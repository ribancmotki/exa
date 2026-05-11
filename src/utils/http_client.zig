const std = @import("std");

pub const Response = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    body_alloc: bool = true,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void {
        if (self.body_alloc) self.allocator.free(self.body);
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

const SSL_CTX = opaque {};
const SSL = opaque {};

extern fn SSL_CTX_new(method: ?*anyopaque) ?*SSL_CTX;
extern fn SSL_CTX_free(ctx: ?*SSL_CTX) void;
extern fn SSL_new(ctx: ?*SSL_CTX) ?*SSL;
extern fn SSL_free(ssl: ?*SSL) void;
extern fn SSL_set_fd(ssl: ?*SSL, fd: c_int) c_int;
extern fn SSL_connect(ssl: ?*SSL) c_int;
extern fn SSL_read(ssl: ?*SSL, buf: [*]u8, len: c_int) c_int;
extern fn SSL_write(ssl: ?*SSL, buf: [*]const u8, len: c_int) c_int;
extern fn SSL_CTX_set_verify(ctx: ?*SSL_CTX, mode: c_int, verify_cb: ?*const anyopaque) void;
extern fn TLS_client_method() ?*anyopaque;
extern fn OPENSSL_init_ssl(opts: c_ulong, settings: ?*anyopaque) c_int;

var ssl_initialized = false;
var ssl_global_ctx: ?*SSL_CTX = null;

fn initSsl() void {
    if (ssl_initialized) return;
    _ = OPENSSL_init_ssl(0, null);
    ssl_global_ctx = SSL_CTX_new(TLS_client_method());
    if (ssl_global_ctx) |ctx| {
        SSL_CTX_set_verify(ctx, 0, null);
    }
    ssl_initialized = true;
}

pub const HttpClient = struct {
    base_url: []const u8,
    timeout_ms: u64,

    pub fn init(base_url: []const u8, timeout_ms: u64) !HttpClient {
        return HttpClient{ .base_url = base_url, .timeout_ms = timeout_ms };
    }

    pub fn post(
        self: *const HttpClient,
        path: []const u8,
        body: []const u8,
        content_type: []const u8,
        extra_headers: anytype,
        allocator: std.mem.Allocator,
    ) !Response {
        const url = try buildUrl(self.base_url, path, allocator);
        defer allocator.free(url);
        _ = content_type;
        _ = extra_headers;
        return self.request("POST", url, body, allocator);
    }

    pub fn get(
        self: *const HttpClient,
        path: []const u8,
        extra_headers: anytype,
        allocator: std.mem.Allocator,
    ) !Response {
        const url = try buildUrl(self.base_url, path, allocator);
        defer allocator.free(url);
        _ = extra_headers;
        return self.request("GET", url, "", allocator);
    }

    pub fn request(
        self: *const HttpClient,
        method: []const u8,
        url: []const u8,
        body: []const u8,
        allocator: std.mem.Allocator,
    ) !Response {
        initSsl();
        const pu = try parseUrl(url, allocator);
        defer {
            allocator.free(pu.host);
            allocator.free(pu.path);
        }

        const stream = std.net.tcpConnectToHost(allocator, pu.host, pu.port) catch |err| {
            std.log.warn("HTTP connect failed to {s}:{d}: {}", .{ pu.host, pu.port, err });
            return error.NetworkError;
        };
        defer stream.close();

        const timeout_ms = self.timeout_ms;
        const timeout = std.posix.timeval{
            .sec = @intCast(timeout_ms / 1000),
            .usec = @intCast((timeout_ms % 1000) * 1000),
        };
        std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};
        std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout)) catch {};

        var ssl_conn: ?*SSL = null;
        defer if (ssl_conn) |s| SSL_free(s);

        if (pu.tls) {
            if (ssl_global_ctx) |ctx| {
                ssl_conn = SSL_new(ctx);
                if (ssl_conn) |s| {
                    _ = SSL_set_fd(s, stream.handle);
                    _ = SSL_connect(s);
                }
            }
        }

        var req_buf = std.ArrayList(u8).init(allocator);
        defer req_buf.deinit();
        const w = req_buf.writer();
        try w.print("{s} {s} HTTP/1.1\r\n", .{ method, pu.path });
        try w.print("Host: {s}\r\n", .{pu.host});
        try w.print("User-Agent: SearchPlatform/0.1\r\n", .{});
        try w.print("Content-Type: application/json\r\n", .{});
        try w.print("Content-Length: {d}\r\n", .{body.len});
        try w.print("Connection: close\r\n", .{});
        try w.print("\r\n", .{});
        try req_buf.appendSlice(body);

        if (ssl_conn) |s| {
            var written: usize = 0;
            const data = req_buf.items;
            while (written < data.len) {
                const n = SSL_write(s, data.ptr + written, @intCast(data.len - written));
                if (n <= 0) return error.WriteFailed;
                written += @intCast(n);
            }
        } else {
            stream.writeAll(req_buf.items) catch return error.WriteFailed;
        }

        var resp_buf = std.ArrayList(u8).init(allocator);
        defer resp_buf.deinit();
        var tmp: [8192]u8 = undefined;
        while (true) {
            const n: usize = if (ssl_conn) |s| blk: {
                const r = SSL_read(s, &tmp, @intCast(tmp.len));
                if (r <= 0) break;
                break :blk @intCast(r);
            } else stream.read(&tmp) catch break;
            if (n == 0) break;
            try resp_buf.appendSlice(tmp[0..n]);
        }

        return parseHttpResponse(resp_buf.items, allocator);
    }
};

