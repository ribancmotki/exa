const std = @import("std");

pub fn nowMillis() i64 {
    return @intCast(@divFloor(std.time.nanoTimestamp(), std.time.ns_per_ms));
}

pub fn nowSeconds() i64 {
    return std.time.timestamp();
}

pub fn parseIso8601(str: []const u8) !i64 {
    if (str.len < 10) return error.InvalidDateFormat;
    const year = try std.fmt.parseInt(i32, str[0..4], 10);
    const month = try std.fmt.parseInt(u32, str[5..7], 10);
    const day = try std.fmt.parseInt(u32, str[8..10], 10);
    var hour: u32 = 0;
    var minute: u32 = 0;
    var second: u32 = 0;
    var offset_minutes: i32 = 0;
    if (str.len > 11) {
        if (str.len >= 13) hour = try std.fmt.parseInt(u32, str[11..13], 10);
        if (str.len >= 16) minute = try std.fmt.parseInt(u32, str[14..16], 10);
        if (str.len >= 19) second = try std.fmt.parseInt(u32, str[17..19], 10);
        var pos: usize = 19;
        if (pos < str.len and str[pos] == '.') {
            while (pos < str.len and str[pos] != '+' and str[pos] != '-' and str[pos] != 'Z') pos += 1;
        }
        if (pos < str.len and str[pos] == 'Z') {
        } else if (pos < str.len and (str[pos] == '+' or str[pos] == '-')) {
            const sign: i32 = if (str[pos] == '+') 1 else -1;
            pos += 1;
            if (pos + 4 <= str.len) {
                const oh = try std.fmt.parseInt(u32, str[pos..pos + 2], 10);
                const om = try std.fmt.parseInt(u32, str[pos + 3..pos + 5], 10);
                offset_minutes = sign * @as(i32, @intCast(oh * 60 + om));
            }
        }
    }
    if (month < 1 or month > 12) return error.InvalidDateFormat;
    if (day < 1 or day > 31) return error.InvalidDateFormat;
    if (hour > 23 or minute > 59 or second > 60) return error.InvalidDateFormat;
    const epoch_days = try civilToEpochDays(year, month, day);
    const total_secs: i64 = epoch_days * 86400 +
        @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
    const utc_secs = total_secs - @as(i64, offset_minutes) * 60;
    return utc_secs * 1000;
}

pub fn formatIso8601(ts_ms: i64, allocator: std.mem.Allocator) ![]const u8 {
    const ts_s = @divFloor(ts_ms, 1000);
    const days = @divFloor(ts_s, 86400);
    const time_of_day = @mod(ts_s, 86400);
    const hour = @divFloor(time_of_day, 3600);
    const minute = @divFloor(@mod(time_of_day, 3600), 60);
    const second = @mod(time_of_day, 60);
    var y: i64 = 0;
    var m: u32 = 0;
    var d: u32 = 0;
    epochDaysToCivil(days, &y, &m, &d);
    return std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        y, m, d, hour, minute, second,
    });
}

fn civilToEpochDays(y: i32, m: u32, d: u32) !i64 {
    var year = y;
    var month = m;
    if (month <= 2) {
        year -= 1;
        month += 9;
    } else {
        month -= 3;
    }
    const era: i64 = @divFloor(year, 400);
    const yoe: i64 = @as(i64, year) - era * 400;
    const doy: i64 = (@as(i64, month) * 153 + 2) / 5 + @as(i64, d) - 1;
    const doe: i64 = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

fn epochDaysToCivil(z: i64, out_y: *i64, out_m: *u32, out_d: *u32) void {
    const z2 = z + 719468;
    const era = @divFloor(z2, 146097);
    const doe = z2 - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    out_d.* = @intCast(doy - @divFloor(153 * mp + 2, 5) + 1);
    out_m.* = @intCast(if (mp < 10) mp + 3 else mp - 9);
    out_y.* = if (out_m.* <= 2) y + 1 else y;
}

pub fn formatDuration(ms: u64, buf: []u8) []const u8 {
    if (ms < 1000) {
        return std.fmt.bufPrint(buf, "{d}ms", .{ms}) catch buf[0..0];
    } else if (ms < 60000) {
        return std.fmt.bufPrint(buf, "{d:.2}s", .{@as(f64, @floatFromInt(ms)) / 1000.0}) catch buf[0..0];
    } else if (ms < 3600000) {
        return std.fmt.bufPrint(buf, "{d:.1}m", .{@as(f64, @floatFromInt(ms)) / 60000.0}) catch buf[0..0];
    } else {
        return std.fmt.bufPrint(buf, "{d:.1}h", .{@as(f64, @floatFromInt(ms)) / 3600000.0}) catch buf[0..0];
    }
}

test "parse iso8601 utc" {
    const ts = try parseIso8601("2024-01-15T10:30:00Z");
    try std.testing.expectEqual(@as(i64, 1705315800000), ts);
}

test "format iso8601" {
    const allocator = std.testing.allocator;
    const str = try formatIso8601(1705315800000, allocator);
    defer allocator.free(str);
    try std.testing.expectEqualStrings("2024-01-15T10:30:00Z", str);
}
