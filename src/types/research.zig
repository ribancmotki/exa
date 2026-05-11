const std = @import("std");
const common = @import("common.zig");

pub const ResearchModel = enum {
    @"exa-research-fast",
    @"exa-research",
    @"exa-research-pro",
};

pub const ResearchStatus = enum {
    pending,
    running,
    completed,
    canceled,
    failed,
};

pub const ResearchCreateRequest = struct {
    instructions: []const u8,
    model: ResearchModel = .@"exa-research",
    output_schema: ?std.json.Value = null,
};

pub const ResearchOutput = struct {
    content: []const u8,
    parsed: ?std.json.Value,
};

pub const ResearchDto = struct {
    id: []const u8,
    created_at: i64,
    model: ResearchModel,
    instructions: []const u8,
    output_schema: ?std.json.Value,
    status: ResearchStatus,
    finished_at: ?i64,
    output: ?ResearchOutput,
    cost_dollars: ?common.CostDollars,
    error_message: ?[]const u8,
};

pub const ListResearchResponse = struct {
    data: []const ResearchDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};
