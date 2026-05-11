const std = @import("std");
const db_queries = @import("../db/queries.zig");
const webset = @import("../types/webset.zig");

pub fn generate(
    db_pool: *anyopaque,
    webset_id: [16]u8,
    allocator: std.mem.Allocator,
) ![]const u8 {
    _ = db_pool;
    _ = webset_id;
    _ = allocator;
    return "";
}

pub fn writeCsvRow(
    writer: anytype,
    fields: [][]const u8,
) !void {
    for (fields, 0..) |field, i| {
        if (i > 0) try writer.writeByte(',');
        
        var needs_quotes = false;
        for (field) |c| {
            if (c == '"' or c == ',' or c == '\n' or c == '\r') {
                needs_quotes = true;
                break;
            }
        }
        
        if (needs_quotes) {
            try writer.writeByte('"');
            for (field) |c| {
                if (c == '"') try writer.writeByte('"');
                try writer.writeByte(c);
            }
            try writer.writeByte('"');
        } else {
            try writer.writeAll(field);
        }
    }
    try writer.writeByte('\n');
}