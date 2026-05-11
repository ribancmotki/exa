const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");
const crypto = @import("../utils/crypto.zig");
const time_util = @import("../utils/time.zig");

pub fn listApiKeys(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = state;
    _ = auth;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{\"data\":[]}" };
}

pub fn createApiKey(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = state;
    var name: ?[]const u8 = null;
    if (req.body.len > 0) {
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch null;
        if (parsed) |p| {
            defer p.deinit();
            if (p.value == .object) {
                if (p.value.object.get("name")) |v| if (v == .string) name = v.string;
            }
        }
    }

    const generated = try crypto.generateApiKey(allocator);
    defer allocator.free(generated.raw);

    const key_id = uuid_util.generate();
    const key_id_str = try uuid_util.toString(key_id, allocator);
    defer allocator.free(key_id_str);
    const team_id_str = try uuid_util.toString(auth.team_id, allocator);
    defer allocator.free(team_id_str);

    const conn = state.pg_pool.acquire();
    defer state.pg_pool.release(conn);
    const hash_hex = try crypto.hexEncode(&generated.hash, allocator);
    defer allocator.free(hash_hex);
    const hash_bytes = try std.fmt.allocPrint(allocator, "\\x{s}", .{hash_hex});
    defer allocator.free(hash_bytes);
    const prefix_str = generated.raw[0..@min(8, generated.raw.len)];
    conn.execCommand(
        "INSERT INTO api_keys (team_id, name, key_hash, key_prefix) VALUES ($1, $2, $3::bytea, $4)",
        &.{ team_id_str, name orelse "", hash_bytes, prefix_str },
    ) catch {};

    const body = try std.fmt.allocPrint(allocator,
        "{{\"id\":\"{s}\",\"key\":\"{s}\",\"name\":\"{s}\",\"createdAt\":{d}}}",
        .{ key_id_str, generated.raw, name orelse "", time_util.nowSeconds() * 1000 },
    );
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 201, .headers = headers, .body = body };
}

pub fn getApiKey(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, key_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{key_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn updateApiKey(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, key_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"status\":\"active\"}}", .{key_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn deleteApiKey(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, key_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    _ = key_id;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{}" };
}

pub fn getApiKeyUsage(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, key_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"spentCents\":0}}", .{key_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}