fn buildUrl(base: []const u8, path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    if (path.len == 0) return allocator.dupe(u8, base);
    if (path[0] == '/') return std.fmt.allocPrint(allocator, "{s}{s}", .{ base, path });
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, path });
}

const ParsedUrl = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
    tls: bool,
};

fn parseUrl(url: []const u8, allocator: std.mem.Allocator) !ParsedUrl {
    var rest = url;
    var port: u16 = 80;
    var tls = false;

    if (std.mem.startsWith(u8, rest, "https://")) {
        rest = rest[8..];
        port = 443;
        tls = true;
    } else if (std.mem.startsWith(u8, rest, "http://")) {
        rest = rest[7..];
    }

    const path_start = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
    const host_port = rest[0..path_start];
    const path_part = if (path_start < rest.len) rest[path_start..] else "/";

    var host: []const u8 = host_port;
    if (std.mem.lastIndexOfScalar(u8, host_port, ':')) |colon| {
        host = host_port[0..colon];
        port = std.fmt.parseInt(u16, host_port[colon + 1..], 10) catch port;
    }

    return ParsedUrl{
        .host = try allocator.dupe(u8, host),
        .port = port,
        .path = try allocator.dupe(u8, path_part),
        .tls = tls,
    };
}

fn parseHttpResponse(data: []const u8, allocator: std.mem.Allocator) Response {
    const header_end = std.mem.indexOf(u8, data, "\r\n\r\n") orelse
        (std.mem.indexOf(u8, data, "\n\n") orelse data.len);

    const headers_raw = data[0..@min(header_end, data.len)];
    const body_off = @min(header_end + 4, data.len);
    const body_raw = data[body_off..];

    var status: u16 = 200;
    var line_iter = std.mem.splitScalar(u8, headers_raw, '\n');
    if (line_iter.next()) |first_line| {
        var sp_iter = std.mem.splitScalar(u8, std.mem.trimRight(u8, first_line, "\r"), ' ');
        _ = sp_iter.next();
        if (sp_iter.next()) |code| {
            status = std.fmt.parseInt(u16, code, 10) catch 200;
        }
    }

    const body = allocator.dupe(u8, body_raw) catch &[_]u8{};

    return Response{
        .status = status,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = body,
        .body_alloc = true,
        .allocator = allocator,
    };
}

pub fn fetchUrl(
    url: []const u8,
    method: []const u8,
    body: []const u8,
    user_agent: []const u8,
    timeout_ms: u64,
    allocator: std.mem.Allocator,
) !Response {
    _ = user_agent;
    const client = HttpClient{ .base_url = "", .timeout_ms = timeout_ms };
    return client.request(method, url, body, allocator);
}
