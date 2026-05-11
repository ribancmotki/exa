const std = @import("std");

pub const JSONRPC_VERSION = "2.0";

pub const JsonRpcRequest = struct {
    jsonrpc: []const u8,
    id: std.json.Value,
    method: []const u8,
    params: ?std.json.Value,
};

pub const JsonRpcResponse = struct {
    jsonrpc: []const u8,
    id: std.json.Value,
    result: ?std.json.Value,
    @"error": ?JsonRpcError,
};

pub const JsonRpcError = struct {
    code: i32,
    message: []const u8,
    data: ?std.json.Value,
};

pub fn parseRequest(body: []const u8, allocator: std.mem.Allocator) !JsonRpcRequest {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return error.InvalidRequest;

    const jsonrpc_val = obj.get("jsonrpc") orelse return error.InvalidRequest;
    const jsonrpc = if (jsonrpc_val == .string) jsonrpc_val.string else return error.InvalidRequest;
    const method_val = obj.get("method") orelse return error.InvalidRequest;
    const method = if (method_val == .string) method_val.string else return error.InvalidRequest;
    const id = obj.get("id") orelse std.json.Value{ .null = {} };
    const params = obj.get("params");

    return JsonRpcRequest{
        .jsonrpc = try allocator.dupe(u8, jsonrpc),
        .id = id,
        .method = try allocator.dupe(u8, method),
        .params = params,
    };
}

pub fn buildSuccess(id: std.json.Value, result: std.json.Value, allocator: std.mem.Allocator) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    const w = buf.writer();
    try w.print("{{\"jsonrpc\":\"2.0\",\"id\":", .{});
    try std.json.stringify(id, .{}, w);
    try w.print(",\"result\":", .{});
    try std.json.stringify(result, .{}, w);
    try w.print("}}", .{});
    return buf.toOwnedSlice();
}

pub fn buildError(id: std.json.Value, code: i32, message: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    const w = buf.writer();
    try w.print("{{\"jsonrpc\":\"2.0\",\"id\":", .{});
    try std.json.stringify(id, .{}, w);
    try w.print(",\"error\":{{\"code\":{d},\"message\":\"{s}\"}}}}", .{ code, message });
    return buf.toOwnedSlice();
}

pub fn buildNotification(method: []const u8, params: std.json.Value, allocator: std.mem.Allocator) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    const w = buf.writer();
    try w.print("{{\"jsonrpc\":\"2.0\",\"method\":\"{s}\",\"params\":", .{method});
    try std.json.stringify(params, .{}, w);
    try w.print("}}", .{});
    return buf.toOwnedSlice();
}
