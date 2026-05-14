const std = @import("std");

test "uuid generate and parse" {
    const uuid = @import("../src/utils/uuid.zig");
    const u = uuid.generate();
    const str = try uuid.toString(u, std.testing.allocator);
    defer std.testing.allocator.free(str);
    try std.testing.expectEqual(@as(usize, 36), str.len);
    try std.testing.expect(str[8] == '-');
    try std.testing.expect(str[13] == '-');
    try std.testing.expect(str[18] == '-');
    try std.testing.expect(str[23] == '-');
    const parsed = try uuid.parse(str);
    try std.testing.expectEqualSlices(u8, &u, &parsed);
}

test "uuid zero" {
    const uuid = @import("../src/utils/uuid.zig");
    const z = uuid.zero();
    for (z) |b| try std.testing.expectEqual(@as(u8, 0), b);
}
