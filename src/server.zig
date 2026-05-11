const std = @import("std");
const app_state = @import("app_state.zig");
const router = @import("router.zig");
const common = @import("types/common.zig");
const uuid = @import("utils/uuid.zig");
const time = @import("utils/time.zig");
const cors = @import("middleware/cors.zig");
const errors = @import("types/errors.zig");
const config = @import("config.zig");

pub const Server = struct {
    pub fn run(state: *app_state.AppState, allocator: std.mem.Allocator) !void {
        const host = state.cfg.listen_host;
        const port = state.cfg.listen_port;

        const addr = std.net.Address.parseIp(host, port) catch |err| {
            std.log.err("Invalid listen address '{s}': {}", .{ host, err });
            return err;
        };

        var net_server = try addr.listen(.{ .reuse_address = true });
        defer net_server.deinit();

        std.log.info("Listening on {s}:{d}", .{ host, port });

        while (true) {
            const conn = net_server.accept() catch |err| {
                std.log.warn("Accept error: {}", .{err});
                continue;
            };

            const ctx = allocator.create(ConnCtx) catch |err| {
                conn.stream.close();
                std.log.warn("OOM allocating conn ctx: {}", .{err});
                continue;
            };
            ctx.* = ConnCtx{ .conn = conn, .state = state, .base_allocator = allocator };

            const thread = std.Thread.spawn(.{}, handleConn, .{ctx}) catch |err| {
                std.log.warn("Thread spawn failed: {}", .{err});
                conn.stream.close();
                allocator.destroy(ctx);
                continue;
            };
            thread.detach();
        }
    }
};

const ConnCtx = struct {
    conn: std.net.Server.Connection,
    state: *app_state.AppState,
    base_allocator: std.mem.Allocator,
};

fn handleConn(ctx: *ConnCtx) void {
    defer {
        ctx.conn.stream.close();
        ctx.base_allocator.destroy(ctx);
    }

    var arena = std.heap.ArenaAllocator.init(ctx.base_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    handleConnInner(ctx.conn.stream, ctx.state, allocator) catch |err| {
        std.log.debug("Connection error: {}", .{err});
    };
}

fn handleConnInner(stream: std.net.Stream, state: *app_state.AppState, allocator: std.mem.Allocator) !void {
    var buf: [65536]u8 = undefined;
    var total_read: usize = 0;

    while (total_read < buf.len) {
        const n = stream.read(buf[total_read..]) catch break;
        if (n == 0) break;
        total_read += n;
        if (total_read >= 4 and std.mem.indexOf(u8, buf[0..total_read], "\r\n\r\n") != null) break;
    }

    if (total_read == 0) return;

    const raw = buf[0..total_read];
    const header_end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return;
    const headers_raw = raw[0..header_end];

    var line_iter = std.mem.splitSequence(u8, headers_raw, "\r\n");
    const request_line = line_iter.next() orelse return;

    var rl_iter = std.mem.splitScalar(u8, request_line, ' ');
    const method = rl_iter.next() orelse return;
    const full_path = rl_iter.next() orelse return;

    var header_map = std.StringHashMap([]const u8).init(allocator);
    var content_length: usize = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " ");
        const val = std.mem.trim(u8, line[colon + 1..], " ");
        const key_lower = try allocator.alloc(u8, key.len);
        for (key, 0..) |c, i| key_lower[i] = std.ascii.toLower(c);
        try header_map.put(key_lower, val);
        if (std.ascii.eqlIgnoreCase(key, "content-length")) {
            content_length = std.fmt.parseInt(usize, val, 10) catch 0;
        }
    }

    var body_from_buf = raw[header_end + 4..];
    var body: []const u8 = body_from_buf;

    if (content_length > body_from_buf.len) {
        const needed = content_length - body_from_buf.len;
        var extra = try allocator.alloc(u8, needed);
        var extra_read: usize = 0;
        while (extra_read < needed) {
            const n = stream.read(extra[extra_read..]) catch break;
            if (n == 0) break;
            extra_read += n;
        }
        var combined = try allocator.alloc(u8, body_from_buf.len + extra_read);
        @memcpy(combined[0..body_from_buf.len], body_from_buf);
        @memcpy(combined[body_from_buf.len..], extra[0..extra_read]);
        body = combined;
    }

    const path_only = if (std.mem.indexOfScalar(u8, full_path, '?')) |qi| full_path[0..qi] else full_path;
    const query_str = if (std.mem.indexOfScalar(u8, full_path, '?')) |qi| full_path[qi + 1..] else "";

    var query_params = std.StringHashMap([]const u8).init(allocator);
    if (query_str.len > 0) {
        var qit = std.mem.splitScalar(u8, query_str, '&');
        while (qit.next()) |pair| {
            if (std.mem.indexOfScalar(u8, pair, '=')) |eq| {
                try query_params.put(pair[0..eq], pair[eq + 1..]);
            }
        }
    }

    var req_id: [16]u8 = uuid.generate();
    header_map.put("x-request-id", try uuid.toString(req_id, allocator)) catch {};

    var req = common.HttpRequest{
        .method = method,
        .path = path_only,
        .headers = header_map,
        .body = body,
        .query_params = query_params,
        .request_id = req_id,
    };

    const start_ms = time.nowMillis();

    const resp = if (std.mem.eql(u8, method, "OPTIONS"))
        cors.handlePreflight(allocator)
    else
        router.route(&req, state, allocator) catch |err| blk: {
            const app_err = errors.toAppError(err, req.headers.get("x-request-id"));
            const err_json = app_err.toJson(allocator) catch "{\"error\":\"internal error\"}";
            var h = std.StringHashMap([]const u8).init(allocator);
            h.put("content-type", "application/json") catch {};
            break :blk common.HttpResponse{
                .status = app_err.httpStatus(),
                .headers = h,
                .body = err_json,
            };
        };

    const duration_ms = @as(u64, @intCast(time.nowMillis() - start_ms));
    std.log.info("{s} {s} -> {d} ({d}ms)", .{ method, path_only, resp.status, duration_ms });

    try writeResponse(stream, resp, allocator);
}

fn writeResponse(stream: std.net.Stream, resp: common.HttpResponse, allocator: std.mem.Allocator) !void {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    const w = out.writer();

    try w.print("HTTP/1.1 {d} {s}\r\n", .{ resp.status, statusText(resp.status) });
    try w.print("Content-Length: {d}\r\n", .{resp.body.len});
    try w.print("Connection: close\r\n", .{});
    try w.print("Access-Control-Allow-Origin: *\r\n", .{});
    try w.print("Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n", .{});
    try w.print("Access-Control-Allow-Headers: Content-Type, x-api-key, Authorization\r\n", .{});

    var it = resp.headers.iterator();
    while (it.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, "content-length")) continue;
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, "connection")) continue;
        try w.print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
    if (resp.headers.get("content-type") == null) {
        try w.print("Content-Type: application/json\r\n", .{});
    }
    try w.print("\r\n", .{});
    try out.appendSlice(resp.body);

    try stream.writeAll(out.items);
}

fn statusText(code: u16) []const u8 {
    return switch (code) {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        402 => "Payment Required",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        422 => "Unprocessable Entity",
        429 => "Too Many Requests",
        451 => "Unavailable For Legal Reasons",
        500 => "Internal Server Error",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        else => "Unknown",
    };
}
