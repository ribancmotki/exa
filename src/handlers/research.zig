const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const uuid_util = @import("../utils/uuid.zig");
const time_util = @import("../utils/time.zig");

pub fn createTask(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = state;
    if (req.body.len == 0) {
        return errorResponse(400, "Empty request body", "INVALID_REQUEST_BODY", allocator);
    }
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch {
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    };
    defer parsed.deinit();
    const obj = if (parsed.value == .object) parsed.value.object else {
        return errorResponse(400, "Invalid request", "INVALID_REQUEST_BODY", allocator);
    };
    const instr_val = obj.get("instructions") orelse return errorResponse(400, "Missing instructions", "INVALID_REQUEST_BODY", allocator);
    const instructions = if (instr_val == .string) instr_val.string else return errorResponse(400, "instructions must be string", "INVALID_REQUEST_BODY", allocator);
    _ = instructions;
    _ = auth;

    const task_id = uuid_util.generate();
    const task_id_str = try uuid_util.toString(task_id, allocator);
    defer allocator.free(task_id_str);
    const ts = time_util.nowSeconds() * 1000;

    const body = try std.fmt.allocPrint(allocator,
        "{{\"researchId\":\"{s}\",\"status\":\"pending\",\"createdAt\":{d}}}",
        .{ task_id_str, ts },
    );
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 201, .headers = headers, .body = body };
}

pub fn listTasks(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = "{\"data\":[],\"hasMore\":false}" };
}

pub fn getTask(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, task_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"researchId\":\"{s}\",\"status\":\"pending\"}}", .{task_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn cancelTask(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, task_id: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    const body = try std.fmt.allocPrint(allocator, "{{\"researchId\":\"{s}\",\"status\":\"cancelled\"}}", .{task_id});
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

fn errorResponse(status: u16, message: []const u8, tag: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    const body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\",\"tag\":\"{s}\"}}", .{ message, tag });
    return common.HttpResponse{ .status = status, .headers = headers, .body = body };
}
