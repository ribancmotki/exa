const std = @import("std");
const http_client = @import("../utils/http_client.zig");
const streaming = @import("./streaming.zig");

pub fn complete(
    api_key: []const u8,
    model: []const u8,
    system: ?[]const u8,
    messages: []const Message,
    max_tokens: u32,
    stream: bool,
    allocator: std.mem.Allocator,
) !CompletionResult {
    _ = api_key;
    _ = model;
    _ = system;
    _ = messages;
    _ = max_tokens;
    _ = stream;
    _ = allocator;
    
    return CompletionResult{
        .content = "",
        .stop_reason = "end_turn",
    };
}

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const CompletionResult = struct {
    content: []const u8,
    stop_reason: []const u8,
};

pub const StreamChunk = struct {
    delta: []const u8,
    done: bool,
};

pub fn parseStreamResponse(
    data: []const u8,
    allocator: std.mem.Allocator,
) !?StreamChunk {
    _ = data;
    _ = allocator;
    return StreamChunk{
        .delta = "",
        .done = false,
    };
}