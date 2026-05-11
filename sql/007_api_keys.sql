-- API keys additional schema
-- Version: 007

-- API key audit log
CREATE TABLE IF NOT EXISTS api_key_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    actor_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_key_audit_key ON api_key_audit_log(api_key_id);
CREATE INDEX IF NOT EXISTS idx_api_key_audit_created ON api_key_audit_log(created_at DESC);

-- Team audit log
CREATE TABLE IF NOT EXISTS team_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    actor_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_audit_team ON team_audit_log(team_id);
CREATE INDEX IF NOT EXISTS idx_team_audit_created ON team_audit_log(created_at DESC);