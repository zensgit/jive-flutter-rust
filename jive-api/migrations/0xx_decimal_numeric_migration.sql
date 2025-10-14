-- Decimal numeric migration with balance verification and audit
BEGIN;

-- Step 1: type conversions (adjust table/column names as needed)
ALTER TABLE IF EXISTS accounts ALTER COLUMN current_balance TYPE numeric(20,6) USING ROUND(current_balance::numeric, 6);
ALTER TABLE IF EXISTS transactions ALTER COLUMN amount TYPE numeric(20,6) USING ROUND(amount::numeric, 6);
ALTER TABLE IF EXISTS entries ALTER COLUMN amount TYPE numeric(20,6) USING ROUND(amount::numeric, 6);

-- Step 1.1: audit table
CREATE TABLE IF NOT EXISTS transaction_migration_audit (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL,
    operation VARCHAR(50) NOT NULL,
    old_value JSONB,
    new_value JSONB,
    difference JSONB,
    migration_version VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100) DEFAULT 'system'
);

-- Step 2: forced balance verification and correction
DO $$
DECLARE
    v_account RECORD;
    v_calculated_balance numeric(20,6);
    v_stored_balance numeric(20,6);
    v_diff numeric(20,6);
    v_error_count int := 0;
BEGIN
    FOR v_account IN
        SELECT id, current_balance FROM accounts WHERE deleted_at IS NULL OR deleted_at IS NULL
    LOOP
        SELECT COALESCE(SUM(CASE WHEN nature = 'inflow' THEN amount ELSE -amount END), 0)
        INTO v_calculated_balance
        FROM entries
        WHERE account_id = v_account.id AND (deleted_at IS NULL);

        v_stored_balance := v_account.current_balance;
        v_diff := ABS(v_calculated_balance - v_stored_balance);

        IF v_diff > 0.01 THEN
            -- audit
            INSERT INTO transaction_migration_audit (
                account_id, operation, old_value, new_value, difference, migration_version
            ) VALUES (
                v_account.id,
                'balance_correction',
                jsonb_build_object('balance', v_stored_balance, 'type', 'f64'),
                jsonb_build_object('balance', v_calculated_balance, 'type', 'Decimal'),
                jsonb_build_object('diff', v_diff),
                '0xx_decimal_migration'
            );

            UPDATE accounts
            SET current_balance = v_calculated_balance,
                updated_at = NOW()
            WHERE id = v_account.id;
            v_error_count := v_error_count + 1;
        END IF;
    END LOOP;

    IF v_error_count > 0 THEN
        RAISE NOTICE 'Fixed % accounts with balance mismatches', v_error_count;
    END IF;
END $$;

-- Optional: balance maintenance trigger (disabled by default)
-- CREATE OR REPLACE FUNCTION maintain_account_balance() RETURNS TRIGGER AS $$
-- BEGIN
--   IF TG_OP = 'INSERT' THEN
--     UPDATE accounts SET current_balance = current_balance + (CASE WHEN NEW.nature = 'inflow' THEN NEW.amount ELSE -NEW.amount END)
--     WHERE id = NEW.account_id;
--   ELSIF TG_OP = 'DELETE' THEN
--     UPDATE accounts SET current_balance = current_balance - (CASE WHEN OLD.nature = 'inflow' THEN OLD.amount ELSE -OLD.amount END)
--     WHERE id = OLD.account_id;
--   ELSIF TG_OP = 'UPDATE' THEN
--     UPDATE accounts SET current_balance = current_balance
--       - (CASE WHEN OLD.nature = 'inflow' THEN OLD.amount ELSE -OLD.amount END)
--       + (CASE WHEN NEW.nature = 'inflow' THEN NEW.amount ELSE -NEW.amount END)
--     WHERE id = NEW.account_id;
--   END IF;
--   RETURN NULL;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE TRIGGER trg_maintain_account_balance
-- AFTER INSERT OR UPDATE OR DELETE ON entries
-- FOR EACH ROW EXECUTE FUNCTION maintain_account_balance();

COMMIT;

