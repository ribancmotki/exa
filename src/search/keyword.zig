const std = @import("std");
const common = @import("../types/common.zig");
const search = @import("../types/search.zig");
const db_queries = @import("../db/queries.zig");

pub fn keywordSearch(
    db_pool: *anyopaque,
    req: search.SearchRequest,
    allocator: std.mem.Allocator,
) ![]common.ScoredDoc {
    _ = db_pool;
    _ = req;
    _ = allocator;
    return &.{};
}