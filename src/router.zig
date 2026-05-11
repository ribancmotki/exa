const std = @import("std");
const common = @import("types/common.zig");
const app_state = @import("app_state.zig");
const middleware_auth = @import("middleware/auth.zig");
const middleware_cors = @import("middleware/cors.zig");
const search_handler = @import("handlers/search.zig");
const contents_handler = @import("handlers/contents.zig");
const answer_handler = @import("handlers/answer.zig");
const research_handler = @import("handlers/research.zig");
const monitors_handler = @import("handlers/monitors.zig");
const websets_handler = @import("handlers/websets.zig");
const team_handler = @import("handlers/team_management.zig");
const health_handler = @import("handlers/health.zig");
const mcp_handler = @import("mcp/server.zig");

pub fn route(
    req: *common.HttpRequest,
    state: *app_state.AppState,
    allocator: std.mem.Allocator,
) !common.HttpResponse {
    const path = req.path;
    const method = req.method;

    if (std.mem.eql(u8, path, "/health") or std.mem.eql(u8, path, "/healthz")) {
        return health_handler.handleHealth(req, state, allocator);
    }

    if (std.mem.eql(u8, path, "/v1/mcp") or std.mem.startsWith(u8, path, "/v1/mcp/")) {
        return mcp_handler.handleMcp(req, state, allocator);
    }

    const auth = try middleware_auth.authenticate(req, state.pg_pool, state.redis_pool, allocator);

    if (matchRoute(method, path, "POST", "/search")) {
        return search_handler.handleSearch(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/contents")) {
        return contents_handler.handleContents(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/search/context")) {
        return search_handler.handleContext(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/search")) {
        return search_handler.handleSearch(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/contents")) {
        return contents_handler.handleContents(req, auth, state, allocator);
    }

    if (matchRoute(method, path, "POST", "/answer")) {
        return answer_handler.handleAnswer(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/chat/completions")) {
        return answer_handler.handleChatCompletions(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/responses")) {
        return answer_handler.handleResponses(req, auth, state, allocator);
    }

    if (matchRoute(method, path, "POST", "/v1/research/tasks")) {
        return research_handler.createTask(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "GET", "/v1/research/tasks")) {
        return research_handler.listTasks(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/research/tasks/")) {
        const task_id = path["/v1/research/tasks/".len..];
        return research_handler.getTask(req, auth, state, task_id, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/research/tasks/")) {
        const task_id = path["/v1/research/tasks/".len..];
        return research_handler.cancelTask(req, auth, state, task_id, allocator);
    }

    if (matchRoute(method, path, "GET", "/v1/monitors")) {
        return monitors_handler.listMonitors(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/monitors")) {
        return monitors_handler.createMonitor(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/monitors/batch")) {
        return monitors_handler.batchMonitors(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/monitors/")) {
        const rest = path["/v1/monitors/".len..];
        if (std.mem.indexOf(u8, rest, "/runs")) |ri| {
            const monitor_id = rest[0..ri];
            const after_runs = rest[ri + "/runs".len..];
            if (after_runs.len == 0) {
                return monitors_handler.listRuns(req, auth, state, monitor_id, allocator);
            }
            const run_id = if (after_runs[0] == '/') after_runs[1..] else after_runs;
            return monitors_handler.getRun(req, auth, state, monitor_id, run_id, allocator);
        }
        return monitors_handler.getMonitor(req, auth, state, rest, allocator);
    }
    if (matchPrefix(method, path, "PATCH", "/v1/monitors/")) {
        const monitor_id = path["/v1/monitors/".len..];
        return monitors_handler.updateMonitor(req, auth, state, monitor_id, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/monitors/")) {
        const monitor_id = path["/v1/monitors/".len..];
        return monitors_handler.deleteMonitor(req, auth, state, monitor_id, allocator);
    }
    if (matchPrefix(method, path, "POST", "/v1/monitors/")) {
        const rest = path["/v1/monitors/".len..];
        if (std.mem.endsWith(u8, rest, "/trigger")) {
            const monitor_id = rest[0 .. rest.len - "/trigger".len];
            return monitors_handler.triggerMonitor(req, auth, state, monitor_id, allocator);
        }
    }

    if (matchRoute(method, path, "GET", "/v1/websets")) {
        return websets_handler.listWebsets(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/websets")) {
        return websets_handler.createWebset(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/websets/preview")) {
        return websets_handler.previewWebset(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/websets/")) {
        return routeWebset(req, auth, state, path, method, allocator);
    }
    if (matchPrefix(method, path, "PATCH", "/v1/websets/")) {
        return routeWebset(req, auth, state, path, method, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/websets/")) {
        return routeWebset(req, auth, state, path, method, allocator);
    }
    if (matchPrefix(method, path, "POST", "/v1/websets/")) {
        return routeWebset(req, auth, state, path, method, allocator);
    }
    if (matchPrefix(method, path, "PUT", "/v1/websets/")) {
        return routeWebset(req, auth, state, path, method, allocator);
    }

    if (matchRoute(method, path, "GET", "/v1/events")) {
        return websets_handler.listEvents(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/events/")) {
        const event_id = path["/v1/events/".len..];
        return websets_handler.getEvent(req, auth, state, event_id, allocator);
    }

    if (matchRoute(method, path, "GET", "/v1/webhooks")) {
        return websets_handler.listWebhooks(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/webhooks")) {
        return websets_handler.createWebhook(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/webhooks/")) {
        const rest = path["/v1/webhooks/".len..];
        if (std.mem.indexOf(u8, rest, "/attempts")) |ai| {
            const webhook_id = rest[0..ai];
            return websets_handler.listWebhookAttempts(req, auth, state, webhook_id, allocator);
        }
        return websets_handler.getWebhook(req, auth, state, rest, allocator);
    }
    if (matchPrefix(method, path, "PATCH", "/v1/webhooks/")) {
        const webhook_id = path["/v1/webhooks/".len..];
        return websets_handler.updateWebhook(req, auth, state, webhook_id, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/webhooks/")) {
        const webhook_id = path["/v1/webhooks/".len..];
        return websets_handler.deleteWebhook(req, auth, state, webhook_id, allocator);
    }

    if (matchRoute(method, path, "GET", "/v1/team/apikeys")) {
        return team_handler.listApiKeys(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/team/apikeys")) {
        return team_handler.createApiKey(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/team/apikeys/")) {
        const rest = path["/v1/team/apikeys/".len..];
        if (std.mem.endsWith(u8, rest, "/usage")) {
            const key_id = rest[0 .. rest.len - "/usage".len];
            return team_handler.getApiKeyUsage(req, auth, state, key_id, allocator);
        }
        return team_handler.getApiKey(req, auth, state, rest, allocator);
    }
    if (matchPrefix(method, path, "PATCH", "/v1/team/apikeys/")) {
        const key_id = path["/v1/team/apikeys/".len..];
        return team_handler.updateApiKey(req, auth, state, key_id, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/team/apikeys/")) {
        const key_id = path["/v1/team/apikeys/".len..];
        return team_handler.deleteApiKey(req, auth, state, key_id, allocator);
    }
    if (matchRoute(method, path, "GET", "/v1/team")) {
        return websets_handler.getTeamInfo(req, auth, state, allocator);
    }

    if (matchRoute(method, path, "GET", "/v1/imports")) {
        return websets_handler.listImports(req, auth, state, allocator);
    }
    if (matchRoute(method, path, "POST", "/v1/imports")) {
        return websets_handler.createImport(req, auth, state, allocator);
    }
    if (matchPrefix(method, path, "GET", "/v1/imports/")) {
        const import_id = path["/v1/imports/".len..];
        return websets_handler.getImport(req, auth, state, import_id, allocator);
    }
    if (matchPrefix(method, path, "PATCH", "/v1/imports/")) {
        const import_id = path["/v1/imports/".len..];
        return websets_handler.updateImport(req, auth, state, import_id, allocator);
    }
    if (matchPrefix(method, path, "DELETE", "/v1/imports/")) {
        const import_id = path["/v1/imports/".len..];
        return websets_handler.deleteImport(req, auth, state, import_id, allocator);
    }

    var not_found_headers = std.StringHashMap([]const u8).init(allocator);
    try not_found_headers.put("content-type", "application/json");
    return common.HttpResponse{
        .status = 404,
        .headers = not_found_headers,
        .body = "{\"error\":\"Not Found\",\"tag\":\"NOT_FOUND\"}",
    };
}

fn routeWebset(req: *common.HttpRequest, auth: common.AuthContext, state: *app_state.AppState, path: []const u8, method: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    const rest = path["/v1/websets/".len..];
    const slash = std.mem.indexOfScalar(u8, rest, '/');
    const webset_id = if (slash) |s| rest[0..s] else rest;
    const sub = if (slash) |s| rest[s..] else "";

    if (sub.len == 0) {
        if (std.mem.eql(u8, method, "GET")) return websets_handler.getWebset(req, auth, state, webset_id, allocator);
        if (std.mem.eql(u8, method, "PATCH")) return websets_handler.updateWebset(req, auth, state, webset_id, allocator);
        if (std.mem.eql(u8, method, "DELETE")) return websets_handler.deleteWebset(req, auth, state, webset_id, allocator);
    }

    if (std.mem.eql(u8, sub, "/cancel") and std.mem.eql(u8, method, "POST")) {
        return websets_handler.cancelWebset(req, auth, state, webset_id, allocator);
    }

    if (std.mem.startsWith(u8, sub, "/searches")) {
        const after = sub["/searches".len..];
        if (after.len == 0 and std.mem.eql(u8, method, "POST")) {
            return websets_handler.createSearch(req, auth, state, webset_id, allocator);
        }
        if (after.len > 1) {
            const search_id = if (after[0] == '/') after[1..] else after;
            const search_slash = std.mem.indexOfScalar(u8, search_id, '/');
            const sid = if (search_slash) |s| search_id[0..s] else search_id;
            const search_sub = if (search_slash) |s| search_id[s..] else "";
            if (search_sub.len == 0) {
                if (std.mem.eql(u8, method, "GET")) return websets_handler.getSearch(req, auth, state, webset_id, sid, allocator);
            }
            if (std.mem.eql(u8, search_sub, "/cancel") and std.mem.eql(u8, method, "POST")) {
                return websets_handler.cancelSearch(req, auth, state, webset_id, sid, allocator);
            }
        }
    }

    if (std.mem.startsWith(u8, sub, "/items")) {
        const after = sub["/items".len..];
        if (after.len == 0 and std.mem.eql(u8, method, "GET")) {
            return websets_handler.listItems(req, auth, state, webset_id, allocator);
        }
        if (after.len > 1) {
            const item_id = if (after[0] == '/') after[1..] else after;
            if (std.mem.eql(u8, method, "GET")) return websets_handler.getItem(req, auth, state, webset_id, item_id, allocator);
            if (std.mem.eql(u8, method, "DELETE")) return websets_handler.deleteItem(req, auth, state, webset_id, item_id, allocator);
        }
    }

    if (std.mem.startsWith(u8, sub, "/enrichments")) {
        const after = sub["/enrichments".len..];
        if (after.len == 0) {
            if (std.mem.eql(u8, method, "POST")) return websets_handler.createEnrichment(req, auth, state, webset_id, allocator);
        }
        if (after.len > 1) {
            const enr_rest = if (after[0] == '/') after[1..] else after;
            const enr_slash = std.mem.indexOfScalar(u8, enr_rest, '/');
            const enr_id = if (enr_slash) |s| enr_rest[0..s] else enr_rest;
            const enr_sub = if (enr_slash) |s| enr_rest[s..] else "";
            if (enr_sub.len == 0) {
                if (std.mem.eql(u8, method, "GET")) return websets_handler.getEnrichment(req, auth, state, webset_id, enr_id, allocator);
                if (std.mem.eql(u8, method, "PUT")) return websets_handler.updateEnrichment(req, auth, state, webset_id, enr_id, allocator);
                if (std.mem.eql(u8, method, "DELETE")) return websets_handler.deleteEnrichment(req, auth, state, webset_id, enr_id, allocator);
            }
            if (std.mem.eql(u8, enr_sub, "/cancel") and std.mem.eql(u8, method, "POST")) {
                return websets_handler.cancelEnrichment(req, auth, state, webset_id, enr_id, allocator);
            }
        }
    }

    if (std.mem.startsWith(u8, sub, "/exports")) {
        const after = sub["/exports".len..];
        if (after.len == 0 and std.mem.eql(u8, method, "POST")) {
            return websets_handler.createExport(req, auth, state, webset_id, allocator);
        }
        if (after.len > 1) {
            const export_id = if (after[0] == '/') after[1..] else after;
            if (std.mem.eql(u8, method, "GET")) return websets_handler.getExport(req, auth, state, webset_id, export_id, allocator);
        }
    }

    if (std.mem.startsWith(u8, sub, "/monitors")) {
        const after = sub["/monitors".len..];
        if (after.len == 0) {
            if (std.mem.eql(u8, method, "GET")) return websets_handler.listWebsetMonitors(req, auth, state, allocator);
            if (std.mem.eql(u8, method, "POST")) return websets_handler.createWebsetMonitor(req, auth, state, allocator);
        }
        if (after.len > 1) {
            const mon_rest = if (after[0] == '/') after[1..] else after;
            const mon_slash = std.mem.indexOfScalar(u8, mon_rest, '/');
            const mon_id = if (mon_slash) |s| mon_rest[0..s] else mon_rest;
            const mon_sub = if (mon_slash) |s| mon_rest[s..] else "";
            if (mon_sub.len == 0) {
                if (std.mem.eql(u8, method, "GET")) return websets_handler.getWebsetMonitor(req, auth, state, mon_id, allocator);
                if (std.mem.eql(u8, method, "PATCH")) return websets_handler.updateWebsetMonitor(req, auth, state, mon_id, allocator);
                if (std.mem.eql(u8, method, "DELETE")) return websets_handler.deleteWebsetMonitor(req, auth, state, mon_id, allocator);
            }
            if (std.mem.startsWith(u8, mon_sub, "/runs")) {
                const runs_after = mon_sub["/runs".len..];
                if (runs_after.len == 0 and std.mem.eql(u8, method, "GET")) {
                    return websets_handler.listWebsetMonitorRuns(req, auth, state, mon_id, allocator);
                }
                if (runs_after.len > 1) {
                    const run_id = if (runs_after[0] == '/') runs_after[1..] else runs_after;
                    if (std.mem.eql(u8, method, "GET")) return websets_handler.getWebsetMonitorRun(req, auth, state, mon_id, run_id, allocator);
                }
            }
        }
    }

    var h = std.StringHashMap([]const u8).init(allocator);
    try h.put("content-type", "application/json");
    return common.HttpResponse{
        .status = 404,
        .headers = h,
        .body = "{\"error\":\"Not Found\"}",
    };
}

fn matchRoute(method: []const u8, path: []const u8, want_method: []const u8, want_path: []const u8) bool {
    return std.mem.eql(u8, method, want_method) and std.mem.eql(u8, path, want_path);
}

fn matchPrefix(method: []const u8, path: []const u8, want_method: []const u8, prefix: []const u8) bool {
    return std.mem.eql(u8, method, want_method) and std.mem.startsWith(u8, path, prefix);
}
