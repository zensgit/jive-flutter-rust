-- Add payee_id to transactions and related index (API expects this column)
-- Safe to run multiple times due to IF NOT EXISTS guards

-- Ensure extension for uuid generation exists (if needed by payees references elsewhere)
-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Add column if missing
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS payee_id UUID REFERENCES payees(id);

-- Index for filtering by payee_id
CREATE INDEX IF NOT EXISTS idx_transactions_payee_id ON transactions(payee_id);

