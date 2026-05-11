const std = @import("std");
const common = @import("../types/common.zig");
const db_pool = @import("../db/pool.zig");
const redis_pool = @import("../cache/redis.zig");
const crypto = @import("../utils/crypto.zig");
const queries = @import("../db/queries.zig");

pub fn authenticate(
    req: *const common.HttpRequest,
    pg: *db_pool.Pool,
    rp: *redis_pool.Pool,
    allocator: std.mem.Allocator,
) !common.AuthContext {
    const api_key = req.headers.get("x-api-key") orelse
        req.headers.get("authorization") orelse {
        return error.InvalidApiKey;
    };

    const key = if (std.mem.startsWith(u8, api_key, "Bearer "))
        api_key[7..]
    else
        api_key;

    if (key.len < 16) return error.InvalidApiKey;

    var hash: [32]u8 = undefined;
    crypto.sha256(key, &hash);

    const cache_client = rp.acquire();
    defer rp.release(cache_client);

    const hash_hex = try crypto.hexEncode(&hash, allocator);
    defer allocator.free(hash_hex);

    const cache_key = try std.fmt.allocPrint(allocator, "apikey:{s}", .{hash_hex});
    defer allocator.free(cache_key);

    if (try cache_client.get(cache_key, allocator)) |cached| {
        defer allocator.free(cached);
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, cached, .{});
        defer parsed.deinit();
        if (parsed.value == .object) {
            const obj = parsed.value.object;
            var kid: [16]u8 = std.mem.zeroes([16]u8);
            var tid: [16]u8 = std.mem.zeroes([16]u8);
            if (obj.get("kid")) |v| if (v == .string) {
                const kid_hex = v.string;
                const kid_bytes = try crypto.hexDecode(kid_hex, allocator);
                defer allocator.free(kid_bytes);
                @memcpy(kid[0..@min(kid_bytes.len, 16)], kid_bytes[0..@min(kid_bytes.len, 16)]);
            };
            if (obj.get("tid")) |v| if (v == .string) {
                const tid_hex = v.string;
                const tid_bytes = try crypto.hexDecode(tid_hex, allocator);
                defer allocator.free(tid_bytes);
                @memcpy(tid[0..@min(tid_bytes.len, 16)], tid_bytes[0..@min(tid_bytes.len, 16)]);
            };
            const balance = if (obj.get("bal")) |v| if (v == .integer) v.integer else @as(i64, 0) else @as(i64, 0);
            const qps = if (obj.get("qps")) |v| if (v == .integer) @as(u32, @intCast(@max(0, v.integer))) else @as(u32, 10) else @as(u32, 10);
            return common.AuthContext{
                .api_key_id = kid,
                .team_id = tid,
                .team_balance_cents = balance,
                .rate_limit_qps = qps,
                .key_budget_cents = null,
                .key_spent_cents = 0,
            };
        }
    }

    const result = try queries.findApiKeyByHash(pg, hash, allocator);
    if (result == null) return error.InvalidApiKey;
    const found = result.?;

    if (found.key.revoked_at != null) return error.InvalidApiKey;

    const kid_hex = try crypto.hexEncode(&found.key.id, allocator);
    defer allocator.free(kid_hex);
    const tid_hex = try crypto.hexEncode(&found.key.team_id, allocator);
    defer allocator.free(tid_hex);
    const qps = found.key.rate_limit_qps orelse 10;
    const cache_val = try std.fmt.allocPrint(allocator,
        "{{\"kid\":\"{s}\",\"tid\":\"{s}\",\"bal\":{d},\"qps\":{d}}}",
        .{ kid_hex, tid_hex, found.balance, qps },
    );
    defer allocator.free(cache_val);
    cache_client.set(cache_key, cache_val, 300) catch {};

    return common.AuthContext{
        .api_key_id = found.key.id,
        .team_id = found.key.team_id,
        .team_balance_cents = found.balance,
        .rate_limit_qps = qps,
        .key_budget_cents = found.key.budget_cents,
        .key_spent_cents = found.key.spent_cents,
    };
}
