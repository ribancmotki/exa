const std = @import("std");
const pool = @import("pool.zig");
const common = @import("../types/common.zig");
const uuid_util = @import("../utils/uuid.zig");
const crypto = @import("../utils/crypto.zig");
const time_util = @import("../utils/time.zig");

pub fn findApiKeyByHash(pg_pool: *pool.Pool, hash: [32]u8, allocator: std.mem.Allocator) !?struct { key: common.ApiKeyRow, balance: i64 } {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const hash_hex = try crypto.hexEncode(&hash, allocator);
    defer allocator.free(hash_hex);
    const hash_bytes = try std.fmt.allocPrint(allocator, "\\x{s}", .{hash_hex});
    defer allocator.free(hash_bytes);
    var rs = try conn.query(
        \\SELECT k.id, k.team_id, k.name, k.key_hash, k.key_prefix,
        \\       k.rate_limit_qps, k.budget_cents, k.spent_cents, k.created_at, k.revoked_at,
        \\       t.credit_balance_cents
        \\FROM api_keys k
        \\JOIN teams t ON t.id = k.team_id
        \\WHERE k.key_hash = $1::bytea AND k.revoked_at IS NULL
        \\LIMIT 1
    , &.{hash_bytes});
    defer rs.deinit();
    if (rs.numRows() == 0) return null;
    if (!rs.next()) return null;
    const row = rs.rowAt();
    const key_id_bytes = row.getBytes(0) orelse return null;
    const team_id_bytes = row.getBytes(1) orelse return null;
    const key_hash_bytes = row.getBytes(3) orelse return null;
    var key_id: [16]u8 = undefined;
    var team_id: [16]u8 = undefined;
    var key_hash: [32]u8 = undefined;
    var key_prefix_arr: [8]u8 = undefined;
    @memcpy(&key_id, if (key_id_bytes.len >= 16) key_id_bytes[0..16] else blk: {
        var tmp = std.mem.zeroes([16]u8);
        @memcpy(tmp[0..key_id_bytes.len], key_id_bytes);
        break :blk &tmp;
    });
    @memcpy(&team_id, if (team_id_bytes.len >= 16) team_id_bytes[0..16] else blk: {
        var tmp = std.mem.zeroes([16]u8);
        @memcpy(tmp[0..team_id_bytes.len], team_id_bytes);
        break :blk &tmp;
    });
    @memcpy(&key_hash, if (key_hash_bytes.len >= 32) key_hash_bytes[0..32] else blk: {
        var tmp = std.mem.zeroes([32]u8);
        @memcpy(tmp[0..key_hash_bytes.len], key_hash_bytes);
        break :blk &tmp;
    });
    const prefix_str = row.getString(4) orelse "";
    const copy_len = @min(prefix_str.len, 8);
    @memset(&key_prefix_arr, 0);
    @memcpy(key_prefix_arr[0..copy_len], prefix_str[0..copy_len]);
    const balance = row.getInt64(10) orelse 0;
    return .{
        .key = common.ApiKeyRow{
            .id = key_id,
            .team_id = team_id,
            .name = if (row.getString(2)) |n| try allocator.dupe(u8, n) else null,
            .key_hash = key_hash,
            .key_prefix = key_prefix_arr,
            .rate_limit_qps = if (row.getInt(5)) |v| @as(u32, @intCast(v)) else null,
            .budget_cents = row.getInt64(6),
            .spent_cents = row.getInt64(7) orelse 0,
            .created_at = row.getInt64(8) orelse 0,
            .revoked_at = row.getInt64(9),
        },
        .balance = balance,
    };
}

pub fn incrementApiKeySpend(pg_pool: *pool.Pool, key_id: [16]u8, cents: i64, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(key_id, allocator);
    defer allocator.free(id_str);
    const cents_str = try std.fmt.allocPrint(allocator, "{d}", .{cents});
    defer allocator.free(cents_str);
    try conn.execCommand(
        "UPDATE api_keys SET spent_cents = spent_cents + $2 WHERE id = $1",
        &.{ id_str, cents_str },
    );
}

pub fn deductTeamBalance(pg_pool: *pool.Pool, team_id: [16]u8, cents: i64, allocator: std.mem.Allocator) !i64 {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(id_str);
    const cents_str = try std.fmt.allocPrint(allocator, "{d}", .{cents});
    defer allocator.free(cents_str);
    var rs = try conn.query(
        \\UPDATE teams SET credit_balance_cents = credit_balance_cents - $2
        \\WHERE id = $1 AND credit_balance_cents >= $2
        \\RETURNING credit_balance_cents
    , &.{ id_str, cents_str });
    defer rs.deinit();
    if (!rs.next()) return error.InsufficientCredits;
    return rs.rowAt().getInt64(0) orelse 0;
}

