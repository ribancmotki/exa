const std = @import("std");
const common = @import("../types/common.zig");
const search_types = @import("../types/search.zig");
const app_state = @import("../app_state.zig");
const search_engine = @import("../search/engine.zig");
const rate_limiter = @import("../middleware/rate_limiter.zig");
const queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");
const time_util = @import("../utils/time.zig");

pub fn handleSearch(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    const rl = try rate_limiter.check(state.redis_pool, auth.api_key_id, auth.rate_limit_qps, auth.rate_limit_qps * 3, allocator);
    if (!rl.allowed) {
        var h = std.StringHashMap([]const u8).init(allocator);
        try h.put("content-type", "application/json");
        try h.put("retry-after", try std.fmt.allocPrint(allocator, "{d}", .{@divFloor(rl.reset_after_ms, 1000) + 1}));
        return common.HttpResponse{
            .status = 429,
            .headers = h,
            .body = "{\"error\":\"Rate limit exceeded\",\"tag\":\"RATE_LIMIT_EXCEEDED\"}",
        };
    }

    if (req.body.len == 0) return errorResponse(400, "Empty request body", "INVALID_REQUEST_BODY", allocator);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch {
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else {
        return errorResponse(400, "Request must be a JSON object", "INVALID_REQUEST_BODY", allocator);
    };

    const query_val = obj.get("query") orelse obj.get("q") orelse {
        return errorResponse(400, "Missing required field: query", "INVALID_REQUEST_BODY", allocator);
    };
    const query = if (query_val == .string) query_val.string else {
        return errorResponse(400, "query must be a string", "INVALID_REQUEST_BODY", allocator);
    };
    if (query.len == 0) return errorResponse(400, "query cannot be empty", "INVALID_REQUEST_BODY", allocator);

    const num_results: usize = blk: {
        const nr = obj.get("numResults") orelse obj.get("num_results");
        if (nr) |v| if (v == .integer) break :blk @min(@as(usize, @intCast(@max(1, v.integer))), state.cfg.max_search_results);
        break :blk state.cfg.default_search_results;
    };

    const search_type_str = blk: {
        const t = obj.get("type");
        if (t) |v| if (v == .string) break :blk v.string;
        break :blk "auto";
    };
    const search_type: search_types.SearchType = std.meta.stringToEnum(search_types.SearchType, search_type_str) orelse .auto;

    const category: ?search_types.Category = blk: {
        const v = obj.get("category");
        if (v) |val| if (val == .string) break :blk std.meta.stringToEnum(search_types.Category, val.string);
        break :blk null;
    };

    const contents_opts: ?search_types.ContentsOptions = blk: {
        const v = obj.get("contents");
        if (v == null) {
            const want_text = obj.get("text") != null;
            const want_highlights = obj.get("highlights") != null;
            const want_summary = obj.get("summary") != null;
            if (want_text or want_highlights or want_summary) {
                break :blk search_types.ContentsOptions{
                    .text = if (want_text) true else null,
                    .highlights = if (want_highlights) true else null,
                    .summary = if (want_summary) true else null,
                };
            }
            break :blk null;
        }
        if (v) |val| if (val == .object or val == .bool) {
            break :blk search_types.ContentsOptions{
                .text = if (obj.get("text")) |t| (t == .bool and t.bool) else null,
                .highlights = if (obj.get("highlights")) |h| (h == .bool and h.bool) else null,
                .summary = if (obj.get("summary")) |s| (s == .bool and s.bool) else null,
            };
        };
        break :blk null;
    };

    const search_req = search_types.SearchRequest{
        .query = query,
        .type = search_type,
        .num_results = num_results,
        .category = category,
        .contents = contents_opts,
    };

    const start_time = time_util.nowMillis();

    const engine = search_engine.SearchEngine{
        .cfg = state.cfg,
        .pg_pool = state.pg_pool,
        .redis_pool = state.redis_pool,
        .hnsw_index = state.hnsw_index,
        .embedding_client = state.embedding_client,
        .llm_client = state.llm_client,
    };

    const response = try engine.search(search_req, auth, allocator);
    const search_time_ms: u64 = @intCast(@max(0, time_util.nowMillis() - start_time));

    const cost_cents = state.cfg.credit_search_auto_cents;
    _ = queries.deductTeamBalance(state.pg_pool, auth.team_id, @as(i64, cost_cents), allocator) catch 0;

    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();
    const w = body.writer();
    try w.print("{{\"requestId\":\"{s}\",\"resolvedSearchType\":\"{s}\",\"results\":[", .{
        response.request_id,
        search_type_str,
    });
    for (response.results, 0..) |result, i| {
        if (i > 0) try w.print(",", .{});
        try w.print("{{\"id\":\"{s}\",\"url\":\"{s}\"", .{ result.id, result.url });
        if (result.title) |t| try w.print(",\"title\":{s}", .{try jsonString(t, allocator)});
        if (result.score) |s| try w.print(",\"score\":{d:.6}", .{s});
        if (result.author) |a| try w.print(",\"author\":{s}", .{try jsonString(a, allocator)});
        if (result.favicon) |f| try w.print(",\"favicon\":{s}", .{try jsonString(f, allocator)});
        if (result.text) |t| try w.print(",\"text\":{s}", .{try jsonString(t, allocator)});
        try w.print("}}", .{});
    }
    try w.print("],\"searchTime\":{d},\"costDollars\":{{\"total\":{d:.4}}}}}", .{
        @as(f64, @floatFromInt(search_time_ms)) / 1000.0,
        @as(f64, @floatFromInt(cost_cents)) / 100.0,
    });

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{
        .status = 200,
        .headers = headers,
        .body = try body.toOwnedSlice(),
    };
}

pub fn handleContext(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;
    _ = auth;
    _ = state;
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{
        .status = 200,
        .headers = headers,
        .body = "{\"context\":\"\",\"contextSnippets\":[]}",
    };
}

fn errorResponse(status: u16, message: []const u8, tag: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    const body = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\",\"tag\":\"{s}\"}}", .{ message, tag });
    return common.HttpResponse{ .status = status, .headers = headers, .body = body };
}

fn jsonString(s: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    try std.json.stringify(s, .{}, buf.writer());
    return buf.toOwnedSlice();
}
