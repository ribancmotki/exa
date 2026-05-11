const std = @import("std");
const config = @import("config.zig");
const pool = @import("db/pool.zig");
const redis = @import("cache/redis.zig");
const hnsw = @import("index/hnsw.zig");
const embeddings = @import("search/embeddings.zig");
const llm = @import("llm/client.zig");

pub const AppState = struct {
    cfg: *const config.Config,
    pg_pool: *pool.Pool,
    redis_pool: *redis.Pool,
    hnsw_index: *hnsw.HnswIndex,
    embedding_client: *embeddings.EmbeddingClient,
    llm_client: *llm.LlmClient,
    allocator: std.mem.Allocator,
};
