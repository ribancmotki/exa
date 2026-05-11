const std = @import("std");
const common = @import("../types/common.zig");

pub fn generateSubpages(
    parent_url: []const u8,
    links: [][]const u8,
    targets: ?[][]const u8,
    limit: usize,
) ![]SearchResultSubpage {
    _ = parent_url;
    _ = links;
    _ = targets;
    _ = limit;
    return &.{};
}

pub const SearchResultSubpage = struct {
    url: []const u8,
    title: ?[]const u8,
    score: f32,
};

const SearchResult = struct {
    title: ?[]const u8,
    url: []const u8,
};