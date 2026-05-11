const std = @import("std");
const common = @import("common.zig");
const search = @import("search.zig");

pub const ContentsRequest = struct {
    urls: []const []const u8,
    text: ?TextContentsInput = null,
    highlights: ?HighlightsContentsInput = null,
    summary: ?SummaryContentsInput = null,
    max_age_hours: ?i64 = null,
    livecrawl_timeout: u64 = 10000,
    subpages: usize = 0,
    subpage_target: ?[]const []const u8 = null,
    extras: ExtrasInput = .{},
};

pub const TextContentsInput = struct {
    max_characters: ?usize = null,
    include_html_tags: bool = false,
    verbosity: []const u8 = "compact",
};

pub const HighlightsContentsInput = struct {
    query: ?[]const u8 = null,
    num_highlights: ?usize = null,
};

pub const SummaryContentsInput = struct {
    query: ?[]const u8 = null,
    schema: ?std.json.Value = null,
};

pub const ExtrasInput = struct {
    links: usize = 0,
    image_links: usize = 0,
};

pub const ContentsResponse = struct {
    results: []const search.SearchResult,
    statuses: []const search.ContentStatus,
    cost_dollars: common.CostDollars,
};

pub const ContentResolveResult = struct {
    result: ?search.SearchResult,
    status: search.ContentStatus,
    from_cache: bool,
    cost_cents: i64,
};
