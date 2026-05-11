const std = @import("std");
const pool = @import("pool.zig");

const MIGRATIONS = [_]struct { version: []const u8, sql: []const u8 }{
    .{ .version = "001_initial", .sql = 
        \\CREATE TABLE IF NOT EXISTS schema_migrations (
        \\    version TEXT PRIMARY KEY,
        \\    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
    },
    .{ .version = "002_teams", .sql =
        \\CREATE TABLE IF NOT EXISTS teams (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    name TEXT NOT NULL,
        \\    credit_balance_cents BIGINT NOT NULL DEFAULT 0,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
    },
    .{ .version = "003_api_keys", .sql =
        \\CREATE TABLE IF NOT EXISTS api_keys (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    name TEXT,
        \\    key_hash BYTEA NOT NULL UNIQUE,
        \\    key_prefix TEXT NOT NULL,
        \\    rate_limit_qps INTEGER,
        \\    budget_cents BIGINT,
        \\    spent_cents BIGINT NOT NULL DEFAULT 0,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    revoked_at TIMESTAMPTZ
        \\);
        \\CREATE INDEX IF NOT EXISTS api_keys_team_id ON api_keys(team_id);
        \\CREATE INDEX IF NOT EXISTS api_keys_key_hash ON api_keys(key_hash);
    },
    .{ .version = "004_documents", .sql =
        \\CREATE TABLE IF NOT EXISTS documents (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    url TEXT NOT NULL UNIQUE,
        \\    domain TEXT NOT NULL,
        \\    title TEXT,
        \\    author TEXT,
        \\    published_at TIMESTAMPTZ,
        \\    crawled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    body_text TEXT,
        \\    body_html TEXT,
        \\    embedding REAL[],
        \\    content_hash BYTEA NOT NULL DEFAULT '\x00',
        \\    language TEXT,
        \\    favicon_url TEXT,
        \\    image_url TEXT,
        \\    word_count INTEGER,
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS documents_domain ON documents(domain);
        \\CREATE INDEX IF NOT EXISTS documents_published_at ON documents(published_at);
        \\CREATE INDEX IF NOT EXISTS documents_crawled_at ON documents(crawled_at);
        \\CREATE INDEX IF NOT EXISTS documents_url ON documents(url);
    },
    .{ .version = "005_fts", .sql =
        \\ALTER TABLE documents ADD COLUMN IF NOT EXISTS fts_vector tsvector
        \\    GENERATED ALWAYS AS (
        \\        to_tsvector('english', coalesce(title,'') || ' ' || coalesce(body_text,''))
        \\    ) STORED;
        \\CREATE INDEX IF NOT EXISTS documents_fts ON documents USING GIN(fts_vector);
    },
    .{ .version = "006_monitors", .sql =
        \\CREATE TABLE IF NOT EXISTS monitors (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    name TEXT,
        \\    status TEXT NOT NULL DEFAULT 'active',
        \\    search_config JSONB NOT NULL DEFAULT '{}',
        \\    trigger_config JSONB,
        \\    output_schema JSONB,
        \\    metadata JSONB,
        \\    webhook_url TEXT NOT NULL DEFAULT '',
        \\    webhook_events TEXT[] NOT NULL DEFAULT '{}',
        \\    webhook_secret TEXT NOT NULL DEFAULT '',
        \\    next_run_at TIMESTAMPTZ,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS monitors_team_id ON monitors(team_id);
        \\CREATE INDEX IF NOT EXISTS monitors_next_run_at ON monitors(next_run_at) WHERE status = 'active';
    },
    .{ .version = "007_monitor_runs", .sql =
        \\CREATE TABLE IF NOT EXISTS monitor_runs (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    monitor_id UUID NOT NULL REFERENCES monitors(id) ON DELETE CASCADE,
        \\    status TEXT NOT NULL DEFAULT 'pending',
        \\    output JSONB,
        \\    fail_reason TEXT,
        \\    started_at TIMESTAMPTZ,
        \\    completed_at TIMESTAMPTZ,
        \\    failed_at TIMESTAMPTZ,
        \\    cancelled_at TIMESTAMPTZ,
        \\    duration_ms INTEGER,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS monitor_runs_monitor_id ON monitor_runs(monitor_id);
    },
    .{ .version = "008_websets", .sql =
        \\CREATE TABLE IF NOT EXISTS websets (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    external_id TEXT,
        \\    status TEXT NOT NULL DEFAULT 'idle',
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS websets_team_id ON websets(team_id);
        \\CREATE UNIQUE INDEX IF NOT EXISTS websets_external_id ON websets(team_id, external_id) WHERE external_id IS NOT NULL;
        \\
        \\CREATE TABLE IF NOT EXISTS webset_searches (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
        \\    status TEXT NOT NULL DEFAULT 'created',
        \\    query TEXT NOT NULL,
        \\    entity_type TEXT,
        \\    entity_description TEXT,
        \\    criteria JSONB NOT NULL DEFAULT '[]',
        \\    count INTEGER NOT NULL DEFAULT 10,
        \\    max_people_per_company INTEGER,
        \\    behaviour TEXT NOT NULL DEFAULT 'override',
        \\    progress_found INTEGER NOT NULL DEFAULT 0,
        \\    progress_completion REAL NOT NULL DEFAULT 0,
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS webset_searches_webset_id ON webset_searches(webset_id);
        \\
        \\CREATE TABLE IF NOT EXISTS webset_items (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
        \\    source TEXT NOT NULL DEFAULT 'search',
        \\    source_id UUID,
        \\    properties JSONB NOT NULL DEFAULT '{}',
        \\    evaluations JSONB NOT NULL DEFAULT '{}',
        \\    enrichments JSONB NOT NULL DEFAULT '{}',
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS webset_items_webset_id ON webset_items(webset_id);
    },
    .{ .version = "009_enrichments", .sql =
        \\CREATE TABLE IF NOT EXISTS webset_enrichments (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
        \\    status TEXT NOT NULL DEFAULT 'pending',
        \\    title TEXT,
        \\    description TEXT NOT NULL DEFAULT '',
        \\    format TEXT,
        \\    options JSONB,
        \\    instructions TEXT,
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS webset_enrichments_webset_id ON webset_enrichments(webset_id);
    },
    .{ .version = "010_webhooks", .sql =
        \\CREATE TABLE IF NOT EXISTS webhooks (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    url TEXT NOT NULL,
        \\    events TEXT[] NOT NULL DEFAULT '{}',
        \\    secret TEXT NOT NULL DEFAULT '',
        \\    status TEXT NOT NULL DEFAULT 'active',
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS webhooks_team_id ON webhooks(team_id);
        \\
        \\CREATE TABLE IF NOT EXISTS webhook_attempts (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
        \\    event_type TEXT NOT NULL,
        \\    payload JSONB NOT NULL DEFAULT '{}',
        \\    status TEXT NOT NULL DEFAULT 'pending',
        \\    http_status INTEGER,
        \\    response_body TEXT,
        \\    attempt_number INTEGER NOT NULL DEFAULT 1,
        \\    next_retry_at TIMESTAMPTZ,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    delivered_at TIMESTAMPTZ
        \\);
        \\CREATE INDEX IF NOT EXISTS webhook_attempts_webhook_id ON webhook_attempts(webhook_id);
        \\CREATE INDEX IF NOT EXISTS webhook_attempts_next_retry ON webhook_attempts(next_retry_at) WHERE status = 'pending';
    },
    .{ .version = "011_events", .sql =
        \\CREATE TABLE IF NOT EXISTS events (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    type TEXT NOT NULL,
        \\    data JSONB NOT NULL DEFAULT '{}',
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS events_team_id ON events(team_id);
        \\CREATE INDEX IF NOT EXISTS events_created_at ON events(created_at);
    },
    .{ .version = "012_billing", .sql =
        \\CREATE TABLE IF NOT EXISTS billing_events (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
        \\    event_type TEXT NOT NULL,
        \\    amount_cents BIGINT NOT NULL,
        \\    description TEXT,
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS billing_events_team_id ON billing_events(team_id);
        \\CREATE INDEX IF NOT EXISTS billing_events_created_at ON billing_events(created_at);
    },
    .{ .version = "013_research", .sql =
        \\CREATE TABLE IF NOT EXISTS research_tasks (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    model TEXT NOT NULL DEFAULT 'exa-research',
        \\    instructions TEXT NOT NULL,
        \\    output_schema JSONB,
        \\    status TEXT NOT NULL DEFAULT 'pending',
        \\    output JSONB,
        \\    error_message TEXT,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    started_at TIMESTAMPTZ,
        \\    finished_at TIMESTAMPTZ,
        \\    cost_dollars JSONB
        \\);
        \\CREATE INDEX IF NOT EXISTS research_tasks_team_id ON research_tasks(team_id);
    },
    .{ .version = "014_imports", .sql =
        \\CREATE TABLE IF NOT EXISTS imports (
        \\    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        \\    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
        \\    webset_id UUID REFERENCES websets(id) ON DELETE SET NULL,
        \\    status TEXT NOT NULL DEFAULT 'pending',
        \\    source_type TEXT NOT NULL DEFAULT 'csv',
        \\    file_url TEXT,
        \\    total_rows INTEGER,
        \\    processed_rows INTEGER NOT NULL DEFAULT 0,
        \\    failed_rows INTEGER NOT NULL DEFAULT 0,
        \\    metadata JSONB,
        \\    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        \\    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
        \\);
        \\CREATE INDEX IF NOT EXISTS imports_team_id ON imports(team_id);
    },
    .{ .version = "015_default_team", .sql =
        \\INSERT INTO teams (id, name, credit_balance_cents)
        \\VALUES ('00000000-0000-0000-0000-000000000001', 'Default Team', 1000000000)
        \\ON CONFLICT DO NOTHING;
    },
};

pub const Migrations = struct {
    pub fn run(pg_pool: *pool.Pool, allocator: std.mem.Allocator) !void {
        _ = allocator;
        const conn = pg_pool.acquire();
        defer pg_pool.release(conn);

        try conn.execCommand(
            \\CREATE TABLE IF NOT EXISTS schema_migrations (
            \\    version TEXT PRIMARY KEY,
            \\    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
            \\)
        , &.{});

        for (MIGRATIONS) |migration| {
            const already_applied = blk: {
                var rs = conn.query(
                    "SELECT 1 FROM schema_migrations WHERE version = $1",
                    &.{migration.version},
                ) catch break :blk false;
                defer rs.deinit();
                break :blk rs.numRows() > 0;
            };

            if (already_applied) continue;

            std.log.info("Applying migration: {s}", .{migration.version});
            conn.execCommand(migration.sql, &.{}) catch |err| {
                std.log.err("Migration {s} failed: {}", .{ migration.version, err });
                return err;
            };
            try conn.execCommand(
                "INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING",
                &.{migration.version},
            );
            std.log.info("Migration {s} applied", .{migration.version});
        }

        std.log.info("All database migrations complete", .{});
    }
};