pub fn getTeamBalance(pg_pool: *pool.Pool, team_id: [16]u8, allocator: std.mem.Allocator) !i64 {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(id_str);
    var rs = try conn.query("SELECT credit_balance_cents FROM teams WHERE id = $1", &.{id_str});
    defer rs.deinit();
    if (!rs.next()) return 0;
    return rs.rowAt().getInt64(0) orelse 0;
}

pub fn recordBillingEvent(pg_pool: *pool.Pool, team_id: [16]u8, api_key_id: ?[16]u8, event_type: []const u8, amount_cents: i64, description: []const u8, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    const cents_str = try std.fmt.allocPrint(allocator, "{d}", .{amount_cents});
    defer allocator.free(cents_str);
    if (api_key_id) |kid| {
        const key_str = try uuid_util.toString(kid, allocator);
        defer allocator.free(key_str);
        try conn.execCommand(
            "INSERT INTO billing_events (team_id, api_key_id, event_type, amount_cents, description) VALUES ($1,$2,$3,$4,$5)",
            &.{ team_str, key_str, event_type, cents_str, description },
        );
    } else {
        try conn.execCommand(
            "INSERT INTO billing_events (team_id, event_type, amount_cents, description) VALUES ($1,$2,$3,$4)",
            &.{ team_str, event_type, cents_str, description },
        );
    }
}

pub fn upsertDocument(pg_pool: *pool.Pool, doc: common.DocumentRow, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const hash_hex = try crypto.hexEncode(&doc.content_hash, allocator);
    defer allocator.free(hash_hex);
    const hash_bytes = try std.fmt.allocPrint(allocator, "\\x{s}", .{hash_hex});
    defer allocator.free(hash_bytes);
    const crawled_str = try time_util.formatIso8601(doc.crawled_at, allocator);
    defer allocator.free(crawled_str);
    try conn.execCommand(
        \\INSERT INTO documents (url, domain, title, author, body_text, content_hash, favicon_url, image_url, crawled_at)
        \\VALUES ($1, $2, $3, $4, $5, $6::bytea, $7, $8, $9)
        \\ON CONFLICT (url) DO UPDATE SET
        \\    title = EXCLUDED.title,
        \\    author = EXCLUDED.author,
        \\    body_text = EXCLUDED.body_text,
        \\    content_hash = EXCLUDED.content_hash,
        \\    favicon_url = EXCLUDED.favicon_url,
        \\    image_url = EXCLUDED.image_url,
        \\    crawled_at = EXCLUDED.crawled_at,
        \\    updated_at = now()
    , &.{
        doc.url,
        doc.domain,
        doc.title orelse "",
        doc.author orelse "",
        doc.body_text orelse "",
        hash_bytes,
        doc.favicon_url orelse "",
        doc.image_url orelse "",
        crawled_str,
    });
}

pub fn searchByFullText(pg_pool: *pool.Pool, query: []const u8, limit: usize, filters: common.SearchFilters, allocator: std.mem.Allocator) ![]common.DocumentRow {
    _ = filters;
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const limit_str = try std.fmt.allocPrint(allocator, "{d}", .{limit});
    defer allocator.free(limit_str);
    var rs = try conn.query(
        \\SELECT id, url, domain, title, author, body_text, content_hash, favicon_url, image_url,
        \\       EXTRACT(EPOCH FROM crawled_at) * 1000 AS crawled_ms,
        \\       EXTRACT(EPOCH FROM published_at) * 1000 AS pub_ms,
        \\       word_count, language
        \\FROM documents
        \\WHERE fts_vector @@ plainto_tsquery('english', $1)
        \\ORDER BY ts_rank(fts_vector, plainto_tsquery('english', $1)) DESC
        \\LIMIT $2
    , &.{ query, limit_str });
    defer rs.deinit();
    var results = std.ArrayList(common.DocumentRow).init(allocator);
    while (rs.next()) {
        const row = rs.rowAt();
        const hash_bytes = row.getBytes(6) orelse &std.mem.zeroes([32]u8);
        var hash: [32]u8 = std.mem.zeroes([32]u8);
        const copy_len = @min(hash_bytes.len, 32);
        @memcpy(hash[0..copy_len], hash_bytes[0..copy_len]);
        try results.append(common.DocumentRow{
            .id = try allocator.dupe(u8, row.getString(0) orelse ""),
            .url = try allocator.dupe(u8, row.getString(1) orelse ""),
            .domain = try allocator.dupe(u8, row.getString(2) orelse ""),
            .title = if (row.getString(3)) |s| try allocator.dupe(u8, s) else null,
            .author = if (row.getString(4)) |s| try allocator.dupe(u8, s) else null,
            .body_text = if (row.getString(5)) |s| try allocator.dupe(u8, s) else null,
            .content_hash = hash,
            .favicon_url = if (row.getString(7)) |s| try allocator.dupe(u8, s) else null,
            .image_url = if (row.getString(8)) |s| try allocator.dupe(u8, s) else null,
            .crawled_at = row.getInt64(9) orelse 0,
            .published_at = row.getInt64(10),
            .word_count = row.getInt(11),
            .language = if (row.getString(12)) |s| try allocator.dupe(u8, s) else null,
            .body_html = null,
            .embedding = null,
        });
    }
    return results.toOwnedSlice();
}

