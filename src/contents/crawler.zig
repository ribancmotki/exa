const std = @import("std");
const config_mod = @import("../config.zig");
const http_client = @import("../utils/http_client.zig");
const parser = @import("./parser.zig");
const crypto = @import("../utils/crypto.zig");

pub const Crawler = struct {
    cfg: *const config_mod.Config,

    pub const CrawlResult = struct {
        url: []const u8,
        content_hash: [32]u8,
        parsed: parser.ParsedDocument,
        status_code: u16,
    };

    pub fn fetch(self: *const Crawler, url: []const u8, allocator: std.mem.Allocator) !CrawlResult {
        var resp = http_client.fetchUrl(
            url, "GET", "", self.cfg.crawler_user_agent, self.cfg.crawler_timeout_ms, allocator,
        ) catch |err| {
            std.log.warn("Crawl failed for {s}: {}", .{ url, err });
            return error.FetchDocumentError;
        };
        defer allocator.free(resp.body);

        if (resp.status >= 400) {
            return error.FetchDocumentError;
        }

        const body_limited = if (resp.body.len > self.cfg.crawler_max_body_bytes)
            resp.body[0..self.cfg.crawler_max_body_bytes]
        else
            resp.body;

        var content_hash: [32]u8 = undefined;
        crypto.sha256(body_limited, &content_hash);

        const parsed_doc = try parser.parseHtml(body_limited, allocator);

        return CrawlResult{
            .url = try allocator.dupe(u8, url),
            .content_hash = content_hash,
            .parsed = parsed_doc,
            .status_code = resp.status,
        };
    }

    pub fn fetchSubpages(self: *const Crawler, url: []const u8, targets: ?[][]const u8, limit: usize, allocator: std.mem.Allocator) ![]CrawlResult {
        _ = targets;
        _ = limit;
        const main = self.fetch(url, allocator) catch return &.{};
        var results = try allocator.alloc(CrawlResult, 1);
        results[0] = main;
        return results;
    }
};
