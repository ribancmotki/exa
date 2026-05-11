const std = @import("std");
const search = @import("../types/search.zig");
const config = @import("../config.zig");

pub const Pricing = struct {
    config: *const config.Config,

    pub fn searchCost(self: *const Pricing, search_type: search.SearchType, num_results: usize) i64 {
        const base: i64 = switch (search_type) {
            .auto, .fast, .instant, .neural, .keyword => @as(i64, @intCast(self.config.credit_search_auto_cents)),
            .@"deep-lite" => @as(i64, @intCast(self.config.credit_search_deep_lite_cents)),
            .deep => @as(i64, @intCast(self.config.credit_search_deep_cents)),
            .@"deep-reasoning" => @as(i64, @intCast(self.config.credit_search_deep_reasoning_cents)),
        };
        
        const extra_results = if (num_results > 10) @as(i64, num_results - 10) else 0;
        return base + extra_results * @as(i64, @intCast(self.config.credit_contents_per_page_cents / 10));
    }

    pub fn contentsCost(
        self: *const Pricing,
        num_pages: usize,
        has_text: bool,
        has_highlights: bool,
        has_summary: bool,
    ) i64 {
        var per_page: i64 = 0;
        if (has_text) per_page += @as(i64, @intCast(self.config.credit_contents_per_page_cents));
        if (has_highlights) per_page += @as(i64, @intCast(self.config.credit_contents_per_page_cents));
        if (has_summary) per_page += @as(i64, @intCast(self.config.credit_summary_per_page_cents));
        return per_page * @as(i64, @intCast(num_pages));
    }

    pub fn answerCost(self: *const Pricing) i64 {
        return @as(i64, @intCast(self.config.credit_answer_cents));
    }
};

test "pricing search cost" {
    const cfg = try config.Config.load(std.testing.allocator);
    defer _ = &cfg;
    
    const pricing = Pricing{ .config = &cfg };
    
    const auto_cost = pricing.searchCost(.auto, 10);
    try std.testing.expect(auto_cost > 0);
}