pub fn createMonitor(pg_pool: *pool.Pool, team_id: [16]u8, name: ?[]const u8, search_config_json: []const u8, trigger_config_json: ?[]const u8, webhook_url: []const u8, webhook_events_json: []const u8, webhook_secret: []const u8, allocator: std.mem.Allocator) !common.MonitorRow {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    var rs = try conn.query(
        \\INSERT INTO monitors (team_id, name, search_config, trigger_config, webhook_url, webhook_events, webhook_secret)
        \\VALUES ($1, $2, $3::jsonb, $4::jsonb, $5, $6::text[], $7)
        \\RETURNING id, EXTRACT(EPOCH FROM created_at)*1000, EXTRACT(EPOCH FROM updated_at)*1000
    , &.{
        team_str,
        name orelse "",
        search_config_json,
        trigger_config_json orelse "null",
        webhook_url,
        webhook_events_json,
        webhook_secret,
    });
    defer rs.deinit();
    if (!rs.next()) return error.QueryFailed;
    const row = rs.rowAt();
    const id_bytes = row.getBytes(0) orelse return error.QueryFailed;
    var id: [16]u8 = std.mem.zeroes([16]u8);
    @memcpy(id[0..@min(id_bytes.len, 16)], id_bytes[0..@min(id_bytes.len, 16)]);
    return common.MonitorRow{
        .id = id,
        .team_id = team_id,
        .name = name,
        .status = "active",
        .search_config = .{ .null = {} },
        .trigger_config = null,
        .output_schema = null,
        .metadata = null,
        .webhook_url = try allocator.dupe(u8, webhook_url),
        .webhook_events = &.{},
        .webhook_secret = try allocator.dupe(u8, webhook_secret),
        .next_run_at = null,
        .created_at = row.getInt64(1) orelse 0,
        .updated_at = row.getInt64(2) orelse 0,
    };
}

pub fn getMonitor(pg_pool: *pool.Pool, id: [16]u8, team_id: [16]u8, allocator: std.mem.Allocator) !?common.MonitorRow {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    var rs = try conn.query(
        \\SELECT id, team_id, name, status, webhook_url, webhook_secret,
        \\       EXTRACT(EPOCH FROM created_at)*1000,
        \\       EXTRACT(EPOCH FROM updated_at)*1000,
        \\       EXTRACT(EPOCH FROM next_run_at)*1000
        \\FROM monitors WHERE id = $1 AND team_id = $2
    , &.{ id_str, team_str });
    defer rs.deinit();
    if (!rs.next()) return null;
    const row = rs.rowAt();
    return common.MonitorRow{
        .id = id,
        .team_id = team_id,
        .name = if (row.getString(2)) |n| try allocator.dupe(u8, n) else null,
        .status = try allocator.dupe(u8, row.getString(3) orelse "active"),
        .search_config = .{ .null = {} },
        .trigger_config = null,
        .output_schema = null,
        .metadata = null,
        .webhook_url = try allocator.dupe(u8, row.getString(4) orelse ""),
        .webhook_events = &.{},
        .webhook_secret = try allocator.dupe(u8, row.getString(5) orelse ""),
        .next_run_at = row.getInt64(8),
        .created_at = row.getInt64(6) orelse 0,
        .updated_at = row.getInt64(7) orelse 0,
    };
}

