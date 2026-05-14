const std = @import("std");

test "cost dollars new" {
    const common = @import("../src/types/common.zig");
    const cost = common.CostDollars.new();
    try std.testing.expectEqual(@as(f64, 0), cost.total);
    try std.testing.expect(cost.search == null);
    try std.testing.expect(cost.contents == null);
}

test "cost to dollars" {
    const common = @import("../src/types/common.zig");
    const dollars = common.CostDollars.toDollars(100);
    try std.testing.expectEqual(@as(f64, 1.0), dollars);
    const cents = common.CostDollars.toDollars(1);
    try std.testing.expectEqual(@as(f64, 0.01), cents);
}

test "time functions" {
    const time = @import("../src/utils/time.zig");
    const ms = time.nowMillis();
    const s = time.nowSeconds();
    try std.testing.expect(ms > 0);
    try std.testing.expect(s > 0);
    try std.testing.expect(ms / 1000 >= s - 1);
}
