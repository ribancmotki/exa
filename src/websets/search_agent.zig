const std = @import("std");
const common = @import("../types/common.zig");
const webset = @import("../types/webset.zig");
const db_queries = @import("../db/queries.zig");
const search = @import("../search/engine.zig");

pub fn run(app_state: *anyopaque) void {
    _ = app_state;
    
    while (true) {
        std.time.sleep(std.time.ns_per_s * 5);
    }
}

pub fn processSearch(
    search_id: [16]u8,
    app_state: *anyopaque,
    allocator: std.mem.Allocator,
) !void {
    _ = search_id;
    _ = app_state;
    _ = allocator;
}