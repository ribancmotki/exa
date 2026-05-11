const std = @import("std");
const common = @import("../types/common.zig");
const search = @import("../types/search.zig");
const db_queries = @import("../db/queries.zig");
const hnsw = @import("../index/hnsw.zig");
const embeddings = @import("./embeddings.zig");

pub fn neuralSearch(
    db_pool: *anyopaque,
    hnsw_index: *hnsw.HnswIndex,
    embedding_client: *embeddings.EmbeddingClient,
    req: search.SearchRequest,
    allocator: std.mem.Allocator,
) ![]common.ScoredDoc {
    _ = db_pool;
    _ = hnsw_index;
    _ = embedding_client;
    _ = req;
    _ = allocator;
    return &.{};
}