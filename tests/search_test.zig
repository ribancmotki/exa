const std = @import("std");

test "search type enum" {
    const search = @import("../src/types/search.zig");
    try std.testing.expect(search.SearchType.auto == .auto);
    try std.testing.expect(search.SearchType.neural == .neural);
}

test "search request defaults" {
    const search = @import("../src/types/search.zig");
    const req = search.SearchRequest{ .query = "test" };
    try std.testing.expectEqualStrings("test", req.query);
    try std.testing.expect(req.num_results == 10);
    try std.testing.expect(req.type == .auto);
}
