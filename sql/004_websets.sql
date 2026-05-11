-- Websets schema
-- Version: 004

CREATE TABLE IF NOT EXISTS websets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    external_id TEXT,
    status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'idle', 'paused')),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (team_id, external_id)
);

CREATE TABLE IF NOT EXISTS webset_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'running', 'completed', 'canceled')),
    query TEXT NOT NULL,
    entity_type TEXT,
    entity_description TEXT,
    criteria JSONB NOT NULL DEFAULT '[]',
    count INTEGER NOT NULL DEFAULT 10,
    max_people_per_company INTEGER,
    behaviour TEXT NOT NULL DEFAULT 'override',
    progress_found INTEGER NOT NULL DEFAULT 0,
    progress_completion NUMERIC(5,2) NOT NULL DEFAULT 0,
    metadata JSONB,
    canceled_at TIMESTAMPTZ,
    canceled_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS webset_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
    source TEXT NOT NULL DEFAULT 'search',
    source_id UUID,
    properties JSONB NOT NULL,
    evaluations JSONB NOT NULL DEFAULT '[]',
    enrichments JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS webset_enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'canceled')),
    title TEXT,
    description TEXT NOT NULL,
    format TEXT,
    options JSONB,
    instructions TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS webset_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webset_id UUID NOT NULL REFERENCES websets(id) ON DELETE CASCADE,
    format TEXT NOT NULL DEFAULT 'csv',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    download_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS webset_imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webset_id UUID REFERENCES websets(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    upload_url TEXT,
    upload_valid_until TIMESTAMPTZ,
    total_urls INTEGER,
    processed_urls INTEGER NOT NULL DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_websets_team ON websets(team_id);
CREATE INDEX IF NOT EXISTS idx_webset_searches_webset ON webset_searches(webset_id);
CREATE INDEX IF NOT EXISTS idx_webset_searches_status ON webset_searches(status);
CREATE INDEX IF NOT EXISTS idx_webset_items_webset ON webset_items(webset_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webset_enrichments_webset ON webset_enrichments(webset_id);
CREATE INDEX IF NOT EXISTS idx_webset_exports_webset ON webset_exports(webset_id);
CREATE INDEX IF NOT EXISTS idx_webset_imports_team ON webset_imports(team_id);