const std = @import("std");

pub const MonitorStatus = enum { active, paused, disabled };
pub const RunStatus = enum { pending, running, completed, failed, cancelled };

pub const TriggerConfig = struct {
    type: []const u8,
    period: []const u8,
};

pub const WebhookConfig = struct {
    url: []const u8,
    events: ?[]const []const u8,
};

pub const CreateMonitorRequest = struct {
    name: ?[]const u8 = null,
    search: std.json.Value,
    trigger: ?TriggerConfig = null,
    output_schema: ?std.json.Value = null,
    metadata: ?std.json.Value = null,
    webhook: WebhookConfig,
};

pub const UpdateMonitorRequest = struct {
    name: ?[]const u8 = null,
    status: ?MonitorStatus = null,
    search: ?std.json.Value = null,
    trigger: ?TriggerConfig = null,
    output_schema: ?std.json.Value = null,
    metadata: ?std.json.Value = null,
    webhook: ?WebhookConfig = null,
};

pub const MonitorDto = struct {
    id: []const u8,
    name: ?[]const u8,
    status: MonitorStatus,
    search: std.json.Value,
    trigger: ?TriggerConfig,
    output_schema: ?std.json.Value,
    metadata: ?std.json.Value,
    webhook: WebhookConfig,
    next_run_at: ?[]const u8,
    created_at: []const u8,
    updated_at: []const u8,
    webhook_secret: ?[]const u8,
};

pub const RunOutput = struct {
    results: []const std.json.Value,
    content: ?std.json.Value,
    grounding: ?[]const std.json.Value,
};

pub const RunDto = struct {
    id: []const u8,
    monitor_id: []const u8,
    status: RunStatus,
    output: ?RunOutput,
    fail_reason: ?[]const u8,
    started_at: ?[]const u8,
    completed_at: ?[]const u8,
    failed_at: ?[]const u8,
    cancelled_at: ?[]const u8,
    duration_ms: ?u64,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const ListMonitorsResponse = struct {
    data: []const MonitorDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const ListRunsResponse = struct {
    data: []const RunDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const BatchMonitorsRequest = struct {
    action: []const u8,
    status: ?[]const u8 = null,
    dry_run: bool = true,
    limit: usize = 100,
    cursor: ?[]const u8 = null,
};

pub const BatchMonitorsResponse = struct {
    affected: usize,
    has_more: bool,
    next_cursor: ?[]const u8,
    monitors: ?[]const MonitorDto,
};

pub fn parsePeriodToSeconds(period: []const u8) !u64 {
    if (period.len < 2) return error.InvalidRequest;
    const unit = period[period.len - 1];
    const num_str = period[0 .. period.len - 1];
    const num = std.fmt.parseInt(u64, num_str, 10) catch return error.InvalidRequest;
    return switch (unit) {
        'h' => num * 3600,
        'd' => num * 86400,
        'w' => num * 604800,
        else => error.InvalidRequest,
    };
}
