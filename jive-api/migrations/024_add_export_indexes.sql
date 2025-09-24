-- Migration: Add composite index to optimize export queries
-- Purpose: Speed up transaction exports by date range and ledger
-- Date: 2025-09-22

-- Add composite index on transactions table for export optimization
-- This index will significantly improve performance when:
-- 1. Exporting transactions for a specific date range
-- 2. Filtering transactions by ledger_id
-- 3. Sorting transactions by date for export

-- Note: CREATE INDEX CONCURRENTLY can't be run in a transaction or function block,
-- so we create indexes directly with IF NOT EXISTS clause

-- Composite index for date and ledger filtering
CREATE INDEX IF NOT EXISTS idx_transactions_export
ON transactions (transaction_date, ledger_id)
WHERE deleted_at IS NULL;

-- Index for date-only filtering in exports
CREATE INDEX IF NOT EXISTS idx_transactions_date
ON transactions (transaction_date DESC)
WHERE deleted_at IS NULL;

-- Covering index for common export fields to enable index-only scans
-- Note: INCLUDE clause requires PostgreSQL 11+
CREATE INDEX IF NOT EXISTS idx_transactions_export_covering
ON transactions (ledger_id, transaction_date DESC)
INCLUDE (amount, description, category_id, account_id, created_at)
WHERE deleted_at IS NULL;

-- Add comments to document the indexes
COMMENT ON INDEX idx_transactions_export IS
'Composite index to optimize CSV/Excel/JSON export queries by date range and ledger';

COMMENT ON INDEX idx_transactions_date IS
'Index for efficient date-based filtering and sorting in exports';

COMMENT ON INDEX idx_transactions_export_covering IS
'Covering index with included columns for efficient export queries (index-only scans)';

-- Analyze the transactions table to update statistics after index creation
ANALYZE transactions;

-- Add comment to document the optimization
COMMENT ON TABLE transactions IS
'Main transactions table with optimized indexes for export operations.
Indexes: idx_transactions_export (date+ledger), idx_transactions_date (date only),
idx_transactions_export_covering (covering index with common export fields)';