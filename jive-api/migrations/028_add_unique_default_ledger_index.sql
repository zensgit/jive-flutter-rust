-- 028_add_unique_default_ledger_index.sql
-- Enforce at most one default ledger per family.
-- Safe to run multiple times (IF NOT EXISTS guard).

CREATE UNIQUE INDEX IF NOT EXISTS idx_ledgers_one_default
    ON ledgers(family_id)
    WHERE is_default = true;

-- Rationale:
-- Business rule: each family must have a single canonical default ledger used for
-- category and transaction fallbacks. Prior logic relies on code discipline; this
-- index guarantees integrity at the database layer and prevents race conditions
-- where two concurrent creations might both mark default.

