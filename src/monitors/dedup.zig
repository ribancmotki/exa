const std = @import("std");
const common = @import("../types/common.zig");
const cache = @import("../cache/redis.zig");
const crypto = @import("../utils/crypto.zig");

pub fn getSeenIds(redis_pool: *cache.Pool, monitor_id: [16]u8, allocator: std.mem.Allocator) ![][]const u8 {
    const client = redis_pool.acquire();
    defer redis_pool.release(client);
    var key_buf: [128]u8 = undefined;
    const key = try std.fmt.bufPrint(&key_buf, "monitor_seen:{s}", .{std.fmt.fmtSliceHexLower(&monitor_id)});
    const val = try client.get(key, allocator) orelse return &.{};
    defer allocator.free(val);
    var ids = std.ArrayList([]const u8).init(allocator);
    var it = std.mem.splitScalar(u8, val, ',');
    while (it.next()) |id| {
        if (id.len > 0) try ids.append(try allocator.dupe(u8, id));
    }
    return ids.toOwnedSlice();
}

pub fn recordSeen(redis_pool: *cache.Pool, monitor_id: [16]u8, ids: [][]const u8, allocator: std.mem.Allocator) !void {
    if (ids.len == 0) return;
    const client = redis_pool.acquire();
    defer redis_pool.release(client);
    var key_buf: [128]u8 = undefined;
    const key = try std.fmt.bufPrint(&key_buf, "monitor_seen:{s}", .{std.fmt.fmtSliceHexLower(&monitor_id)});
    var val = std.ArrayList(u8).init(allocator);
    defer val.deinit();
    for (ids, 0..) |id, i| {
        if (i > 0) try val.append(',');
        try val.appendSlice(id);
    }
    try client.set(key, val.items, 86400 * 30);
}

pub fn filterDuplicates(results: []common.ScoredDoc, seen_ids: [][]const u8, allocator: std.mem.Allocator) ![]common.ScoredDoc {
    if (seen_ids.len == 0) return results;
    var filtered = std.ArrayList(common.ScoredDoc).init(allocator);
    for (results) |doc| {
        var is_seen = false;
        for (seen_ids) |sid| {
            if (std.mem.eql(u8, doc.id, sid)) {
                is_seen = true;
                break;
            }
        }
        if (!is_seen) try filtered.append(doc);
    }
    return filtered.toOwnedSlice();
}
