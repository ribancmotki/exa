const std = @import("std");
const webset = @import("../types/webset.zig");
const db_queries = @import("../db/queries.zig");

pub fn createImport(
    db_pool: *anyopaque,
    req: webset.CreateImportRequest,
    team_id: [16]u8,
    allocator: std.mem.Allocator,
) !webset.WebsetImportDto {
    _ = db_pool;
    _ = req;
    _ = team_id;
    _ = allocator;
    
    return webset.WebsetImportDto{
        .id = "",
        .webset_id = null,
        .team_id = "",
        .status = "pending",
        .total_urls = null,
        .processed_urls = 0,
        .created_at = "",
        .updated_at = "",
    };
}

pub fn processImport(
    import_id: [16]u8,
    db_pool: *anyopaque,
    allocator: std.mem.Allocator,
) !void {
    _ = import_id;
    _ = db_pool;
    _ = allocator;
}