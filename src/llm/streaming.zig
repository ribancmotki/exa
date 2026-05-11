const std = @import("std");

pub const SseParser = struct {
    data_buffer: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !SseParser {
        return SseParser{
            .data_buffer = &.{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SseParser) void {
        self.allocator.free(self.data_buffer);
    }

    pub fn parse(self: *SseParser, data: []const u8) ![]SseEvent {
        _ = self;
        _ = data;
        return &.{};
    }
};

pub const SseEvent = struct {
    event: ?[]const u8,
    data: []const u8,
};

pub fn openAiChunkToText(
    chunk_json: []const u8,
    allocator: std.mem.Allocator,
) !?[]const u8 {
    _ = chunk_json;
    _ = allocator;
    return null;
}

pub fn parseAnthropicChunk(
    chunk_json: []const u8,
    allocator: std.mem.Allocator,
) !?[]const u8 {
    _ = chunk_json;
    _ = allocator;
    return null;
}

pub fn formatSseEvent(event_type: []const u8, data: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "event: {s}\ndata: {s}\n\n", .{ event_type, data });
}