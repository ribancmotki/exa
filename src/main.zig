const std = @import("std");
const config = @import("config.zig");
const app_state = @import("app_state.zig");
const server = @import("server.zig");
const db_pool = @import("db/pool.zig");
const db_migrations = @import("db/migrations.zig");
const redis = @import("cache/redis.zig");
const hnsw = @import("index/hnsw.zig");
const embeddings = @import("search/embeddings.zig");
const llm = @import("llm/client.zig");
const scheduler = @import("monitors/scheduler.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("Search Platform v{s} starting...", .{config.VERSION});

    var cfg = config.Config.load(allocator) catch |err| {
        std.log.err("Failed to load configuration: {}", .{err});
        std.process.exit(1);
    };
    defer cfg.deinit();

    std.log.info("Connecting to PostgreSQL at {s}...", .{cfg.postgres_dsn});
    const pg = db_pool.Pool.init(allocator, cfg.postgres_dsn, cfg.db_pool_size) catch |err| {
        std.log.err("Failed to connect to PostgreSQL: {}", .{err});
        std.process.exit(1);
    };
    defer pg.deinit();

    std.log.info("Running database migrations...", .{});
    db_migrations.Migrations.run(pg, allocator) catch |err| {
        std.log.err("Database migrations failed: {}", .{err});
        std.process.exit(1);
    };

    std.log.info("Connecting to Redis at {s}...", .{cfg.redis_url});
    const rp = redis.Pool.init(allocator, cfg.redis_url, cfg.redis_pool_size) catch
        redis.Pool.init(allocator, "redis://127.0.0.1:6379", 1) catch {
        std.log.err("Cannot connect to Redis at all, exiting", .{});
        std.process.exit(1);
    };
    defer rp.deinit();

    std.log.info("Initializing HNSW vector index from {s}...", .{cfg.index_data_dir});
    var index = hnsw.HnswIndex.load(cfg.index_data_dir, cfg.embedding_dim, allocator) catch |err| blk: {
        std.log.warn("Could not load existing HNSW index (starting fresh): {}", .{err});
        break :blk hnsw.HnswIndex{
            .dim = cfg.embedding_dim,
            .m = 16,
            .ef_construction = 200,
            .ef_search = 50,
            .nodes = std.ArrayList(hnsw.HnswIndex.HnswNode).init(allocator),
            .vectors = std.ArrayList([]f32).init(allocator),
            .mutex = std.Thread.RwLock{},
            .allocator = allocator,
            .path = cfg.index_data_dir,
        };
    };
    defer index.deinit();

    var emb_client = embeddings.EmbeddingClient{
        .url = cfg.embedding_model_url,
        .model = cfg.embedding_model_name,
        .dim = cfg.embedding_dim,
    };

    var llm_client = llm.LlmClient{
        .api_key = cfg.anthropic_api_key,
        .model = "claude-opus-4-5",
        .max_tokens = 4096,
    };

    var state = app_state.AppState{
        .cfg = &cfg,
        .pg_pool = pg,
        .redis_pool = rp,
        .hnsw_index = &index,
        .embedding_client = &emb_client,
        .llm_client = &llm_client,
        .allocator = allocator,
    };

    const sched_thread: ?std.Thread = std.Thread.spawn(.{}, scheduler.Scheduler.run, .{&state}) catch |err| blk: {
        std.log.warn("Failed to start monitor scheduler thread: {}", .{err});
        break :blk null;
    };
    if (sched_thread) |t| t.detach();

    std.log.info("Starting HTTP server on {s}:{d}...", .{ cfg.listen_host, cfg.listen_port });
    try server.Server.run(&state, allocator);
}
