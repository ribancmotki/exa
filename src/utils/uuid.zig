const std = @import("std");

pub const Uuid = [16]u8;

extern fn RAND_bytes(buf: [*]u8, num: c_int) c_int;

pub fn generate() Uuid {
    var uuid: Uuid = undefined;
    _ = RAND_bytes(&uuid, 16);
    uuid[6] = (uuid[6] & 0x0F) | 0x40;
    uuid[8] = (uuid[8] & 0x3F) | 0x80;
    return uuid;
}

pub fn toString(uuid: Uuid, allocator: std.mem.Allocator) ![]const u8 {
    const hex = "0123456789abcdef";
    var result = try allocator.alloc(u8, 36);
    const b = uuid;
    var i: usize = 0;
    var j: usize = 0;
    const groups = [_]usize{ 4, 2, 2, 2, 6 };
    for (groups, 0..) |g, gi| {
        if (gi > 0) {
            result[j] = '-';
            j += 1;
        }
        var k: usize = 0;
        while (k < g) : (k += 1) {
            result[j] = hex[b[i] >> 4];
            result[j + 1] = hex[b[i] & 0x0F];
            j += 2;
            i += 1;
        }
    }
    return result;
}

pub fn parse(str: []const u8) !Uuid {
    if (str.len != 36) return error.InvalidUuidLength;
    if (str[8] != '-' or str[13] != '-' or str[18] != '-' or str[23] != '-')
        return error.InvalidUuidFormat;
    var uuid: Uuid = undefined;
    var idx: usize = 0;
    var si: usize = 0;
    while (si < 36) {
        if (str[si] == '-') {
            si += 1;
            continue;
        }
        if (si + 1 >= 36) return error.InvalidUuidFormat;
        const hi = try hexNibble(str[si]);
        const lo = try hexNibble(str[si + 1]);
        uuid[idx] = (hi << 4) | lo;
        idx += 1;
        si += 2;
    }
    if (idx != 16) return error.InvalidUuidFormat;
    return uuid;
}

pub fn fromPgBytes(bytes: []const u8) Uuid {
    var uuid: Uuid = undefined;
    @memcpy(&uuid, bytes[0..16]);
    return uuid;
}

pub fn toPgBytes(uuid: Uuid) [16]u8 {
    return uuid;
}

pub fn eql(a: Uuid, b: Uuid) bool {
    return std.mem.eql(u8, &a, &b);
}

pub fn zero() Uuid {
    return std.mem.zeroes(Uuid);
}

fn hexNibble(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHexCharacter,
    };
}

test "uuid generate and roundtrip" {
    const uuid = generate();
    const allocator = std.testing.allocator;
    const str = try toString(uuid, allocator);
    defer allocator.free(str);
    try std.testing.expectEqual(@as(usize, 36), str.len);
    const parsed = try parse(str);
    try std.testing.expectEqualSlices(u8, &uuid, &parsed);
}
