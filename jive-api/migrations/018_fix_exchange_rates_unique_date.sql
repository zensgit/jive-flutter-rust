-- Fix exchange_rates schema to align with service upsert logic
-- Goal:
--  - Ensure a business date column (date DATE NOT NULL)
--  - Ensure unique key on (from_currency, to_currency, date)
--  - Keep idempotent and safe for existing data

BEGIN;

-- 1) Ensure date column exists
ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS date DATE;

-- 2) Backfill date from effective_date when missing
UPDATE exchange_rates
SET date = COALESCE(date, effective_date, CURRENT_DATE)
WHERE date IS NULL;

-- 3) Enforce NOT NULL on date (only after backfill)
ALTER TABLE exchange_rates
    ALTER COLUMN date SET NOT NULL;

-- 4) Ensure effective_date exists and not null (older installs might miss it)
ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS effective_date DATE;

UPDATE exchange_rates
SET effective_date = COALESCE(effective_date, date)
WHERE effective_date IS NULL;

ALTER TABLE exchange_rates
    ALTER COLUMN effective_date SET NOT NULL;

-- 5) Ensure created_at/updated_at exist with defaults (no-op if already present)
ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- Keep defaults stable if they already exist
ALTER TABLE exchange_rates
    ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE exchange_rates
    ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;

-- 6) Add unique index to enforce one rate per pair per day
CREATE UNIQUE INDEX IF NOT EXISTS ux_exchange_rates_from_to_date
    ON exchange_rates (from_currency, to_currency, date);

COMMIT;

