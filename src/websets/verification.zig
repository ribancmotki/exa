const std = @import("std");
const webset = @import("../types/webset.zig");
const llm = @import("../llm/client.zig");

pub const EvaluationResult = struct {
    criterion: []const u8,
    result: []const u8,
    reasoning: ?[]const u8,
    citations: ?[][]const u8,
};

pub fn verify(
    result: anyopaque,
    criteria: []webset.Criterion,
    llm_client: *llm.LlmClient,
    allocator: std.mem.Allocator,
) ![]EvaluationResult {
    _ = result;
    _ = criteria;
    _ = llm_client;
    _ = allocator;
    return &.{};
}