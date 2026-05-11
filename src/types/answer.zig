const std = @import("std");
const common = @import("common.zig");

pub const AnswerRequest = struct {
    query: []const u8,
    stream: bool = false,
    text: bool = false,
    system_prompt: ?[]const u8 = null,
    model: ?[]const u8 = null,
    output_schema: ?std.json.Value = null,
    user_location: ?[]const u8 = null,
};

pub const AnswerCitation = struct {
    id: []const u8,
    url: []const u8,
    title: ?[]const u8,
    published_date: ?[]const u8,
    author: ?[]const u8,
    text: ?[]const u8,
};

pub const AnswerResponse = struct {
    answer: std.json.Value,
    citations: []const AnswerCitation,
    cost_dollars: common.CostDollars,
};

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatCompletionRequest = struct {
    model: []const u8,
    messages: []const ChatMessage,
    stream: bool = false,
    temperature: ?f32 = null,
    max_tokens: ?u32 = null,
};

pub const ChatCompletionDelta = struct {
    role: ?[]const u8 = null,
    content: ?[]const u8 = null,
};

pub const ChatCompletionChunkChoice = struct {
    index: u32,
    delta: ChatCompletionDelta,
    finish_reason: ?[]const u8,
};

pub const ChatCompletionChunk = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []const ChatCompletionChunkChoice,
};

pub const ChatMessage2 = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatCompletionChoiceFull = struct {
    index: u32,
    message: ChatMessage2,
    finish_reason: ?[]const u8,
};

pub const TokenUsage = struct {
    prompt_tokens: u32,
    completion_tokens: u32,
    total_tokens: u32,
};

pub const ChatCompletionResponse = struct {
    id: []const u8,
    object: []const u8,
    created: i64,
    model: []const u8,
    choices: []const ChatCompletionChoiceFull,
    usage: TokenUsage,
};

pub const OutputContent = struct {
    type: []const u8,
    text: []const u8,
};

pub const OutputItem = struct {
    type: []const u8,
    id: []const u8,
    status: []const u8,
    role: []const u8,
    content: []const OutputContent,
};

pub const ResponsesResponse = struct {
    id: []const u8,
    object: []const u8,
    created_at: i64,
    model: []const u8,
    output: []const OutputItem,
    output_text: []const u8,
};
