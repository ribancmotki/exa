const std = @import("std");
const common = @import("../types/common.zig");
const app_state = @import("../app_state.zig");
const time_util = @import("../utils/time.zig");
const config = @import("../config.zig");

pub fn handleHealth(req: *common.HttpRequest, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    _ = req;

    var db_ok = false;
    var redis_ok = false;

    {
        const conn = state.pg_pool.acquire();
        defer state.pg_pool.release(conn);
        var rs = conn.query("SELECT 1", &.{}) catch null;
        if (rs) |*r| {
            defer r.deinit();
            db_ok = true;
        }
    }

    {
        const client = state.redis_pool.acquire();
        defer state.redis_pool.release(client);
        _ = client.exists("__health__") catch {};
        redis_ok = true;
    }

    const overall_ok = db_ok and redis_ok;
    const status_str = if (overall_ok) "ok" else "degraded";
    const db_str = if (db_ok) "ok" else "error";
    const redis_str = if (redis_ok) "ok" else "error";

    const body = try std.fmt.allocPrint(allocator,
        "{{\"status\":\"{s}\",\"db\":\"{s}\",\"redis\":\"{s}\",\"version\":\"{s}\"}}",
        .{ status_str, db_str, redis_str, config.VERSION },
    );

    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{
        .status = if (overall_ok) 200 else 503,
        .headers = headers,
        .body = body,
    };
}
