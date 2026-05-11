const std = @import("std");
const http_client = @import("../utils/http_client.zig");

const ANTHROPIC_API_URL = "https://api.anthropic.com";

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
        try w.print("{{\"model\":\"{s}\",\"max_tokens\":{d},\"messages\":[{{\"role\":\"user\",\"content\":", .{ self.model, mt });
        try std.json.stringify(user, .{}, w);
        try w.print("}}]", .{});
        if (system) |sys| {
            try w.print(",\"system\":", .{});
            try std.json.stringify(sys, .{}, w);
        }
        try w.print("}}", .{});

        const client = http_client.HttpClient{ .base_url = ANTHROPIC_API_URL, .timeout_ms = 120000 };
        _ = client;

        const no_headers: []const struct { name: []const u8, value: []const u8 } = &.{};
        _ = no_headers;

        var full_url = try std.fmt.allocPrint(allocator, "{s}/v1/messages", .{ANTHROPIC_API_URL});
        defer allocator.free(full_url);

        const auth_header = try std.fmt.allocPrint(allocator, "x-api-key: {s}", .{self.api_key});
        defer allocator.free(auth_header);

        const c = http_client.HttpClient{ .base_url = "", .timeout_ms = 120000 };
        var resp = c.request("POST", full_url, body_buf.items, allocator) catch |err| {
            std.log.warn("LLM API call failed: {}", .{err});
            return try allocator.dupe(u8, "");
        };
        defer allocator.free(resp.body);

        if (resp.status != 200) {
            std.log.warn("LLM API returned status {d}: {s}", .{ resp.status, resp.body });
            return try allocator.dupe(u8, "");
        }

        return extractTextFromAnthropicResponse(resp.body, allocator);
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

fn extractTextFromAnthropicResponse(body: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{ .allocate = .alloc_always }) catch {
        return allocator.dupe(u8, "");
    };
    defer parsed.deinit();

    if (parsed.value != .object) return allocator.dupe(u8, "");
    const obj = parsed.value.object;

    const content = obj.get("content") orelse return allocator.dupe(u8, "");
    if (content != .array) return allocator.dupe(u8, "");

    var result = std.ArrayList(u8).init(allocator);
    for (content.array.items) |item| {
        if (item != .object) continue;
        const type_val = item.object.get("type") orelse continue;
        if (type_val != .string) continue;
        if (!std.mem.eql(u8, type_val.string, "text")) continue;
        const text_val = item.object.get("text") orelse continue;
        if (text_val != .string) continue;
        try result.appendSlice(text_val.string);
    }
    return result.toOwnedSlice();
}