pub fn listMonitors(pg_pool: *pool.Pool, team_id: [16]u8, cursor: ?[]const u8, limit: usize, allocator: std.mem.Allocator) !common.PaginatedResult(common.MonitorRow) {
    _ = cursor;
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    const lim = try std.fmt.allocPrint(allocator, "{d}", .{limit + 1});
    defer allocator.free(lim);
    var rs = try conn.query(
        "SELECT id, name, status, EXTRACT(EPOCH FROM created_at)*1000 FROM monitors WHERE team_id = $1 ORDER BY created_at DESC LIMIT $2",
        &.{ team_str, lim },
    );
    defer rs.deinit();
    var items = std.ArrayList(common.MonitorRow).init(allocator);
    while (rs.next()) {
        const row = rs.rowAt();
        const id_bytes = row.getBytes(0) orelse continue;
        var mid: [16]u8 = std.mem.zeroes([16]u8);
        @memcpy(mid[0..@min(id_bytes.len, 16)], id_bytes[0..@min(id_bytes.len, 16)]);
        try items.append(common.MonitorRow{
            .id = mid,
            .team_id = team_id,
            .name = if (row.getString(1)) |n| try allocator.dupe(u8, n) else null,
            .status = try allocator.dupe(u8, row.getString(2) orelse "active"),
            .search_config = .{ .null = {} },
            .trigger_config = null,
            .output_schema = null,
            .metadata = null,
            .webhook_url = "",
            .webhook_events = &.{},
            .webhook_secret = "",
            .next_run_at = null,
            .created_at = row.getInt64(3) orelse 0,
            .updated_at = 0,
        });
    }
    const all = try items.toOwnedSlice();
    const has_more = all.len > limit;
    const slice = if (has_more) all[0..limit] else all;
    return .{ .items = slice, .has_more = has_more, .next_cursor = null };
}

pub fn deleteMonitor(pg_pool: *pool.Pool, id: [16]u8, team_id: [16]u8, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(id, allocator);
    defer allocator.free(id_str);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    try conn.execCommand("DELETE FROM monitors WHERE id = $1 AND team_id = $2", &.{ id_str, team_str });
}

pub fn listDueMonitors(pg_pool: *pool.Pool, now: i64, allocator: std.mem.Allocator) ![]common.MonitorRow {
    _ = allocator;
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    var pa = std.heap.page_allocator;
    const now_str = try std.fmt.allocPrint(pa, "{d}", .{now});
    defer pa.free(now_str);
    var rs = try conn.query(
        \\SELECT id, team_id, name, status, webhook_url, webhook_secret,
        \\       search_config::text, trigger_config::text,
        \\       EXTRACT(EPOCH FROM created_at)*1000,
        \\       EXTRACT(EPOCH FROM updated_at)*1000
        \\FROM monitors
        \\WHERE status = 'active'
        \\  AND next_run_at IS NOT NULL
        \\  AND next_run_at <= to_timestamp($1::bigint / 1000)
        \\LIMIT 100
    , &.{now_str});
    defer rs.deinit();
    var items = std.ArrayList(common.MonitorRow).init(pa);
    while (rs.next()) {
        const row = rs.rowAt();
        const id_bytes = row.getBytes(0) orelse continue;
        const tid_bytes = row.getBytes(1) orelse continue;
        var mid: [16]u8 = std.mem.zeroes([16]u8);
        var tid: [16]u8 = std.mem.zeroes([16]u8);
        @memcpy(mid[0..@min(id_bytes.len, 16)], id_bytes[0..@min(id_bytes.len, 16)]);
        @memcpy(tid[0..@min(tid_bytes.len, 16)], tid_bytes[0..@min(tid_bytes.len, 16)]);
        items.append(common.MonitorRow{
            .id = mid,
            .team_id = tid,
            .name = null,
            .status = "active",
            .search_config = .{ .null = {} },
            .trigger_config = null,
            .output_schema = null,
            .metadata = null,
            .webhook_url = "",
            .webhook_events = &.{},
            .webhook_secret = "",
            .next_run_at = null,
            .created_at = row.getInt64(8) orelse 0,
            .updated_at = row.getInt64(9) orelse 0,
        }) catch continue;
    }
    return items.toOwnedSlice() catch &.{};
}

