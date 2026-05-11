const std = @import("std");
const pool = @import("../db/pool.zig");
const queries = @import("../db/queries.zig");
const common = @import("../types/common.zig");

pub fn charge(
    db_pool: *pool.Pool,
    team_id: [16]u8,
    api_key_id: ?[16]u8,
    amount_cents: i64,
    description: []const u8,
) !void {
    _ = db_pool;
    _ = team_id;
    _ = api_key_id;
    _ = amount_cents;
    _ = description;
}

pub fn checkBalance(db_pool: *pool.Pool, team_id: [16]u8) !i64 {
    _ = db_pool;
    _ = team_id;
    return 10000;
}

pub fn addCredits(
    db_pool: *pool.Pool,
    team_id: [16]u8,
    amount_cents: i64,
    description: []const u8,
) !void {
    _ = db_pool;
    _ = team_id;
    _ = amount_cents;
    _ = description;
}