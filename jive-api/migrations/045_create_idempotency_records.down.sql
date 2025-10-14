-- Migration Rollback: Drop idempotency_records table
-- Purpose: Rollback for 045_create_idempotency_records.sql
-- Author: Claude Code
-- Date: 2025-10-14

-- Drop indexes first
DROP INDEX IF EXISTS idx_idempotency_operation;
DROP INDEX IF EXISTS idx_idempotency_expires;

-- Drop the table
DROP TABLE IF EXISTS idempotency_records;
