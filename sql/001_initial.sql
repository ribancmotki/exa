-- Initial schema for search platform
-- Version: 001

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Teams table
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    credit_balance_cents BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- API keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    name TEXT,
    key_hash BYTEA NOT NULL UNIQUE,
    key_prefix CHAR(8) NOT NULL,
    rate_limit_qps INTEGER,
    budget_cents BIGINT,
    spent_cents BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ
);

-- Documents table with vector support
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    title TEXT,
    author TEXT,
    published_at TIMESTAMPTZ,
    crawled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    body_text TEXT,
    body_html TEXT,
    embedding BYTEA,
    content_hash BYTEA,
    domain TEXT NOT NULL,
    language CHAR(10),
    favicon_url TEXT,
    image_url TEXT,
    word_count INTEGER
);

-- Search requests audit table
CREATE TABLE IF NOT EXISTS search_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID REFERENCES api_keys(id),
    team_id UUID REFERENCES teams(id),
    query TEXT NOT NULL,
    search_type TEXT NOT NULL,
    num_results INTEGER NOT NULL,
    category TEXT,
    cost_cents INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    duration_ms INTEGER
);

-- Content requests audit table
CREATE TABLE IF NOT EXISTS content_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID REFERENCES api_keys(id),
    team_id UUID REFERENCES teams(id),
    url TEXT NOT NULL,
    cost_cents INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Research tasks table
CREATE TABLE IF NOT EXISTS research_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    api_key_id UUID REFERENCES api_keys(id),
    model TEXT NOT NULL,
    instructions TEXT NOT NULL,
    output_schema JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    output JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    cost_dollars JSONB
);

-- Schema migrations tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Webhook attempts for debugging
CREATE TABLE IF NOT EXISTS webhook_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_id UUID NOT NULL,
    event_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    url TEXT NOT NULL,
    successful BOOLEAN NOT NULL,
    response_headers JSONB,
    response_body TEXT,
    response_status_code SMALLINT,
    attempt SMALLINT NOT NULL DEFAULT 1,
    error_message TEXT,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_api_keys_team ON api_keys(team_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_documents_domain ON documents(domain);
CREATE INDEX IF NOT EXISTS idx_search_requests_team ON search_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_search_requests_created ON search_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_requests_team ON content_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_research_tasks_team ON research_tasks(team_id);
CREATE INDEX IF NOT EXISTS idx_research_tasks_status ON research_tasks(status);