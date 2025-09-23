-- Migration: Add composite index for frequent today lookups
-- Purpose: speed queries on (from_currency, to_currency, date) and recent updates

DO $$
BEGIN
    -- Create composite btree index (supports equality on first 3 columns and order by updated_at DESC)
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE schemaname = current_schema() 
          AND indexname = 'idx_exchange_rates_from_to_date_updated_at'
    ) THEN
        CREATE INDEX idx_exchange_rates_from_to_date_updated_at
        ON exchange_rates (from_currency, to_currency, date, updated_at DESC);
    END IF;
END $$;

