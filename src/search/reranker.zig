const std = @import("std");
const common = @import("../types/common.zig");
const http_client = @import("../utils/http_client.zig");

pub const Reranker = struct {
    url: []const u8,
    http_client: ?http_client.HttpClient = null,

    pub fn init(url: []const u8) !Reranker {
        const client = http_client.HttpClient.init(url, 10000) catch null;
        return Reranker{
            .url = url,
            .http_client = client,
        };
    }

    pub fn rerank(
        self: *const Reranker,
        query: []const u8,
        docs: []common.ScoredDoc,
        allocator: std.mem.Allocator,
    ) ![]common.ScoredDoc {
        _ = self;
        _ = query;
        _ = docs;
        _ = allocator;
        return &.{};
    }
};