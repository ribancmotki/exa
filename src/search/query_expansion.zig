const std = @import("std");
const llm = @import("../llm/client.zig");

pub const QueryExpander = struct {
    llm_client: *llm.LlmClient,

    pub fn expand(
        self: *const QueryExpander,
        query: []const u8,
        n: usize,
        allocator: std.mem.Allocator,
    ) ![][]const u8 {
        _ = self;
        _ = query;
        _ = n;
        _ = allocator;
        return &.{};
    }
};