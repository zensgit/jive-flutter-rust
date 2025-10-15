-- Migration: Create idempotency_records table
-- Purpose: Support idempotency for API requests to prevent duplicate operations
-- Author: Claude Code
-- Date: 2025-10-14

-- Create idempotency_records table
CREATE TABLE IF NOT EXISTS idempotency_records (
    -- Primary key: unique request identifier
    request_id UUID PRIMARY KEY,

    -- Operation metadata
    operation VARCHAR(100) NOT NULL,
    result_payload TEXT NOT NULL,
    status_code INTEGER,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,

    -- Ensure expires_at is in the future
    CONSTRAINT chk_expires_at CHECK (expires_at > created_at)
);

-- Index for cleanup operations (finding expired records)
CREATE INDEX idx_idempotency_expires ON idempotency_records(expires_at);

-- Index for operation-based queries (optional, for analytics)
CREATE INDEX idx_idempotency_operation ON idempotency_records(operation);

-- Add comments for documentation
COMMENT ON TABLE idempotency_records IS 'Stores idempotency records for duplicate request prevention. Records automatically expire based on TTL.';
COMMENT ON COLUMN idempotency_records.request_id IS 'Unique request identifier (idempotency key) - used to detect duplicate requests';
COMMENT ON COLUMN idempotency_records.operation IS 'Operation name (e.g., create_transaction, transfer) for debugging and analytics';
COMMENT ON COLUMN idempotency_records.result_payload IS 'JSON serialized result for cached responses - returned for duplicate requests';
COMMENT ON COLUMN idempotency_records.status_code IS 'HTTP status code for API operations (e.g., 201 for created, 200 for success)';
COMMENT ON COLUMN idempotency_records.created_at IS 'Timestamp when the idempotency record was created';
COMMENT ON COLUMN idempotency_records.expires_at IS 'Automatic expiry timestamp (TTL) - records past this time can be cleaned up';

-- Grant permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON idempotency_records TO jive_api_user;
