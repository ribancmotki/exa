const std = @import("std");
const http_client = @import("../utils/http_client.zig");

const CEREBRAS_API_URL = "https://api.cerebras.ai";

pub const LlmClient = struct {
    api_key: []const u8,
    model: []const u8,
    max_tokens: u32,

    pub fn complete(
        self: *const LlmClient,
        system: ?[]const u8,
        user: []const u8,
        max_tokens: u32,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        if (self.api_key.len == 0) return try allocator.dupe(u8, "");

        const mt = if (max_tokens > 0) max_tokens else self.max_tokens;
        var body_buf = std.ArrayList(u8).init(allocator);
        defer body_buf.deinit();
        const w = body_buf.writer();

        try w.print("{{\"model\":\"{s}\",\"stream\":false,\"max_tokens\":{d},\"temperature\":0,\"top_p\":1,\"reasoning_effort\":\"low\",\"messages\":[", .{ self.model, mt });

        var first = true;
        if (system) |sys| {
            try w.print("{{\"role\":\"system\",\"content\":", .{});
            try std.json.stringify(sys, .{}, w);
            try w.print("}}", .{});
            first = false;
        }

        if (!first) try w.print(",", .{});
        try w.print("{{\"role\":\"user\",\"content\":", .{});
        try std.json.stringify(user, .{}, w);
        try w.print("}}]}}", .{});

        const full_url = try std.fmt.allocPrint(allocator, "{s}/v1/chat/completions", .{CEREBRAS_API_URL});
        defer allocator.free(full_url);

        const auth_value = try std.fmt.allocPrint(allocator, "Bearer {s}", .{self.api_key});
        defer allocator.free(auth_value);

        const c = http_client.HttpClient{ .base_url = "", .timeout_ms = 120000 };
        const headers = [_]struct { name: []const u8, value: []const u8 }{
            .{ .name = "Authorization", .value = auth_value },
        };
        const resp = c.requestWithHeaders("POST", full_url, body_buf.items, &headers, allocator) catch |err| {
            std.log.warn("LLM API call failed: {}", .{err});
            return try allocator.dupe(u8, "");
        };
        defer allocator.free(resp.body);

        if (resp.status != 200) {
            std.log.warn("LLM API returned status {d}: {s}", .{ resp.status, resp.body });
            return try allocator.dupe(u8, "");
        }

        return extractTextFromCerebrasResponse(resp.body, allocator);
    }

    pub fn completeJson(
        self: *const LlmClient,
        system: ?[]const u8,
        user: []const u8,
        schema: std.json.Value,
        max_tokens: u32,
        allocator: std.mem.Allocator,
    ) !std.json.Value {
        var schema_buf = std.ArrayList(u8).init(allocator);
        defer schema_buf.deinit();
        try std.json.stringify(schema, .{}, schema_buf.writer());

        const full_prompt = try std.fmt.allocPrint(allocator,
            "{s}\n\nRespond with valid JSON matching this schema: {s}",
            .{ user, schema_buf.items },
        );
        defer allocator.free(full_prompt);

        const text = try self.complete(system, full_prompt, max_tokens, allocator);
        defer allocator.free(text);

        if (text.len == 0) return .{ .null = {} };

        const json_start = std.mem.indexOfAny(u8, text, "{[") orelse return .{ .null = {} };
        const json_end = std.mem.lastIndexOfAny(u8, text, "}]") orelse return .{ .null = {} };
        if (json_end <= json_start) return .{ .null = {} };

        const json_text = text[json_start .. json_end + 1];
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_text, .{ .allocate = .alloc_always }) catch return .{ .null = {} };
        return parsed.value;
    }
};

fn extractTextFromCerebrasResponse(body: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{ .allocate = .alloc_always }) catch {
        return allocator.dupe(u8, "");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return allocator.dupe(u8, "");
    const obj = parsed.value.object;

    const choices = obj.get("choices") orelse return allocator.dupe(u8, "");
    if (choices != .array or choices.array.items.len == 0) return allocator.dupe(u8, "");

    const first = choices.array.items[0];
    if (first != .object) return allocator.dupe(u8, "");

    const message = first.object.get("message") orelse return allocator.dupe(u8, "");
    if (message != .object) return allocator.dupe(u8, "");

    const content = message.object.get("content") orelse return allocator.dupe(u8, "");
    if (content != .string) return allocator.dupe(u8, "");

    return allocator.dupe(u8, content.string);
}
