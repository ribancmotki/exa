const std = @import("std");

test "period parsing" {
    const scheduler = @import("../src/monitors/scheduler.zig");
    try std.testing.expectEqual(@as(u64, 3600), try scheduler.parsePeriod("1h"));
    try std.testing.expectEqual(@as(u64, 86400), try scheduler.parsePeriod("1d"));
    try std.testing.expectEqual(@as(u64, 60), try scheduler.parsePeriod("1m"));
    try std.testing.expectEqual(@as(u64, 604800), try scheduler.parsePeriod("7d"));
    try std.testing.expectEqual(@as(u64, 1800), try scheduler.parsePeriod("30m"));
}

test "period parsing invalid" {
    const scheduler = @import("../src/monitors/scheduler.zig");
    try std.testing.expectError(error.InvalidRequest, scheduler.parsePeriod("x"));
    try std.testing.expectError(error.InvalidRequest, scheduler.parsePeriod(""));
}
