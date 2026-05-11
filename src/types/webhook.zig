const std = @import("std");

pub const WebhookStatus = enum { active, inactive };

pub const EventType = enum {
    @"webset.created",
    @"webset.deleted",
    @"webset.paused",
    @"webset.idle",
    @"webset.search.created",
    @"webset.search.updated",
    @"webset.search.completed",
    @"webset.search.canceled",
    @"webset.item.created",
    @"webset.item.enriched",
    @"webset.export.created",
    @"webset.export.completed",
    @"import.created",
    @"import.completed",
    @"monitor.created",
    @"monitor.updated",
    @"monitor.deleted",
    @"monitor.run.created",
    @"monitor.run.completed",
    @"monitor.run.failed",
};

pub const CreateWebhookRequest = struct {
    url: []const u8,
    events: []const []const u8,
    metadata: ?std.json.Value = null,
};

pub const UpdateWebhookRequest = struct {
    url: ?[]const u8 = null,
    events: ?[]const []const u8 = null,
    status: ?WebhookStatus = null,
    metadata: ?std.json.Value = null,
};

pub const WebhookDto = struct {
    id: []const u8,
    object: []const u8,
    status: WebhookStatus,
    url: []const u8,
    events: []const []const u8,
    secret: ?[]const u8,
    metadata: ?std.json.Value,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const WebhookAttemptDto = struct {
    id: []const u8,
    object: []const u8,
    event_id: []const u8,
    event_type: []const u8,
    webhook_id: []const u8,
    url: []const u8,
    successful: bool,
    response_headers: std.json.Value,
    response_body: []const u8,
    response_status_code: u16,
    attempt: u8,
    attempted_at: []const u8,
};

pub const ListWebhooksResponse = struct {
    data: []const WebhookDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};

pub const ListAttemptsResponse = struct {
    data: []const WebhookAttemptDto,
    has_more: bool,
    next_cursor: ?[]const u8,
};
