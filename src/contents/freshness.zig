const std = @import("std");
const search = @import("../types/search.zig");
const db_pool = @import("../db/pool.zig");
const redis_pool = @import("../cache/redis.zig");
const crawler_mod = @import("./crawler.zig");
const time_util = @import("../utils/time.zig");

pub fn shouldLivecrawl(pg: *db_pool.Pool, url: []const u8, max_age_hours: ?i64, allocator: std.mem.Allocator) !bool {
    const conn = pg.acquire();
    defer pg.release(conn);
    var rs = conn.query(
        "SELECT EXTRACT(EPOCH FROM crawled_at)*1000 FROM documents WHERE url = $1 LIMIT 1",
        &.{url},
    ) catch return true;
    defer rs.deinit();
    if (!rs.next()) return true;
    const crawled_ms = rs.rowAt().getInt64(0) orelse 0;
    const age_ms = time_util.nowMillis() - crawled_ms;
    const max_age_ms: i64 = (max_age_hours orelse 24) * 3600 * 1000;
    _ = allocator;
    return age_ms > max_age_ms;
}

pub fn resolveContent(pg: *db_pool.Pool, rp: *redis_pool.Pool, web_crawler: *const crawler_mod.Crawler, url: []const u8, allocator: std.mem.Allocator) !search.ContentStatus {
    _ = rp;
    const needs_crawl = shouldLivecrawl(pg, url, null, allocator) catch true;
    if (!needs_crawl) {
        return search.ContentStatus{
            .id = url,
            .status = "success",
            .@"error" = null,
        };
    }
    _ = web_crawler.fetch(url, allocator) catch {
        return search.ContentStatus{
            .id = url,
            .status = "error",
            .@"error" = null,
        };
    };
    return search.ContentStatus{
        .id = url,
        .status = "success",
        .@"error" = null,
    };
}
