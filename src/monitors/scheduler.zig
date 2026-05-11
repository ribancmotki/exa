const std = @import("std");
const app_state = @import("../app_state.zig");
const queries = @import("../db/queries.zig");
const runner = @import("./runner.zig");
const time = @import("../utils/time.zig");

pub fn parsePeriod(period: []const u8) !u64 {
    if (period.len < 2) return error.InvalidRequest;
    const value_str = period[0 .. period.len - 1];
    const unit = period[period.len - 1];
    const value = try std.fmt.parseInt(u64, value_str, 10);
    return switch (unit) {
        's' => value,
        'm' => value * 60,
        'h' => value * 3600,
        'd' => value * 86400,
        'w' => value * 604800,
        else => error.InvalidRequest,
    };
}

pub fn computeNextRun(period_seconds: u64) i64 {
    return time.nowSeconds() + @as(i64, @intCast(period_seconds));
}

pub const Scheduler = struct {
    pub fn run(state: *app_state.AppState) void {
        std.log.info("Monitor scheduler started", .{});
        while (true) {
            std.time.sleep(std.time.ns_per_s * 60);
            runDueMonitors(state) catch |err| {
                std.log.warn("Monitor scheduler error: {}", .{err});
            };
        }
    }

    fn runDueMonitors(state: *app_state.AppState) !void {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const now = time.nowSeconds() * 1000;
        const due = try queries.listDueMonitors(state.pg_pool, now, allocator);
        for (due) |monitor_row| {
            const thread = std.Thread.spawn(.{}, runner.runMonitor, .{ state, monitor_row, allocator }) catch |err| {
                std.log.warn("Failed to spawn monitor run thread: {}", .{err});
                continue;
            };
            thread.detach();
        }
    }
};

test "period parsing" {
    try std.testing.expectEqual(@as(u64, 3600), try parsePeriod("1h"));
    try std.testing.expectEqual(@as(u64, 604800), try parsePeriod("7d"));
    try std.testing.expectEqual(@as(u64, 1800), try parsePeriod("30m"));
}