pub fn createMonitorRun(pg_pool: *pool.Pool, monitor_id: [16]u8, allocator: std.mem.Allocator) ![16]u8 {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(monitor_id, allocator);
    defer allocator.free(id_str);
    var rs = try conn.query(
        "INSERT INTO monitor_runs (monitor_id, status, started_at) VALUES ($1, 'running', now()) RETURNING id",
        &.{id_str},
    );
    defer rs.deinit();
    if (!rs.next()) return std.mem.zeroes([16]u8);
    const row = rs.rowAt();
    const id_bytes = row.getBytes(0) orelse return std.mem.zeroes([16]u8);
    var run_id: [16]u8 = std.mem.zeroes([16]u8);
    @memcpy(run_id[0..@min(id_bytes.len, 16)], id_bytes[0..@min(id_bytes.len, 16)]);
    return run_id;
}

pub fn updateMonitorRun(pg_pool: *pool.Pool, run_id: [16]u8, status: []const u8, output: ?std.json.Value, fail_reason: ?[]const u8, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(run_id, allocator);
    defer allocator.free(id_str);
    _ = output;
    const fr = fail_reason orelse "";
    try conn.execCommand(
        "UPDATE monitor_runs SET status = $2, fail_reason = $3, completed_at = CASE WHEN $2 = 'completed' THEN now() ELSE completed_at END, failed_at = CASE WHEN $2 = 'failed' THEN now() ELSE failed_at END, updated_at = now() WHERE id = $1",
        &.{ id_str, status, fr },
    );
}

pub fn setMonitorNextRun(pg_pool: *pool.Pool, monitor_id: [16]u8, next_run_at: i64, allocator: std.mem.Allocator) !void {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const id_str = try uuid_util.toString(monitor_id, allocator);
    defer allocator.free(id_str);
    const ts_str = try std.fmt.allocPrint(allocator, "to_timestamp({d})", .{@divFloor(next_run_at, 1000)});
    defer allocator.free(ts_str);
    try conn.execCommand(
        "UPDATE monitors SET next_run_at = $2::timestamptz, updated_at = now() WHERE id = $1",
        &.{ id_str, ts_str },
    );
}

pub fn emitEvent(pg_pool: *pool.Pool, team_id: [16]u8, event_type: []const u8, data: std.json.Value, allocator: std.mem.Allocator) ![]const u8 {
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    var data_buf = std.ArrayList(u8).init(allocator);
    defer data_buf.deinit();
    try std.json.stringify(data, .{}, data_buf.writer());
    var rs = try conn.query(
        "INSERT INTO events (team_id, type, data) VALUES ($1, $2, $3::jsonb) RETURNING id::text",
        &.{ team_str, event_type, data_buf.items },
    );
    defer rs.deinit();
    if (!rs.next()) return try allocator.dupe(u8, "");
    return try allocator.dupe(u8, rs.rowAt().getString(0) orelse "");
}

pub fn listEvents(pg_pool: *pool.Pool, team_id: [16]u8, cursor: ?[]const u8, limit: usize, allocator: std.mem.Allocator) !common.PaginatedResult(common.EventRow) {
    _ = cursor;
    const conn = pg_pool.acquire();
    defer pg_pool.release(conn);
    const team_str = try uuid_util.toString(team_id, allocator);
    defer allocator.free(team_str);
    const lim = try std.fmt.allocPrint(allocator, "{d}", .{limit + 1});
    defer allocator.free(lim);
    var rs = try conn.query(
        "SELECT id, type, data::text, EXTRACT(EPOCH FROM created_at)*1000 FROM events WHERE team_id = $1 ORDER BY created_at DESC LIMIT $2",
        &.{ team_str, lim },
    );
    defer rs.deinit();
    var items = std.ArrayList(common.EventRow).init(allocator);
    while (rs.next()) {
        const row = rs.rowAt();
        const id_bytes = row.getBytes(0) orelse continue;
        var eid: [16]u8 = std.mem.zeroes([16]u8);
        @memcpy(eid[0..@min(id_bytes.len, 16)], id_bytes[0..@min(id_bytes.len, 16)]);
        try items.append(common.EventRow{
            .id = eid,
            .team_id = team_id,
            .type = try allocator.dupe(u8, row.getString(1) orelse ""),
            .data = .{ .null = {} },
            .created_at = row.getInt64(3) orelse 0,
        });
    }
    const all = try items.toOwnedSlice();
    const has_more = all.len > limit;
    return .{ .items = if (has_more) all[0..limit] else all, .has_more = has_more, .next_cursor = null };
}
