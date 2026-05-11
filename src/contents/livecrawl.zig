const std = @import("std");
const config = @import("../config.zig");
const http_client = @import("../utils/http_client.zig");
const parser = @import("./parser.zig");
const search = @import("../types/search.zig");

pub fn fetch(url: []const u8, timeout_ms: u64, allocator: std.mem.Allocator) !search.ContentStatus {
    _ = timeout_ms;
    const client = http_client.HttpClient{ .base_url = "", .timeout_ms = 10000 };
    var resp = client.request("GET", url, "", allocator) catch {
        return search.ContentStatus{
            .id = url,
            .status = "error",
            .@"error" = search.ContentError{
                .tag = .CRAWL_UNKNOWN_ERROR,
                .http_status_code = null,
            },
        };
    };
    defer allocator.free(resp.body);

    if (resp.status >= 400) {
        return search.ContentStatus{
            .id = url,
            .status = "error",
            .@"error" = search.ContentError{
                .tag = .CRAWL_NOT_FOUND,
                .http_status_code = resp.status,
            },
        };
    }

    return search.ContentStatus{
        .id = url,
        .status = "success",
        .@"error" = null,
    };
}

pub const CrawlResult = struct {
    url: []const u8,
    content_hash: [32]u8,
    parsed: parser.ParsedDocument,
    status_code: u16,
};
