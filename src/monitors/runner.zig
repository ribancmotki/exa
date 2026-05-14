const std = @import("std");
const app_state = @import("../app_state.zig");
const queries = @import("../db/queries.zig");
const common = @import("../types/common.zig");
const search_engine = @import("../search/engine.zig");
const search_types = @import("../types/search.zig");
const scheduler = @import("./scheduler.zig");
const time = @import("../utils/time.zig");
const uuid = @import("../utils/uuid.zig");
const webhooks = @import("../webhooks/dispatcher.zig");

pub fn runMonitor(state: *app_state.AppState, monitor_row: common.MonitorRow, base_allocator: std.mem.Allocator) void {
    _ = base_allocator;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    runMonitorInner(state, monitor_row, allocator) catch |err| {
        std.log.warn("Monitor run failed for {s}: {}", .{ std.fmt.fmtSliceHexLower(&monitor_row.id), err });
        const run_id = queries.createMonitorRun(state.pg_pool, monitor_row.id, allocator) catch return;
        queries.updateMonitorRun(state.pg_pool, run_id, "failed", null, @errorName(err), allocator) catch {};
    };
}

fn runMonitorInner(state: *app_state.AppState, monitor_row: common.MonitorRow, allocator: std.mem.Allocator) !void {
    const run_id = try queries.createMonitorRun(state.pg_pool, monitor_row.id, allocator);

    const engine = search_engine.SearchEngine{
        .cfg = state.cfg,
        .pg_pool = state.pg_pool,
        .redis_pool = state.redis_pool,
        .hnsw_index = state.hnsw_index,
        .embedding_client = state.embedding_client,
        .llm_client = state.llm_client,
    };

    var query_str: []const u8 = "";
    if (monitor_row.search_config == .object) {
        if (monitor_row.search_config.object.get("query")) |q| {
            if (q == .string) query_str = q.string;
        }
    }

    const dummy_auth = common.AuthContext{
        .api_key_id = monitor_row.team_id,
        .team_id = monitor_row.team_id,
        .team_balance_cents = 1_000_000,
        .rate_limit_qps = 100,
        .key_budget_cents = null,
        .key_spent_cents = 0,
    };

    if (query_str.len > 0) {
        const search_req = search_types.SearchRequest{
            .query = query_str,
            .type = .auto,
            .num_results = 10,
        };
        const search_resp = engine.search(search_req, dummy_auth, allocator) catch null;
        _ = search_resp;
    }

    try queries.updateMonitorRun(state.pg_pool, run_id, "completed", null, null, allocator);

    if (monitor_row.trigger_config) |trigger| {
        if (trigger == .object) {
            if (trigger.object.get("period")) |pv| {
                if (pv == .string) {
                    const period_secs = scheduler.parsePeriod(pv.string) catch 3600;
                    const next_run = scheduler.computeNextRun(period_secs);
                    queries.setMonitorNextRun(state.pg_pool, monitor_row.id, next_run, allocator) catch {};
                }
            }
        }
    }

    const event_data = std.json.Value{ .null = {} };
    webhooks.dispatchEvent(state.pg_pool, state.redis_pool, monitor_row.team_id, "monitor.run.completed", event_data, allocator) catch {};
}
