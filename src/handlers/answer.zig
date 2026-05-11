const std = @import("std");
const common = @import("../types/common.zig");
const search_types = @import("../types/search.zig");
const app_state = @import("../app_state.zig");
const search_engine = @import("../search/engine.zig");
const queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");
const time_util = @import("../utils/time.zig");

pub fn handleAnswer(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    if (req.body.len == 0) return errorResponse(400, "Empty request body", "INVALID_REQUEST_BODY", allocator);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch {
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else {
        return errorResponse(400, "Request must be a JSON object", "INVALID_REQUEST_BODY", allocator);
    };

    const query_val = obj.get("query") orelse return errorResponse(400, "Missing required field: query", "INVALID_REQUEST_BODY", allocator);
    const query = if (query_val == .string) query_val.string else return errorResponse(400, "query must be a string", "INVALID_REQUEST_BODY", allocator);

    const engine = search_engine.SearchEngine{
        .cfg = state.cfg,
        .pg_pool = state.pg_pool,
        .redis_pool = state.redis_pool,
        .hnsw_index = state.hnsw_index,
        .embedding_client = state.embedding_client,
        .llm_client = state.llm_client,
    };

    const search_req = search_types.SearchRequest{
        .query = query,
        .type = .neural,
        .num_results = 5,
    };

    const search_resp = try engine.search(search_req, auth, allocator);

    var context_buf = std.ArrayList(u8).init(allocator);
    defer context_buf.deinit();
    for (search_resp.results) |r| {
        if (r.text) |text| {
            try context_buf.appendSlice(text);
            try context_buf.append('\n');
        }
    }

    const system_prompt =
        \\You are a helpful AI assistant that answers questions based on web search results.
        \\Provide accurate, concise answers with citations to the sources.
    ;

    const user_prompt = try std.fmt.allocPrint(allocator,
        "Question: {s}\n\nSources:\n{s}\n\nAnswer the question based on these sources.",
        .{ query, context_buf.items },
    );
    defer allocator.free(user_prompt);

    const answer_text = try state.llm_client.complete(system_prompt, user_prompt, 2048, allocator);
    defer allocator.free(answer_text);

    var citations_buf = std.ArrayList(u8).init(allocator);
    defer citations_buf.deinit();
    try citations_buf.appendSlice("[");
    for (search_resp.results, 0..) |r, i| {
        if (i > 0) try citations_buf.appendSlice(",");
        try citations_buf.print("{{\"url\":\"{s}\"", .{r.url});
        if (r.title) |t| try citations_buf.print(",\"title\":{s}", .{try jsonString(t, allocator)});
        try citations_buf.appendSlice("}");
    }
    try citations_buf.appendSlice("]");

    const cost_cents = state.cfg.credit_answer_cents;
    queries.deductTeamBalance(state.pg_pool, auth.team_id, @intCast(cost_cents), allocator) catch {};

    const answer_json = try jsonString(answer_text, allocator);
    defer allocator.free(answer_json);

    const body = try std.fmt.allocPrint(allocator,
        "{{\"requestId\":\"{s}\",\"answer\":{s},\"citations\":{s},\"costDollars\":{{\"total\":{d:.4}}}}}",
        .{ search_resp.request_id, answer_json, citations_buf.items, @as(f64, @floatFromInt(cost_cents)) / 100.0 },
    );

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn handleChatCompletions(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = auth;
    if (req.body.len == 0) return errorResponse(400, "Empty body", "INVALID_REQUEST_BODY", allocator);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{ .allocate = .alloc_always }) catch {
        return errorResponse(400, "Invalid JSON", "INVALID_REQUEST_BODY", allocator);
    };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return errorResponse(400, "Invalid request", "INVALID_REQUEST_BODY", allocator);
    const msgs = obj.get("messages") orelse return errorResponse(400, "Missing messages", "INVALID_REQUEST_BODY", allocator);
    var last_content: []const u8 = "";
    if (msgs == .array) {
        for (msgs.array.items) |msg| {
            if (msg != .object) continue;
            const content = msg.object.get("content") orelse continue;
            if (content == .string) last_content = content.string;
        }
    }

    const response_text = try state.llm_client.complete(null, last_content, 2048, allocator);
    defer allocator.free(response_text);

    const resp_json = try jsonString(response_text, allocator);
    defer allocator.free(resp_json);

    const model = if (obj.get("model")) |m| if (m == .string) m.string else "exa" else "exa";
    const ts = time_util.nowSeconds();
    const id_val = uuid_util.generate();
    const id_str = try uuid_util.toString(id_val, allocator);
    defer allocator.free(id_str);

    const body = try std.fmt.allocPrint(allocator,
        "{{\"id\":\"chatcmpl-{s}\",\"object\":\"chat.completion\",\"created\":{d},\"model\":\"{s}\",\"choices\":[{{\"index\":0,\"message\":{{\"role\":\"assistant\",\"content\":{s}}},\"finish_reason\":\"stop\"}}],\"usage\":{{\"prompt_tokens\":0,\"completion_tokens\":0,\"total_tokens\":0}}}}",
        .{ id_str, ts, model, resp_json },
    );

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{ .status = 200, .headers = headers, .body = body };
}

pub fn handleResponses(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    return handleChatCompletions(req, auth, state, allocator);
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
