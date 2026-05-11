const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const crawler = @import("../contents/crawler.zig");
const highlights = @import("../contents/highlights.zig");
const queries = @import("../db/queries.zig");
const time_util = @import("../utils/time.zig");
const crypto = @import("../utils/crypto.zig");

pub fn handleContents(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    if (req.body.len == 0) return errorResponse(400, "Empty request body", "INVALID_REQUEST_BODY", allocator);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch {
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else {
        return errorResponse(400, "Request must be a JSON object", "INVALID_REQUEST_BODY", allocator);
    };

    const ids_val = obj.get("ids") orelse obj.get("urls") orelse {
        return errorResponse(400, "Missing required field: ids", "INVALID_REQUEST_BODY", allocator);
    };
    const ids_arr = if (ids_val == .array) ids_val.array else {
        return errorResponse(400, "ids must be an array", "INVALID_REQUEST_BODY", allocator);
    };

    if (ids_arr.items.len == 0) return errorResponse(400, "ids array is empty", "INVALID_REQUEST_BODY", allocator);
    if (ids_arr.items.len > 10) return errorResponse(400, "Maximum 10 URLs per request", "NUM_RESULTS_EXCEEDED", allocator);

    const want_text = blk: {
        const v = obj.get("text");
        if (v) |val| {
            if (val == .bool) break :blk val.bool;
            if (val == .object) break :blk true;
        }
        break :blk false;
    };
    const want_highlights = blk: {
        const v = obj.get("highlights");
        if (v) |val| {
            if (val == .bool) break :blk val.bool;
            if (val == .object) break :blk true;
        }
        break :blk false;
    };

    const web_crawler = crawler.Crawler{ .cfg = state.cfg };

    var results_buf = std.ArrayList(u8).init(allocator);
    defer results_buf.deinit();
    const w = results_buf.writer();

    var statuses_buf = std.ArrayList(u8).init(allocator);
    defer statuses_buf.deinit();
    const sw = statuses_buf.writer();

    var total_cost_cents: u32 = 0;
    try w.print("[", .{});
    try sw.print("[", .{});

    for (ids_arr.items, 0..) |id_val, i| {
        if (i > 0) {
            try w.print(",", .{});
            try sw.print(",", .{});
        }
        const url = if (id_val == .string) id_val.string else {
            try w.print("null", .{});
            try sw.print("{{\"id\":null,\"status\":\"error\",\"error\":\"invalid_url\"}}", .{});
            continue;
        };

        const crawl_result = web_crawler.fetch(url, allocator) catch |err| {
            std.log.warn("Crawl failed for {s}: {}", .{ url, err });
            try w.print("null", .{});
            try sw.print("{{\"id\":\"{s}\",\"status\":\"error\",\"error\":\"fetch_failed\"}}", .{url});
            continue;
        };

        try sw.print("{{\"id\":\"{s}\",\"status\":\"success\"}}", .{url});
        try w.print("{{\"url\":\"{s}\"", .{url});

        if (crawl_result.parsed.title) |title| {
            try w.print(",\"title\":", .{});
            try std.json.stringify(title, .{}, w);
        }

        if (want_text) {
            try w.print(",\"text\":", .{});
            try std.json.stringify(crawl_result.parsed.main_text, .{}, w);
            total_cost_cents += state.cfg.credit_contents_per_page_cents;
        }

        if (want_highlights) {
            const hl = highlights.extract(crawl_result.parsed.main_text, null, state.cfg.max_highlights_chars, allocator) catch &.{};
            try w.print(",\"highlights\":[", .{});
            for (hl, 0..) |h, hi| {
                if (hi > 0) try w.print(",", .{});
                try std.json.stringify(h, .{}, w);
            }
            try w.print("]", .{});
        }

        if (crawl_result.parsed.author) |author| {
            try w.print(",\"author\":", .{});
            try std.json.stringify(author, .{}, w);
        }
        if (crawl_result.parsed.published_at) |pub_date| {
            try w.print(",\"publishedDate\":", .{});
            try std.json.stringify(pub_date, .{}, w);
        }

        try w.print("}}", .{});

        const doc = common.DocumentRow{
            .id = url,
            .url = url,
            .domain = extractDomain(url) orelse url,
            .title = crawl_result.parsed.title,
            .author = crawl_result.parsed.author,
            .published_at = null,
            .crawled_at = time_util.nowMillis(),
            .body_text = crawl_result.parsed.main_text,
            .body_html = null,
            .embedding = null,
            .content_hash = crawl_result.content_hash,
            .language = null,
            .favicon_url = null,
            .image_url = null,
            .word_count = null,
        };
        queries.upsertDocument(state.pg_pool, doc, allocator) catch {};
    }

    try w.print("]", .{});
    try sw.print("]", .{});

    if (total_cost_cents > 0) {
        queries.deductTeamBalance(state.pg_pool, auth.team_id, @intCast(total_cost_cents), allocator) catch {};
    }

    const body = try std.fmt.allocPrint(allocator,
        "{{\"results\":{s},\"statuses\":{s},\"costDollars\":{{\"total\":{d:.4}}}}}",
        .{ results_buf.items, statuses_buf.items, @as(f64, @floatFromInt(total_cost_cents)) / 100.0 },
    );

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

fn extractDomain(url: []const u8) ?[]const u8 {
    var rest = url;
    if (std.mem.startsWith(u8, rest, "https://")) rest = rest[8..];
    if (std.mem.startsWith(u8, rest, "http://")) rest = rest[7..];
    const end = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
    return rest[0..end];
}

fn errorResponse(status: u16, message: []const u8, tag: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    const body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\",\"tag\":\"{s}\"}}", .{ message, tag });
    return common.HttpResponse{ .status = status, .headers = headers, .body = body };
}
