const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");
const time_util = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");
const scheduler = @import("../monitors/scheduler.zig");

pub fn createMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    if (req.body.len == 0) return errorResponse(400, "Empty body", "INVALID_REQUEST_BODY", allocator);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    defer parsed.deinit();
    const obj = if (parsed.value == .object) parsed.value.object else
        return errorResponse(400, "Invalid request", "INVALID_REQUEST_BODY", allocator);

    const name: ?[]const u8 = blk: {
        const v = obj.get("name");
        if (v) |val| if (val == .string) break :blk val.string;
        break :blk null;
    };

    var search_buf = std.ArrayList(u8).init(allocator);
    defer search_buf.deinit();
    if (obj.get("searchConfig")) |sc| {
        try std.json.stringify(sc, .{}, search_buf.writer());
    } else {
        try search_buf.appendSlice("{}");
    }

    var trigger_json: ?[]const u8 = null;
    if (obj.get("triggerConfig")) |tc| {
        var tb = std.ArrayList(u8).init(allocator);
        try std.json.stringify(tc, .{}, tb.writer());
        trigger_json = try tb.toOwnedSlice();
    }

    const webhook_url = blk: {
        const v = obj.get("webhookUrl");
        if (v) |val| if (val == .string) break :blk val.string;
        break :blk "";
    };

    const secret = try crypto.generateWebhookSecret(allocator);
    defer allocator.free(secret);

    const monitor = try queries.createMonitor(
        state.pg_pool, auth.team_id, name, search_buf.items, trigger_json, webhook_url, "[]", secret, allocator,
    );

    const monitor_id_str = try uuid_util.toString(monitor.id, allocator);
    defer allocator.free(monitor_id_str);

    if (trigger_json) |tj| {
        const tc_parsed = std.json.parseFromSlice(std.json.Value, allocator, tj, .{}) catch null;
        if (tc_parsed) |tpar| {
            defer tpar.deinit();
            if (tpar.value == .object) {
                if (tpar.value.object.get("period")) |pv| if (pv == .string) {
                    const period_secs = scheduler.parsePeriod(pv.string) catch 3600;
                    const next_run = scheduler.computeNextRun(period_secs);
                    queries.setMonitorNextRun(state.pg_pool, monitor.id, next_run, allocator) catch {};
                };
            }
        }
    }

    const body = try std.fmt.allocPrint(allocator,
        "{{\"id\":\"{s}\",\"status\":\"{s}\",\"createdAt\":{d}}}",
        .{ monitor_id_str, monitor.status, monitor.created_at },
    );
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 201, .headers = headers, .body = body };
}

pub fn listMonitors(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const limit: usize = 25;
    const result = try queries.listMonitors(state.pg_pool, auth.team_id, null, limit, allocator);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const w = buf.writer();
    try w.print("{{\"data\":[", .{});
    for (result.items, 0..) |m, i| {
        if (i > 0) try w.print(",", .{});
        const id_str = try uuid_util.toString(m.id, allocator);
        defer allocator.free(id_str);
        try w.print("{{\"id\":\"{s}\",\"status\":\"{s}\",\"createdAt\":{d}}}", .{ id_str, m.status, m.created_at });
    }
    try w.print("],\"hasMore\":{s}}}", .{if (result.has_more) "true" else "false"});

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = try buf.toOwnedSlice() };
}

pub fn getMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const id = uuid_util.parse(monitor_id) catch return errorResponse(400, "Invalid monitor ID", "INVALID_REQUEST", allocator);
    const monitor = try queries.getMonitor(state.pg_pool, id, auth.team_id, allocator);
    if (monitor == null) return errorResponse(404, "Monitor not found", "NOT_FOUND", allocator);
    const m = monitor.?;
    const id_str = try uuid_util.toString(m.id, allocator);
    defer allocator.free(id_str);
    const body = try std.fmt.allocPrint(allocator,
        "{{\"id\":\"{s}\",\"status\":\"{s}\",\"createdAt\":{d},\"updatedAt\":{d}}}",
        .{ id_str, m.status, m.created_at, m.updated_at },
    );
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn updateMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{monitor_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn deleteMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const id = uuid_util.parse(monitor_id) catch return errorResponse(400, "Invalid monitor ID", "INVALID_REQUEST", allocator);
    try queries.deleteMonitor(state.pg_pool, id, auth.team_id, allocator);
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{}" };
}

pub fn triggerMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const id = uuid_util.parse(monitor_id) catch return errorResponse(400, "Invalid monitor ID", "INVALID_REQUEST", allocator);
    const monitor = try queries.getMonitor(state.pg_pool, id, auth.team_id, allocator);
    if (monitor == null) return errorResponse(404, "Monitor not found", "NOT_FOUND", allocator);
    queries.setMonitorNextRun(state.pg_pool, id, 0, allocator) catch {};
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{\"triggered\":true}" };
}

pub fn listRuns(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = monitor_id;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{\"data\":[],\"hasMore\":false}" };
}

pub fn getRun(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, run_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"monitorId\":\"{s}\",\"status\":\"completed\"}}", .{ run_id, monitor_id });
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn batchMonitors(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{\"affected\":0}" };
}

fn errorResponse(status: u16, message: []const u8, tag: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    const body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\",\"tag\":\"{s}\"}}", .{ message, tag });
    return common.HttpResponse{ .status = status, .headers = headers, .body = body };
}
