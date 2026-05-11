const std = @import("std");
const common = @import("common.zig");

pub const SearchType = enum {
    auto,
    fast,
    instant,
    @"deep-lite",
    deep,
    @"deep-reasoning",
    neural,
    keyword,
};

pub const Category = enum {
    company,
    @"research paper",
    news,
    @"personal site",
    @"financial report",
    people,
    pdf,
    github,
};

pub const TextVerbosity = enum { compact, standard, full };
pub const SectionTag = enum { header, navigation, banner, body, sidebar, footer, metadata };

pub const TextContentsOptions = struct {
    max_characters: ?usize = null,
    include_html_tags: bool = false,
    verbosity: TextVerbosity = .compact,
};

pub const HighlightsContentsOptions = struct {
    query: ?[]const u8 = null,
    max_characters: ?usize = null,
};

pub const SummaryContentsOptions = struct {
    query: ?[]const u8 = null,
    schema: ?std.json.Value = null,
};

pub const ContextContentsOptions = struct {
    max_characters: ?usize = null,
};

pub const ExtrasOptions = struct {
    links: usize = 0,
    image_links: usize = 0,
};

pub const ContentsOptions = struct {
    text: ?bool = null,
    highlights: ?bool = null,
    summary: ?bool = null,
    max_age_hours: ?i64 = null,
    livecrawl_timeout: u64 = 10000,
    subpages: usize = 0,
    subpage_target: ?[]const []const u8 = null,
    extras: ExtrasOptions = .{},
    filter_empty_results: bool = true,
    text_options: ?TextContentsOptions = null,
    highlights_options: ?HighlightsContentsOptions = null,
    summary_options: ?SummaryContentsOptions = null,
};

pub const SearchRequest = struct {
    query: []const u8,
    type: SearchType = .auto,
    stream: bool = false,
    num_results: usize = 10,
    category: ?Category = null,
    user_location: ?[]const u8 = null,
    include_domains: ?[]const []const u8 = null,
    exclude_domains: ?[]const []const u8 = null,
    start_published_date: ?[]const u8 = null,
    end_published_date: ?[]const u8 = null,
    start_crawl_date: ?[]const u8 = null,
    end_crawl_date: ?[]const u8 = null,
    include_text: ?[]const []const u8 = null,
    exclude_text: ?[]const []const u8 = null,
    moderation: bool = false,
    additional_queries: ?[]const []const u8 = null,
    system_prompt: ?[]const u8 = null,
    output_schema: ?std.json.Value = null,
    contents: ?ContentsOptions = null,
    flags: ?[]const []const u8 = null,
};

pub const ExtrasResult = struct {
    links: ?[]const []const u8,
    image_links: ?[]const []const u8,
};

pub const SearchResult = struct {
    title: ?[]const u8,
    url: []const u8,
    id: []const u8,
    published_date: ?[]const u8,
    author: ?[]const u8,
    score: ?f32,
    image: ?[]const u8,
    favicon: ?[]const u8,
    text: ?[]const u8,
    highlights: ?[]const []const u8,
    highlight_scores: ?[]const f32,
    summary: ?[]const u8,
    subpages: ?[]const SearchResult,
    extras: ?ExtrasResult,
};

pub const DeepSearchOutputGroundingCitation = struct {
    url: []const u8,
    title: []const u8,
};

pub const DeepSearchOutputGrounding = struct {
    field: []const u8,
    citations: []const DeepSearchOutputGroundingCitation,
    confidence: []const u8,
};

pub const DeepSearchOutput = struct {
    content: std.json.Value,
    grounding: []const DeepSearchOutputGrounding,
};

pub const SearchResponse = struct {
    request_id: []const u8,
    search_type: ?[]const u8,
    results: []const SearchResult,
    output: ?DeepSearchOutput,
    auto_date: ?[]const u8,
    context: ?[]const u8,
    statuses: ?[]const ContentStatus,
    cost_dollars: common.CostDollars,
    search_time: ?f64,
};

pub const ContentErrorTag = enum {
    CRAWL_NOT_FOUND,
    CRAWL_TIMEOUT,
    CRAWL_LIVECRAWL_TIMEOUT,
    SOURCE_NOT_AVAILABLE,
    UNSUPPORTED_URL,
    CRAWL_UNKNOWN_ERROR,
};

pub const ContentError = struct {
    tag: ContentErrorTag,
    http_status_code: ?u16,
};

pub const ContentStatus = struct {
    id: []const u8,
    status: []const u8,
    @"error": ?ContentError,
};
