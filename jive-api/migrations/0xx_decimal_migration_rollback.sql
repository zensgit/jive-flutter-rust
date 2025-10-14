BEGIN;

-- Record rollback intent
CREATE TABLE IF NOT EXISTS migration_rollback_flag (
    rolled_back_at TIMESTAMPTZ DEFAULT NOW(),
    reason TEXT
);

INSERT INTO migration_rollback_flag (reason)
VALUES ('Emergency rollback from Decimal to f64');

-- Type rollback (lossy!)
ALTER TABLE IF EXISTS accounts
    ALTER COLUMN current_balance TYPE double precision
    USING current_balance::double precision;

ALTER TABLE IF EXISTS transactions
    ALTER COLUMN amount TYPE double precision
    USING amount::double precision;

ALTER TABLE IF EXISTS entries
    ALTER COLUMN amount TYPE double precision
    USING amount::double precision;

COMMIT;

