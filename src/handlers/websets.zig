const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");
const time_util = @import("../utils/time.zig");
const webhooks = @import("../webhooks/dispatcher.zig");

fn j(status: u16, body: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var h = std.StringHashMap([]const u8).init(allocator);
    try h.put("content-type", "application/json");
    return common.HttpResponse{ .status = status, .headers = h, .body = body };
}

pub fn createWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    const ts = time_util.nowSeconds() * 1000;
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"idle\",\"createdAt\":{d}}}", .{ id_str, ts }), allocator);
}

pub fn previewWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, "{\"items\":[]}", allocator);
}

pub fn listWebsets(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, "{\"data\":[],\"hasMore\":false}", allocator);
}

pub fn getWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"idle\"}}", .{webset_id}), allocator);
}

pub fn updateWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"idle\"}}", .{webset_id}), allocator);
}

pub fn deleteWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webset_id;
    return j(200, "{}", allocator);
}

pub fn cancelWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"idle\"}}", .{webset_id}), allocator);
}

pub fn createSearch(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"created\"}}", .{ id_str, webset_id }), allocator);
}

pub fn getSearch(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, search_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"completed\"}}", .{ search_id, webset_id }), allocator);
}

pub fn cancelSearch(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, search_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"cancelled\"}}", .{ search_id, webset_id }), allocator);
}

pub fn createEnrichment(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"pending\"}}", .{ id_str, webset_id }), allocator);
}

pub fn getEnrichment(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, enrichment_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"pending\"}}", .{ enrichment_id, webset_id }), allocator);
}

pub fn updateEnrichment(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, enrichment_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"pending\"}}", .{ enrichment_id, webset_id }), allocator);
}

pub fn deleteEnrichment(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, enrichment_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webset_id;
    _ = enrichment_id;
    return j(200, "{}", allocator);
}

pub fn cancelEnrichment(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, enrichment_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"cancelled\"}}", .{ enrichment_id, webset_id }), allocator);
}

pub fn listItems(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webset_id;
    return j(200, "{\"data\":[],\"hasMore\":false}", allocator);
}

pub fn getItem(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, item_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\"}}", .{ item_id, webset_id }), allocator);
}

pub fn deleteItem(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, item_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webset_id;
    _ = item_id;
    return j(200, "{}", allocator);
}

pub fn createExport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"pending\"}}", .{ id_str, webset_id }), allocator);
}

pub fn getExport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webset_id: []const u8, export_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"websetId\":\"{s}\",\"status\":\"completed\"}}", .{ export_id, webset_id }), allocator);
}

pub fn createImport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"pending\"}}", .{id_str}), allocator);
}

pub fn getImport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, import_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"completed\"}}", .{import_id}), allocator);
}

pub fn listImports(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, "{\"data\":[],\"hasMore\":false}", allocator);
}

pub fn updateImport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, import_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}", .{import_id}), allocator);
}

pub fn deleteImport(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, import_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = import_id;
    return j(200, "{}", allocator);
}

pub fn createWebhook(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    if (req.body.len == 0) return j(400, "{\"error\":\"Empty body\"}", allocator);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch
        return j(400, "{\"error\":\"Invalid JSON\"}", allocator);
    defer parsed.deinit();
    const obj = if (parsed.value == .object) parsed.value.object else return j(400, "{\"error\":\"Invalid request\"}", allocator);
    const url_val = obj.get("url") orelse return j(400, "{\"error\":\"Missing url\"}", allocator);
    const url = if (url_val == .string) url_val.string else return j(400, "{\"error\":\"url must be string\"}", allocator);
    const team_str = try uuid_util.toString(auth.team_id, allocator);
    defer allocator.free(team_str);
    const crypto = @import("../utils/crypto.zig");
    const secret = try crypto.generateWebhookSecret(allocator);
    defer allocator.free(secret);
    const conn = state.pg_pool.acquire();
    defer state.pg_pool.release(conn);
    var rs = conn.query(
        "INSERT INTO webhooks (team_id, url, secret) VALUES ($1, $2, $3) RETURNING id::text",
        &.{ team_str, url, secret },
    ) catch null;
    var id_str = try uuid_util.toString(uuid_util.generate(), allocator);
    defer allocator.free(id_str);
    if (rs) |*r| {
        defer r.deinit();
        if (r.next()) {
            id_str = try allocator.dupe(u8, r.rowAt().getString(0) orelse id_str);
        }
    }
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"url\":\"{s}\",\"status\":\"active\",\"secret\":\"{s}\"}}", .{ id_str, url, secret }), allocator);
}

pub fn listWebhooks(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, "{\"data\":[]}", allocator);
}

pub fn getWebhook(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webhook_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{webhook_id}), allocator);
}

pub fn updateWebhook(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webhook_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{webhook_id}), allocator);
}

pub fn deleteWebhook(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webhook_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webhook_id;
    return j(200, "{}", allocator);
}

pub fn listWebhookAttempts(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, webhook_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = webhook_id;
    return j(200, "{\"data\":[]}", allocator);
}

pub fn listEvents(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const result = try queries.listEvents(state.pg_pool, auth.team_id, null, 25, allocator);
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try buf.appendSlice("{\"data\":[],\"hasMore\":");
    try buf.appendSlice(if (result.has_more) "true}" else "false}");
    return j(200, try buf.toOwnedSlice(), allocator);
}

pub fn getEvent(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, event_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}", .{event_id}), allocator);
}

pub fn getTeamInfo(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    const balance = queries.getTeamBalance(state.pg_pool, auth.team_id, allocator) catch 0;
    const team_str = try uuid_util.toString(auth.team_id, allocator);
    defer allocator.free(team_str);
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"creditBalanceCents\":{d}}}", .{ team_str, balance }), allocator);
}

pub fn createWebsetMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const id = uuid_util.generate();
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    return j(201, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{id_str}), allocator);
}

pub fn listWebsetMonitors(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, "{\"data\":[]}", allocator);
}

pub fn getWebsetMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{monitor_id}), allocator);
}

pub fn updateWebsetMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{monitor_id}), allocator);
}

pub fn deleteWebsetMonitor(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = monitor_id;
    return j(200, "{}", allocator);
}

pub fn listWebsetMonitorRuns(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = monitor_id;
    return j(200, "{\"data\":[]}", allocator);
}

pub fn getWebsetMonitorRun(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, monitor_id: []const u8, run_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    return j(200, try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"monitorId\":\"{s}\"}}", .{ run_id, monitor_id }), allocator);
}
