-- Monitors schema
-- Version: 003

CREATE TABLE IF NOT EXISTS monitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    name TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'disabled')),
    search_config JSONB NOT NULL,
    trigger_config JSONB,
    output_schema JSONB,
    metadata JSONB,
    webhook_url TEXT NOT NULL,
    webhook_events TEXT[] NOT NULL DEFAULT '{}',
    webhook_secret BYTEA NOT NULL,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS monitor_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    monitor_id UUID NOT NULL REFERENCES monitors(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    output JSONB,
    fail_reason TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    duration_ms INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_monitors_team ON monitors(team_id);
CREATE INDEX IF NOT EXISTS idx_monitors_next_run ON monitors(next_run_at) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_monitors_status ON monitors(status);
CREATE INDEX IF NOT EXISTS idx_monitor_runs_monitor ON monitor_runs(monitor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_monitor_runs_status ON monitor_runs(status);