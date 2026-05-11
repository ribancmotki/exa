const std = @import("std");
const common = @import("../types/common.zig");
const redis = @import("../cache/redis.zig");

pub fn check(
    redis_pool: *redis.Pool,
    api_key_id: [16]u8,
    qps_limit: u32,
    burst: u32,
    allocator: std.mem.Allocator,
) !common.RateLimitResult {
    const client = redis_pool.acquire();
    defer redis_pool.release(client);

    var key_buf: [128]u8 = undefined;
    const now_ms = @divFloor(std.time.nanoTimestamp(), std.time.ns_per_ms);
    const window_ms: i64 = 1000;
    const window_key = @divFloor(now_ms, window_ms);

    var hex_buf: [32]u8 = undefined;
    const hex = "0123456789abcdef";
    for (api_key_id, 0..) |b, i| {
        hex_buf[i * 2] = hex[b >> 4];
        hex_buf[i * 2 + 1] = hex[b & 0xf];
    }
    _ = &hex_buf;

    const key = std.fmt.bufPrint(&key_buf, "rl:{s}:{d}", .{
        std.fmt.fmtSliceHexLower(&api_key_id),
        window_key,
    }) catch return common.RateLimitResult{
        .allowed = true,
        .remaining = burst,
        .reset_after_ms = window_ms,
    };
    _ = allocator;

    const count = client.incrby(key, 1) catch return common.RateLimitResult{
        .allowed = true,
        .remaining = burst,
        .reset_after_ms = window_ms,
    };

    if (count == 1) {
        client.expire(key, 2) catch {};
    }

    const effective_limit: i64 = @intCast(burst);
    if (count > effective_limit) {
        return common.RateLimitResult{
            .allowed = false,
            .remaining = 0,
            .reset_after_ms = @as(u64, @intCast(window_ms - @mod(now_ms, window_ms))),
        };
    }

    const remaining: u32 = if (effective_limit >= count)
        @as(u32, @intCast(effective_limit - count))
    else
        0;
    _ = qps_limit;

    return common.RateLimitResult{
        .allowed = true,
        .remaining = remaining,
        .reset_after_ms = @as(u64, @intCast(window_ms - @mod(now_ms, window_ms))),
    };
}

pub fn getClientId(req: *const common.HttpRequest) []const u8 {
    if (req.headers.get("x-api-key")) |key| return key;
    if (req.headers.get("x-forwarded-for")) |ip| return ip;
    return "unknown";
}
