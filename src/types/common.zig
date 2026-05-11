const std = @import("std");

pub const PaginatedResponse = struct {
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const CostDollars = struct {
    total: f64,
    search: ?SearchCost,
    contents: ?ContentsCost,

    pub const SearchCost = struct {
        neural: f64 = 0,
        keyword: f64 = 0,
    };
    pub const ContentsCost = struct {
        text: f64 = 0,
        summary: f64 = 0,
    };

    pub fn new() CostDollars {
        return .{ .total = 0, .search = null, .contents = null };
    }

    pub fn toDollars(cents: i64) f64 {
        return @as(f64, @floatFromInt(cents)) / 100.0;
    }
};

pub const Reference = struct {
    title: ?[]const u8,
    snippet: ?[]const u8,
    url: []const u8,
};

pub const ApiError = struct {
    request_id: []const u8,
    @"error": []const u8,
    tag: []const u8,
};

pub const AuthContext = struct {
    api_key_id: [16]u8,
    team_id: [16]u8,
    team_balance_cents: i64,
    rate_limit_qps: u32,
    key_budget_cents: ?i64,
    key_spent_cents: i64,
};

pub const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    query_params: std.StringHashMap([]const u8),
    request_id: [16]u8,
};

pub const HttpResponse = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    is_sse: bool = false,
};

pub const RateLimitResult = struct {
    allowed: bool,
    remaining: u32,
    reset_after_ms: u64,
};

pub const ScoredDoc = struct {
    id: []const u8,
    url: []const u8,
    title: ?[]const u8,
    score: f32,
    body_text: ?[]const u8,
    published_at: ?[]const u8,
    author: ?[]const u8,
    favicon_url: ?[]const u8,
    image_url: ?[]const u8,
};

pub const SearchHit = struct {
    id: []const u8,
    score: f32,
};

pub const SearchFilters = struct {
    include_domains: ?[][]const u8 = null,
    exclude_domains: ?[][]const u8 = null,
    start_published_date: ?i64 = null,
    end_published_date: ?i64 = null,
    start_crawl_date: ?i64 = null,
    end_crawl_date: ?i64 = null,
    include_text: ?[][]const u8 = null,
    exclude_text: ?[][]const u8 = null,
};

pub fn PaginatedResult(comptime T: type) type {
    return struct {
        items: []T,
        has_more: bool,
        next_cursor: ?[]const u8,
    };
}

pub const ApiKeyRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    name: ?[]const u8,
    key_hash: [32]u8,
    key_prefix: [8]u8,
    rate_limit_qps: ?u32,
    budget_cents: ?i64,
    spent_cents: i64,
    created_at: i64,
    revoked_at: ?i64,
};

pub const TeamRow = struct {
    id: [16]u8,
    name: []const u8,
    credit_balance_cents: i64,
    created_at: i64,
};

pub const DocumentRow = struct {
    id: []const u8,
    url: []const u8,
    title: ?[]const u8,
    author: ?[]const u8,
    published_at: ?i64,
    crawled_at: i64,
    body_text: ?[]const u8,
    body_html: ?[]const u8,
    embedding: ?[]f32,
    content_hash: [32]u8,
    domain: []const u8,
    language: ?[]const u8,
    favicon_url: ?[]const u8,
    image_url: ?[]const u8,
    word_count: ?i32,
};

pub const MonitorRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    name: ?[]const u8,
    status: []const u8,
    search_config: std.json.Value,
    trigger_config: ?std.json.Value,
    output_schema: ?std.json.Value,
    metadata: ?std.json.Value,
    webhook_url: []const u8,
    webhook_events: [][]const u8,
    webhook_secret: []const u8,
    next_run_at: ?i64,
    created_at: i64,
    updated_at: i64,
};

pub const MonitorRunRow = struct {
    id: [16]u8,
    monitor_id: [16]u8,
    status: []const u8,
    output: ?std.json.Value,
    fail_reason: ?[]const u8,
    started_at: ?i64,
    completed_at: ?i64,
    failed_at: ?i64,
    cancelled_at: ?i64,
    duration_ms: ?i32,
    created_at: i64,
    updated_at: i64,
};

pub const WebsetRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    external_id: ?[]const u8,
    status: []const u8,
    metadata: ?std.json.Value,
    created_at: i64,
    updated_at: i64,
};

pub const WebsetSearchRow = struct {
    id: [16]u8,
    webset_id: [16]u8,
    status: []const u8,
    query: []const u8,
    entity_type: ?[]const u8,
    entity_description: ?[]const u8,
    criteria: std.json.Value,
    count: i32,
    max_people_per_company: ?i32,
    behaviour: []const u8,
    progress_found: i32,
    progress_completion: f32,
    metadata: ?std.json.Value,
    created_at: i64,
    updated_at: i64,
};

pub const WebsetItemRow = struct {
    id: [16]u8,
    webset_id: [16]u8,
    source: []const u8,
    source_id: ?[16]u8,
    properties: std.json.Value,
    evaluations: std.json.Value,
    enrichments: std.json.Value,
    created_at: i64,
    updated_at: i64,
};

pub const WebsetEnrichmentRow = struct {
    id: [16]u8,
    webset_id: [16]u8,
    status: []const u8,
    title: ?[]const u8,
    description: []const u8,
    format: ?[]const u8,
    options: ?std.json.Value,
    instructions: ?[]const u8,
    metadata: ?std.json.Value,
    created_at: i64,
    updated_at: i64,
};

pub const EventRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    type: []const u8,
    data: std.json.Value,
    created_at: i64,
};

pub const BillingEventRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    api_key_id: ?[16]u8,
    event_type: []const u8,
    amount_cents: i64,
    description: ?[]const u8,
    metadata: ?std.json.Value,
    created_at: i64,
};

pub const WebhookRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    url: []const u8,
    events: [][]const u8,
    secret: []const u8,
    status: []const u8,
    metadata: ?std.json.Value,
    created_at: i64,
    updated_at: i64,
};

pub const ResearchTaskRow = struct {
    id: [16]u8,
    team_id: [16]u8,
    model: []const u8,
    instructions: []const u8,
    output_schema: ?std.json.Value,
    status: []const u8,
    output: ?std.json.Value,
    error_message: ?[]const u8,
    created_at: i64,
    started_at: ?i64,
    finished_at: ?i64,
    cost_dollars: ?std.json.Value,
};
