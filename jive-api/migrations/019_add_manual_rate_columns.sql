-- Add manual rate support columns to exchange_rates and supporting constraints
-- - is_manual BOOLEAN NOT NULL DEFAULT false
-- - manual_rate_expiry TIMESTAMPTZ NULL (when set, manual rate valid until expiry)
-- - Trigger to keep updated_at fresh

-- 1) Columns for manual rate management
ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS is_manual BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS manual_rate_expiry TIMESTAMPTZ NULL;

-- 2) Create function for updating updated_at timestamp (idempotent)
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) Create trigger if it doesn't exist
DO $do$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tr_exchange_rates_set_updated_at'
        AND tgrelid = 'exchange_rates'::regclass
    ) THEN
        CREATE TRIGGER tr_exchange_rates_set_updated_at
        BEFORE UPDATE ON exchange_rates
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_timestamp();
    END IF;
END
$do$;
