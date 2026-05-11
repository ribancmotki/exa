const std = @import("std");
const common = @import("../types/common.zig");
const search_types = @import("../types/search.zig");
const db_pool = @import("../db/pool.zig");
const redis_pool = @import("../cache/redis.zig");
const hnsw_mod = @import("../index/hnsw.zig");
const embeddings_mod = @import("./embeddings.zig");
const llm_mod = @import("../llm/client.zig");
const config_mod = @import("../config.zig");
const db_queries = @import("../db/queries.zig");
const uuid_util = @import("../utils/uuid.zig");

pub const SearchEngine = struct {
    cfg: *const config_mod.Config,
    pg_pool: *db_pool.Pool,
    redis_pool: *redis_pool.Pool,
    hnsw_index: *hnsw_mod.HnswIndex,
    embedding_client: *embeddings_mod.EmbeddingClient,
    llm_client: *llm_mod.LlmClient,

    pub fn search(
        self: *const SearchEngine,
        req: search_types.SearchRequest,
        auth: common.AuthContext,
        allocator: std.mem.Allocator,
    ) !search_types.SearchResponse {
        _ = auth;

        const request_id = uuid_util.generate();
        const request_id_str = try uuid_util.toString(request_id, allocator);

        const cache_client = self.redis_pool.acquire();
        defer self.redis_pool.release(cache_client);

        const type_str = @tagName(req.type);
        const cache_key = try std.fmt.allocPrint(allocator, "search:{s}:{s}:{d}", .{
            type_str, req.query, req.num_results,
        });
        defer allocator.free(cache_key);

        var results = std.ArrayList(search_types.SearchResult).init(allocator);

        const do_neural = req.type == .neural or req.type == .auto or req.type == .fast;
        const do_keyword = req.type == .keyword or req.type == .auto or req.type == .fast or req.type == .instant;

        if (do_neural) {
            const neural_docs = self.neuralSearch(req.query, req.num_results, allocator) catch &.{};
            for (neural_docs) |doc| {
                try results.append(search_types.SearchResult{
                    .id = doc.id,
                    .url = doc.url,
                    .title = doc.title,
                    .score = doc.score,
                    .published_date = doc.published_at,
                    .author = doc.author,
                    .image = doc.image_url,
                    .favicon = doc.favicon_url,
                    .text = doc.body_text,
                    .highlights = null,
                    .highlight_scores = null,
                    .summary = null,
                    .subpages = null,
                    .extras = null,
                });
            }
        }

        if (do_keyword) {
            const keyword_docs = self.keywordSearch(req.query, req.num_results, allocator) catch &.{};
            for (keyword_docs) |doc| {
                var already = false;
                for (results.items) |r| {
                    if (std.mem.eql(u8, r.url, doc.url)) { already = true; break; }
                }
                if (!already) {
                    try results.append(search_types.SearchResult{
                        .id = doc.id,
                        .url = doc.url,
                        .title = doc.title,
                        .score = doc.score,
                        .published_date = doc.published_at,
                        .author = doc.author,
                        .image = doc.image_url,
                        .favicon = doc.favicon_url,
                        .text = doc.body_text,
                        .highlights = null,
                        .highlight_scores = null,
                        .summary = null,
                        .subpages = null,
                        .extras = null,
                    });
                }
            }
        }

        if (results.items.len > req.num_results) {
            results.shrinkRetainingCapacity(req.num_results);
        }

        return search_types.SearchResponse{
            .request_id = request_id_str,
            .search_type = type_str,
            .results = try results.toOwnedSlice(),
            .output = null,
            .auto_date = null,
            .context = null,
            .statuses = null,
            .cost_dollars = common.CostDollars.new(),
            .search_time = null,
        };
    }

    fn neuralSearch(self: *const SearchEngine, query: []const u8, limit: usize, allocator: std.mem.Allocator) ![]common.ScoredDoc {
        const embedding = try self.embedding_client.embed(query, allocator);
        defer allocator.free(embedding);

        const hits = try self.hnsw_index.search(embedding, limit, allocator);
        var docs = std.ArrayList(common.ScoredDoc).init(allocator);
        for (hits) |hit| {
            try docs.append(common.ScoredDoc{
                .id = try allocator.dupe(u8, hit.id),
                .url = try allocator.dupe(u8, hit.id),
                .title = null,
                .score = hit.score,
                .body_text = null,
                .published_at = null,
                .author = null,
                .favicon_url = null,
                .image_url = null,
            });
        }
        return docs.toOwnedSlice();
    }

    fn keywordSearch(self: *const SearchEngine, query: []const u8, limit: usize, allocator: std.mem.Allocator) ![]common.ScoredDoc {
        const filters = common.SearchFilters{};
        const doc_rows = db_queries.searchByFullText(self.pg_pool, query, limit, filters, allocator) catch return &.{};
        var docs = std.ArrayList(common.ScoredDoc).init(allocator);
        for (doc_rows) |row| {
            try docs.append(common.ScoredDoc{
                .id = row.id,
                .url = row.url,
                .title = row.title,
                .score = 0.5,
                .body_text = row.body_text,
                .published_at = null,
                .author = row.author,
                .favicon_url = row.favicon_url,
                .image_url = row.image_url,
            });
        }
        return docs.toOwnedSlice();
    }
};
