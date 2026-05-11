const std = @import("std");
const db_pool = @import("../db/pool.zig");
const redis_pool = @import("../cache/redis.zig");
const time = @import("../utils/time.zig");
const uuid = @import("../utils/uuid.zig");

pub fn enqueueRetry(rp: *redis_pool.Pool, webhook_id: [16]u8, event_id: [16]u8, attempt: u8, delay_seconds: u64) !void {
    const client = rp.acquire();
    defer rp.release(client);
    const at = time.nowSeconds() + @as(i64, @intCast(delay_seconds));
    var key_buf: [128]u8 = undefined;
    const key = try std.fmt.bufPrint(&key_buf, "webhook_retry:{s}:{s}", .{
        std.fmt.fmtSliceHexLower(&webhook_id),
        std.fmt.fmtSliceHexLower(&event_id),
    });
    var val_buf: [64]u8 = undefined;
    const val = try std.fmt.bufPrint(&val_buf, "{d}:{d}", .{ at, attempt });
    try client.set(key, val, delay_seconds + 3600);
}

pub fn getNextRetry(rp: *redis_pool.Pool, allocator: std.mem.Allocator) !?struct { webhook_id: [16]u8, event_id: [16]u8, attempt: u8 } {
    _ = rp;
    _ = allocator;
    return null;
}

pub fn run(pg: *db_pool.Pool, rp: *redis_pool.Pool) void {
    _ = pg;
    while (true) {
        std.time.sleep(std.time.ns_per_s * 10);
        processRetries(rp) catch {};
    }
}

fn processRetries(rp: *redis_pool.Pool) !void {
    const pa = std.heap.page_allocator;
    const retry = try getNextRetry(rp, pa);
    if (retry == null) return;
}
