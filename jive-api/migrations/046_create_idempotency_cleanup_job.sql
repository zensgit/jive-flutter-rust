-- Migration: Create stored procedure for idempotency cleanup
-- Purpose: Provides a stored procedure for periodic cleanup of expired idempotency records
-- Author: Claude Code
-- Date: 2025-10-14
-- Note: This is optional - cleanup can also be done via application code

-- Create cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_records()
RETURNS TABLE(deleted_count BIGINT) AS $$
DECLARE
    rows_deleted BIGINT;
BEGIN
    -- Delete expired records
    DELETE FROM idempotency_records
    WHERE expires_at <= NOW();

    -- Get count of deleted rows
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;

    -- Return the count
    RETURN QUERY SELECT rows_deleted;
END;
$$ LANGUAGE plpgsql;

-- Add comment
COMMENT ON FUNCTION cleanup_expired_idempotency_records() IS
'Deletes expired idempotency records and returns the count of deleted records.
Call this function periodically (e.g., via cron or background job) to keep the table clean.
Example: SELECT * FROM cleanup_expired_idempotency_records();';

-- Optional: Create a pg_cron job (if pg_cron extension is available)
-- Uncomment the following if you have pg_cron installed:
--
-- SELECT cron.schedule(
--     'cleanup-idempotency',
--     '0 * * * *',  -- Run every hour
--     $$SELECT cleanup_expired_idempotency_records()$$
-- );

-- Grant execute permission (adjust as needed)
-- GRANT EXECUTE ON FUNCTION cleanup_expired_idempotency_records() TO jive_api_user;
