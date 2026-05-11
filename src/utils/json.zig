const std = @import("std");

pub fn parseRequest(comptime T: type, body: []const u8, allocator: std.mem.Allocator) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}

pub fn writeResponse(writer: anytype, value: anytype) !void {
    try std.json.stringify(value, .{ .emit_null_optional_fields = false }, writer);
}

pub fn toJson(value: anytype, allocator: std.mem.Allocator) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    errdefer buf.deinit();
    try std.json.stringify(value, .{ .emit_null_optional_fields = false }, buf.writer());
    return buf.toOwnedSlice();
}

pub fn camelToSnake(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    for (name, 0..) |c, i| {
        if (c >= 'A' and c <= 'Z') {
            if (i > 0) try result.append('_');
            try result.append(c + 32);
        } else {
            try result.append(c);
        }
    }
    return result.toOwnedSlice();
}

pub fn snakeToCamel(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    var capitalize_next = false;
    for (name) |c| {
        if (c == '_') {
            capitalize_next = true;
        } else if (capitalize_next) {
            try result.append(if (c >= 'a' and c <= 'z') c - 32 else c);
            capitalize_next = false;
        } else {
            try result.append(c);
        }
    }
    return result.toOwnedSlice();
}

pub fn mergeJson(allocator: std.mem.Allocator, base: std.json.Value, patch: std.json.Value) !std.json.Value {
    if (base == .null) return patch;
    if (patch == .null) return base;
    switch (base) {
        .object => |base_obj| {
            if (patch != .object) return patch;
            const patch_obj = patch.object;
            var result = std.json.ObjectMap.init(allocator);
            errdefer result.deinit();
            var it = base_obj.iterator();
            while (it.next()) |entry| {
                const patch_val = patch_obj.get(entry.key_ptr.*) orelse .null;
                const merged = try mergeJson(allocator, entry.value_ptr.*, patch_val);
                try result.put(try allocator.dupe(u8, entry.key_ptr.*), merged);
            }
            var pit = patch_obj.iterator();
            while (pit.next()) |entry| {
                if (!result.contains(entry.key_ptr.*)) {
                    try result.put(try allocator.dupe(u8, entry.key_ptr.*), entry.value_ptr.*);
                }
            }
            return .{ .object = result };
        },
        else => return patch,
    }
}

pub fn validateJsonSchema(schema: std.json.Value) !void {
    if (schema != .object) return error.InvalidJsonSchema;
    const obj = schema.object;
    if (obj.get("type")) |type_val| {
        if (type_val != .string) return error.InvalidJsonSchema;
        const valid_types = [_][]const u8{ "object", "array", "string", "number", "integer", "boolean", "null" };
        var valid = false;
        for (valid_types) |vt| {
            if (std.mem.eql(u8, type_val.string, vt)) { valid = true; break; }
        }
        if (!valid) return error.InvalidJsonSchema;
    }
    if (obj.get("properties")) |props| {
        if (props != .object) return error.InvalidJsonSchema;
        var pit = props.object.iterator();
        var count: usize = 0;
        while (pit.next()) |_| {
            count += 1;
            if (count > 10) return error.InvalidJsonSchema;
        }
    }
    if (obj.get("required")) |req| {
        if (req != .array) return error.InvalidJsonSchema;
        for (req.array.items) |item| {
            if (item != .string) return error.InvalidJsonSchema;
        }
    }
}

pub fn jsonStringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const val = obj.get(key) orelse return null;
    return if (val == .string) val.string else null;
}

pub fn jsonIntField(obj: std.json.ObjectMap, key: []const u8) ?i64 {
    const val = obj.get(key) orelse return null;
    return switch (val) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => null,
    };
}
