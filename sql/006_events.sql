-- Events schema
-- Version: 006

-- Platform events already created in 002_indexes.sql
-- This file contains additional event-related functionality

-- Event delivery status tracking
CREATE TABLE IF NOT EXISTS event_delivery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL,
    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'failed')),
    attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_delivery_webhook ON event_delivery(webhook_id);
CREATE INDEX IF NOT EXISTS idx_event_delivery_status ON event_delivery(status) WHERE status != 'delivered';