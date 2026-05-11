const std = @import("std");
const llm = @import("../llm/client.zig");

pub fn generate(
    llm_client: *llm.LlmClient,
    text: []const u8,
    query: ?[]const u8,
    schema: ?std.json.Value,
    allocator: std.mem.Allocator,
) ![]const u8 {
    _ = llm_client;
    _ = text;
    _ = query;
    _ = schema;
    _ = allocator;
    return "";
}