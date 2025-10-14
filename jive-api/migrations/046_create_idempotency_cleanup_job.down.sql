-- Migration Rollback: Drop idempotency cleanup function
-- Purpose: Rollback for 046_create_idempotency_cleanup_job.sql
-- Author: Claude Code
-- Date: 2025-10-14

-- Drop pg_cron job if it was created (uncomment if applicable)
-- SELECT cron.unschedule('cleanup-idempotency');

-- Drop the cleanup function
DROP FUNCTION IF EXISTS cleanup_expired_idempotency_records();
