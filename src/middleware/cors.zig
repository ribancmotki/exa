const std = @import("std");
const common = @import("../types/common.zig");

pub fn handlePreflight(allocator: std.mem.Allocator) common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    headers.put("access-control-allow-origin", "*") catch {};
    headers.put("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS") catch {};
    headers.put("access-control-allow-headers", "Content-Type, x-api-key, Authorization") catch {};
    headers.put("access-control-max-age", "86400") catch {};
    return common.HttpResponse{
        .status = 204,
        .headers = headers,
        .body = "",
    };
}

pub fn addCorsHeaders(resp: *common.HttpResponse) void {
    resp.headers.put("access-control-allow-origin", "*") catch {};
}
