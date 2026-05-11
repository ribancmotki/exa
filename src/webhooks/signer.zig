const std = @import("std");
const crypto = @import("../utils/crypto.zig");
const time = @import("../utils/time.zig");

pub fn sign(secret: []const u8, timestamp: i64, payload: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var signature: [32]u8 = undefined;
    crypto.computeWebhookSignature(secret, timestamp, payload, &signature);
    const sig_hex = try crypto.hexEncode(&signature, allocator);
    defer allocator.free(sig_hex);
    const ts_str = try std.fmt.allocPrint(allocator, "{d}", .{timestamp});
    defer allocator.free(ts_str);
    return try std.fmt.allocPrint(allocator, "t={s},v1={s}", .{ ts_str, sig_hex });
}

pub fn verify(secret: []const u8, timestamp: i64, payload: []const u8, signature: []const u8) bool {
    var expected: [32]u8 = undefined;
    crypto.computeWebhookSignature(secret, timestamp, payload, &expected);
    const expected_hex = crypto.hexEncode(&expected, std.heap.page_allocator) catch return false;
    defer std.heap.page_allocator.free(expected_hex);
    const sig_prefix = "v1=";
    const v1_start = std.mem.indexOf(u8, signature, sig_prefix) orelse return false;
    const v1 = signature[v1_start + sig_prefix.len..];
    return crypto.timingSafeEqual(expected_hex, v1);
}
