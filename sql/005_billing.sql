-- Billing schema
-- Version: 005

CREATE TABLE IF NOT EXISTS billing_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(id),
    api_key_id UUID REFERENCES api_keys(id),
    event_type TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    description TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_billing_team_created ON billing_events(team_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_billing_api_key ON billing_events(api_key_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_billing_event_type ON billing_events(event_type);