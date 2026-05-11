-- Additional indexes for search performance
-- Version: 002

-- Document indexes
CREATE INDEX IF NOT EXISTS idx_documents_published_at ON documents(published_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_documents_crawled_at ON documents(crawled_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_language ON documents(language);
CREATE INDEX IF NOT EXISTS idx_documents_domain ON documents(domain);

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_documents_fulltext ON documents USING GIN (
    to_tsvector('english', COALESCE(body_text, ''))
);

-- API key usage tracking
CREATE TABLE IF NOT EXISTS api_key_usage_daily (
    api_key_id UUID NOT NULL REFERENCES api_keys(id),
    date DATE NOT NULL,
    total_requests INTEGER NOT NULL DEFAULT 0,
    total_cost_cents BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (api_key_id, date)
);

CREATE INDEX IF NOT EXISTS idx_usage_daily_key_date ON api_key_usage_daily(api_key_id, date DESC);

-- Webhooks table
CREATE TABLE IF NOT EXISTS webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    url TEXT NOT NULL,
    events TEXT[] NOT NULL DEFAULT '{}',
    secret BYTEA NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_webhooks_team ON webhooks(team_id);

-- Platform events
CREATE TABLE IF NOT EXISTS platform_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    type TEXT NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_platform_events_team ON platform_events(team_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_events_type ON platform_events(team_id, type, created_at DESC);

-- Auto-delete events after 60 days
CREATE OR REPLACE FUNCTION delete_old_events() RETURNS void AS $$
BEGIN
    DELETE FROM platform_events WHERE created_at < now() - INTERVAL '60 days';
END;
$$ LANGUAGE plpgsql;