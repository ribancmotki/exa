const std = @import("std");
const common = @import("../types/common.zig");
const search = @import("../types/search.zig");
const llm = @import("../llm/client.zig");

pub fn deepLiteSearch(
    req: search.SearchRequest,
    llm_client: *llm.LlmClient,
    allocator: std.mem.Allocator,
) !search.SearchResponse {
    _ = req;
    _ = llm_client;
    _ = allocator;
    
    return search.SearchResponse{
        .request_id = "",
        .search_type = @as([]const u8, "deep-lite"),
        .results = &.{},
        .output = null,
        .auto_date = null,
        .context = null,
        .statuses = null,
        .cost_dollars = common.CostDollars.new(),
        .search_time = null,
    };
}