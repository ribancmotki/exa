const std = @import("std");

pub const WebsetStatus = enum { running, idle, paused };
pub const WebsetSearchStatus = enum { created, running, completed, canceled };
pub const WebsetEnrichmentStatus = enum { pending, completed, canceled };
pub const WebsetEnrichmentFormat = enum { text, number, date, url, email, phone, options };

pub const EntityType = enum {
    company,
    person,
    article,
    research_paper,
    custom,
};

pub const Criterion = struct {
    description: []const u8,
    pass_if: ?[]const u8 = null,
    fail_if: ?[]const u8 = null,
    required: bool = false,
};

pub const CreateWebsetSearchRequest = struct {
    query: []const u8,
    entity_type: EntityType = .company,
    entity_description: ?[]const u8 = null,
    criteria: []const Criterion = &.{},
    count: usize = 10,
    max_people_per_company: ?usize = null,
    behaviour: []const u8 = "override",
};

pub const CreateEnrichmentRequest = struct {
    title: ?[]const u8 = null,
    description: []const u8,
    format: []const u8 = "text",
    options: ?std.json.Value = null,
    instructions: ?[]const u8 = null,
};

pub const CreateWebsetRequest = struct {
    external_id: ?[]const u8 = null,
    search: ?CreateWebsetSearchRequest = null,
    enrichments: ?[]const CreateEnrichmentRequest = null,
    metadata: ?std.json.Value = null,
};

pub const CreateImportRequest = struct {
    webset_id: ?[]const u8 = null,
    urls: []const []const u8,
};

pub const CompanyProperties = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    description: ?[]const u8 = null,
    logo_url: ?[]const u8 = null,
    location: ?[]const u8 = null,
    industry: ?[]const u8 = null,
    employee_count: ?[]const u8 = null,
    founded_year: ?[]const u8 = null,
};

pub const PersonProperties = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    picture_url: ?[]const u8 = null,
    location: ?[]const u8 = null,
    current_title: ?[]const u8 = null,
    current_company: ?[]const u8 = null,
};

pub const ArticleProperties = struct {
    title: ?[]const u8 = null,
    url: ?[]const u8 = null,
    author: ?[]const u8 = null,
    published_date: ?[]const u8 = null,
    source: ?[]const u8 = null,
};

pub const ResearchPaperProperties = struct {
    title: ?[]const u8 = null,
    url: ?[]const u8 = null,
    authors: ?[]const []const u8 = null,
    published_date: ?[]const u8 = null,
    venue: ?[]const u8 = null,
};

pub const CustomProperties = struct {
    url: ?[]const u8 = null,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    data: std.json.Value = .null,
};

pub const EnrichmentResult = struct {
    enrichment_id: []const u8,
    enrichment_title: ?[]const u8,
    value: std.json.Value,
    created_at: i64,
};

pub const EvaluationResult = struct {
    criterion: []const u8,
    result: []const u8,
    reasoning: ?[]const u8,
    citations: ?[]const []const u8,
};

pub const WebsetDto = struct {
    id: []const u8,
    external_id: ?[]const u8,
    status: WebsetStatus,
    metadata: ?std.json.Value,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const WebsetSearchDto = struct {
    id: []const u8,
    webset_id: []const u8,
    status: WebsetSearchStatus,
    query: []const u8,
    entity_type: ?EntityType,
    entity_description: ?[]const u8,
    criteria: []const Criterion,
    count: usize,
    max_people_per_company: ?usize,
    behaviour: []const u8,
    progress_found: usize,
    progress_completion: f32,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const WebsetItemDto = struct {
    id: []const u8,
    webset_id: []const u8,
    source: []const u8,
    source_id: ?[]const u8,
    properties: std.json.Value,
    evaluations: []const EvaluationResult,
    enrichments: []const EnrichmentResult,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const WebsetEnrichmentDto = struct {
    id: []const u8,
    webset_id: []const u8,
    status: WebsetEnrichmentStatus,
    title: ?[]const u8,
    description: []const u8,
    format: []const u8,
    options: ?std.json.Value,
    instructions: ?[]const u8,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const WebsetExportDto = struct {
    id: []const u8,
    webset_id: []const u8,
    format: []const u8,
    status: []const u8,
    download_url: ?[]const u8,
    created_at: []const u8,
    completed_at: ?[]const u8,
};

pub const WebsetImportDto = struct {
    id: []const u8,
    webset_id: ?[]const u8,
    team_id: []const u8,
    status: []const u8,
    total_urls: ?usize,
    processed_urls: usize,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const ListWebsetsResponse = struct {
    data: []const WebsetDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const ListItemsResponse = struct {
    data: []const WebsetItemDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const Progress = struct {
    found: usize,
    completion: f32,
};
