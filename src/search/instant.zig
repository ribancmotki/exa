const std = @import("std");
const common = @import("../types/common.zig");
const search = @import("../types/search.zig");

pub fn instantSearch(
    req: search.SearchRequest,
    allocator: std.mem.Allocator,
) ![]common.ScoredDoc {
    _ = req;
    _ = allocator;
    return &.{};
}