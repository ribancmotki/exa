const std = @import("std");
const common = @import("../types/common.zig");
const time = @import("../utils/time.zig");
const uuid_util = @import("../utils/uuid.zig");

pub const Logger = struct {
    level: []const u8,

    pub fn init(level: []const u8) Logger {
        return Logger{ .level = level };
    }

    pub fn logRequest(self: *const Logger, req: *const common.HttpRequest, status: u16, duration_ms: u64, team_id: ?[16]u8) void {
        _ = self;
        if (team_id) |tid| {
            std.log.info("{s} {s} {d} {d}ms team={s}", .{
                req.method, req.path, status, duration_ms, std.fmt.fmtSliceHexLower(&tid),
            });
        } else {
            std.log.info("{s} {s} {d} {d}ms", .{ req.method, req.path, status, duration_ms });
        }
    }

    pub fn logInfo(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        _ = self;
        std.log.info(msg, args);
    }

    pub fn logError(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        _ = self;
        std.log.err(msg, args);
    }

    pub fn logWarn(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        _ = self;
        std.log.warn(msg, args);
    }

    pub fn logDebug(self: *const Logger, comptime msg: []const u8, args: anytype) void {
        if (std.mem.eql(u8, self.level, "debug")) {
            std.log.debug(msg, args);
        }
    }
};
