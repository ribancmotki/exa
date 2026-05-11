const std = @import("std");

const EVP_MD = opaque {};

extern fn EVP_sha256() *const EVP_MD;
extern fn EVP_DigestInit_ex(ctx: ?*anyopaque, type_: *const EVP_MD, impl: ?*anyopaque) c_int;
extern fn EVP_Digest(data: [*]const u8, count: usize, md: [*]u8, size: ?*c_uint, type_: *const EVP_MD, impl: ?*anyopaque) c_int;
extern fn HMAC(evp_md: *const EVP_MD, key: [*]const u8, key_len: c_int, d: [*]const u8, n: usize, md: [*]u8, md_len: ?*c_uint) ?[*]u8;
extern fn RAND_bytes(buf: [*]u8, num: c_int) c_int;
extern fn CRYPTO_memcmp(a: [*]const u8, b: [*]const u8, len: usize) c_int;

pub fn sha256(data: []const u8, out: *[32]u8) void {
    var len: c_uint = 32;
    _ = EVP_Digest(data.ptr, data.len, out, &len, EVP_sha256(), null);
}

pub fn hmacSha256(key: []const u8, data: []const u8, out: *[32]u8) void {
    var len: c_uint = 32;
    _ = HMAC(EVP_sha256(), key.ptr, @intCast(key.len), data.ptr, data.len, out, &len);
}

pub fn hexEncode(bytes: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const hex = "0123456789abcdef";
    var result = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        result[i * 2] = hex[byte >> 4];
        result[i * 2 + 1] = hex[byte & 0x0F];
    }
    return result;
}

pub fn hexDecode(hex: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;
    var result = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(result);
    for (0..hex.len / 2) |i| {
        const hi = try hexNibble(hex[i * 2]);
        const lo = try hexNibble(hex[i * 2 + 1]);
        result[i] = (hi << 4) | lo;
    }
    return result;
}

fn hexNibble(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHexCharacter,
    };
}

pub fn randomBytes(buf: []u8) void {
    _ = RAND_bytes(buf.ptr, @intCast(buf.len));
}

pub fn randomHex(len: usize, allocator: std.mem.Allocator) ![]const u8 {
    const raw = try allocator.alloc(u8, len);
    defer allocator.free(raw);
    randomBytes(raw);
    return hexEncode(raw, allocator);
}

pub const GeneratedApiKey = struct {
    raw: []const u8,
    hash: [32]u8,
    prefix: [8]u8,
};

pub fn generateApiKey(allocator: std.mem.Allocator) !GeneratedApiKey {
    var raw_bytes: [32]u8 = undefined;
    randomBytes(&raw_bytes);
    const raw = try hexEncode(&raw_bytes, allocator);
    var hash: [32]u8 = undefined;
    sha256(raw, &hash);
    var prefix: [8]u8 = undefined;
    @memcpy(&prefix, raw[0..8]);
    return GeneratedApiKey{ .raw = raw, .hash = hash, .prefix = prefix };
}

pub fn generateWebhookSecret(allocator: std.mem.Allocator) ![]const u8 {
    return randomHex(32, allocator);
}

pub fn computeWebhookSignature(secret: []const u8, timestamp: i64, payload: []const u8, out: *[32]u8) void {
    var msg_buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "{d}.{s}", .{ timestamp, payload }) catch {
        @memset(out, 0);
        return;
    };
    hmacSha256(secret, msg, out);
}

pub fn timingSafeEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    return CRYPTO_memcmp(a.ptr, b.ptr, a.len) == 0;
}

test "sha256 known value" {
    var hash: [32]u8 = undefined;
    sha256("", &hash);
    const allocator = std.testing.allocator;
    const hex = try hexEncode(&hash, allocator);
    defer allocator.free(hex);
    try std.testing.expectEqualStrings("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hex);
}
