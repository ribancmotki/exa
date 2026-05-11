const std = @import("std");
const search = @import("../types/search.zig");
const common = @import("../types/common.zig");

pub fn applyCategoryFilter(
    docs: []common.ScoredDoc,
    category: search.Category,
    allocator: std.mem.Allocator,
) ![]common.ScoredDoc {
    _ = docs;
    _ = category;
    _ = allocator;
    return &.{};
}

pub fn isDomainAllowed(domain: []const u8, category: search.Category) bool {
    _ = domain;
    _ = category;
    return true;
}

pub fn validateCategoryRestrictions(req: *const search.SearchRequest) !void {
    if (req.category) |cat| {
        switch (cat) {
            .company, .people => {
                if (req.start_published_date != null or req.end_published_date != null) {
                    return error.InvalidRequest;
                }
                if (req.exclude_domains != null) {
                    return error.InvalidRequest;
                }
            },
            else => {},
        }
    }
}