-- Add payee_id column to transactions table
-- Note: payees.id is bigint, not uuid
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS payee_id BIGINT REFERENCES payees(id);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_transactions_payee_id ON transactions(payee_id);

-- Get family_id from a user's ledger
DO $$
DECLARE
    v_family_id UUID;
BEGIN
    -- Get a family_id from an existing ledger/user
    SELECT u.family_id INTO v_family_id
    FROM ledgers l
    JOIN users u ON l.user_id = u.id
    LIMIT 1;
    
    IF v_family_id IS NOT NULL THEN
        -- Migrate merchant data to payees
        -- This creates payees from existing merchant names if they don't exist
        INSERT INTO payees (name, family_id, created_at, updated_at)
        SELECT DISTINCT
            t.merchant,
            v_family_id,
            NOW(),
            NOW()
        FROM transactions t
        WHERE t.merchant IS NOT NULL 
            AND t.merchant != ''
            AND NOT EXISTS (
                SELECT 1 FROM payees p 
                WHERE p.name = t.merchant 
                AND p.family_id = v_family_id
            )
        ON CONFLICT (family_id, name) DO NOTHING;

        -- Update transactions to link to the newly created payees
        UPDATE transactions t
        SET payee_id = p.id
        FROM payees p
        WHERE t.merchant = p.name 
            AND p.family_id = v_family_id
            AND t.payee_id IS NULL;
    END IF;
END $$;