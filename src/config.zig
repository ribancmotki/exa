const std = @import("std");

pub const VERSION = "0.1.0";
pub const BUILD_TIME = "2025-05-11";

pub const Config = struct {
    listen_host: []const u8,
    listen_port: u16,
    postgres_dsn: []const u8,
    redis_url: []const u8,
    cerebras_api_key: []const u8,
    embedding_model_url: []const u8,
    embedding_model_name: []const u8,
    embedding_dim: usize,
    reranker_url: []const u8,
    crawler_timeout_ms: u64,
    crawler_max_body_bytes: usize,
    crawler_user_agent: []const u8,
    max_search_results: usize,
    default_search_results: usize,
    max_highlights_chars: usize,
    rate_limit_qps: u32,
    rate_limit_burst: u32,
    webhook_signing_secret_length: usize,
    webhook_delivery_timeout_ms: u64,
    webhook_max_retries: u8,
    monitor_min_interval_hours: u32,
    credit_search_auto_cents: u32,
    credit_search_fast_cents: u32,
    credit_search_instant_cents: u32,
    credit_search_deep_lite_cents: u32,
    credit_search_deep_cents: u32,
    credit_search_deep_reasoning_cents: u32,
    credit_contents_per_page_cents: u32,
    credit_summary_per_page_cents: u32,
    credit_answer_cents: u32,
    log_level: []const u8,
    mcp_listen_port: u16,
    worker_threads: usize,
    db_pool_size: usize,
    redis_pool_size: usize,
    index_data_dir: []const u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator) !Config {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const worker_threads = std.Thread.getCpuCount() catch 4;

        return Config{
            .listen_host = try getEnvOrDefault(&env_map, "LISTEN_HOST", "0.0.0.0", allocator),
            .listen_port = try getEnvOrDefaultU16(&env_map, "LISTEN_PORT", 8080),
            .postgres_dsn = try getEnvRequired(&env_map, "POSTGRES_DSN", allocator),
            .redis_url = try getEnvOrDefault(&env_map, "REDIS_URL", "redis://localhost:6379", allocator),
            .cerebras_api_key = try getEnvOrDefault(&env_map, "CEREBRAS_API_KEY", "", allocator),
            .embedding_model_url = try getEnvOrDefault(&env_map, "EMBEDDING_MODEL_URL", "http://localhost:11434/api/embeddings", allocator),
            .embedding_model_name = try getEnvOrDefault(&env_map, "EMBEDDING_MODEL_NAME", "nomic-embed-text", allocator),
            .embedding_dim = try getEnvOrDefaultUsize(&env_map, "EMBEDDING_DIM", 768),
            .reranker_url = try getEnvOrDefault(&env_map, "RERANKER_URL", "http://localhost:8081/rerank", allocator),
            .crawler_timeout_ms = try getEnvOrDefaultU64(&env_map, "CRAWLER_TIMEOUT_MS", 10000),
            .crawler_max_body_bytes = try getEnvOrDefaultUsize(&env_map, "CRAWLER_MAX_BODY_BYTES", 5_242_880),
            .crawler_user_agent = try getEnvOrDefault(&env_map, "CRAWLER_USER_AGENT", "SearchPlatformBot/0.1 (+https://search-platform.io/bot)", allocator),
            .max_search_results = try getEnvOrDefaultUsize(&env_map, "MAX_SEARCH_RESULTS", 100),
            .default_search_results = try getEnvOrDefaultUsize(&env_map, "DEFAULT_SEARCH_RESULTS", 10),
            .max_highlights_chars = try getEnvOrDefaultUsize(&env_map, "MAX_HIGHLIGHTS_CHARS", 8000),
            .rate_limit_qps = try getEnvOrDefaultU32(&env_map, "RATE_LIMIT_QPS", 10),
            .rate_limit_burst = try getEnvOrDefaultU32(&env_map, "RATE_LIMIT_BURST", 20),
            .webhook_signing_secret_length = try getEnvOrDefaultUsize(&env_map, "WEBHOOK_SIGNING_SECRET_LENGTH", 32),
            .webhook_delivery_timeout_ms = try getEnvOrDefaultU64(&env_map, "WEBHOOK_DELIVERY_TIMEOUT_MS", 5000),
            .webhook_max_retries = try getEnvOrDefaultU8(&env_map, "WEBHOOK_MAX_RETRIES", 5),
            .monitor_min_interval_hours = try getEnvOrDefaultU32(&env_map, "MONITOR_MIN_INTERVAL_HOURS", 1),
            .credit_search_auto_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_AUTO_CENTS", 700),
            .credit_search_fast_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_FAST_CENTS", 700),
            .credit_search_instant_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_INSTANT_CENTS", 700),
            .credit_search_deep_lite_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_DEEP_LITE_CENTS", 1200),
            .credit_search_deep_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_DEEP_CENTS", 1200),
            .credit_search_deep_reasoning_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SEARCH_DEEP_REASONING_CENTS", 1500),
            .credit_contents_per_page_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_CONTENTS_PER_PAGE_CENTS", 100),
            .credit_summary_per_page_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_SUMMARY_PER_PAGE_CENTS", 100),
            .credit_answer_cents = try getEnvOrDefaultU32(&env_map, "CREDIT_ANSWER_CENTS", 500),
            .log_level = try getEnvOrDefault(&env_map, "LOG_LEVEL", "info", allocator),
            .mcp_listen_port = try getEnvOrDefaultU16(&env_map, "MCP_LISTEN_PORT", 3000),
            .worker_threads = worker_threads,
            .db_pool_size = try getEnvOrDefaultUsize(&env_map, "DB_POOL_SIZE", 16),
            .redis_pool_size = try getEnvOrDefaultUsize(&env_map, "REDIS_POOL_SIZE", 8),
            .index_data_dir = try getEnvOrDefault(&env_map, "INDEX_DATA_DIR", "./data/index", allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const Config) void {
        self.allocator.free(self.listen_host);
        self.allocator.free(self.postgres_dsn);
        self.allocator.free(self.redis_url);
        self.allocator.free(self.cerebras_api_key);
        self.allocator.free(self.embedding_model_url);
        self.allocator.free(self.embedding_model_name);
        self.allocator.free(self.reranker_url);
        self.allocator.free(self.crawler_user_agent);
        self.allocator.free(self.log_level);
        self.allocator.free(self.index_data_dir);
    }
};

fn getEnvRequired(env_map: *const std.process.EnvMap, key: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const value = env_map.get(key) orelse {
        std.log.err("Missing required environment variable: {s}", .{key});
        return error.MissingRequiredEnvVar;
    };
    return allocator.dupe(u8, value);
}

fn getEnvOrDefault(env_map: *const std.process.EnvMap, key: []const u8, default: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const value = env_map.get(key) orelse default;
    return allocator.dupe(u8, value);
}

fn getEnvOrDefaultU16(env_map: *const std.process.EnvMap, key: []const u8, default: u16) !u16 {
    const value = env_map.get(key) orelse return default;
    return std.fmt.parseInt(u16, value, 10) catch error.ConfigParseError;
}

fn getEnvOrDefaultU32(env_map: *const std.process.EnvMap, key: []const u8, default: u32) !u32 {
    const value = env_map.get(key) orelse return default;
    return std.fmt.parseInt(u32, value, 10) catch error.ConfigParseError;
}

fn getEnvOrDefaultU64(env_map: *const std.process.EnvMap, key: []const u8, default: u64) !u64 {
    const value = env_map.get(key) orelse return default;
    return std.fmt.parseInt(u64, value, 10) catch error.ConfigParseError;
}

fn getEnvOrDefaultU8(env_map: *const std.process.EnvMap, key: []const u8, default: u8) !u8 {
    const value = env_map.get(key) orelse return default;
    return std.fmt.parseInt(u8, value, 10) catch error.ConfigParseError;
}

fn getEnvOrDefaultUsize(env_map: *const std.process.EnvMap, key: []const u8, default: usize) !usize {
    const value = env_map.get(key) orelse return default;
    return std.fmt.parseInt(usize, value, 10) catch error.ConfigParseError;
}
