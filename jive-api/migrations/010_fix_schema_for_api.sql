-- Migration to fix schema for API compatibility

-- 1. Add ledger_id to accounts table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'ledger_id') THEN
        ALTER TABLE accounts ADD COLUMN ledger_id UUID;
        ALTER TABLE accounts ADD CONSTRAINT accounts_ledger_id_fkey 
            FOREIGN KEY (ledger_id) REFERENCES ledgers(id) ON DELETE CASCADE;
        CREATE INDEX idx_accounts_ledger ON accounts(ledger_id);
    END IF;
END $$;

-- 2. Add missing columns to accounts table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'account_type') THEN
        ALTER TABLE accounts ADD COLUMN account_type VARCHAR(50) DEFAULT 'checking';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'account_number') THEN
        ALTER TABLE accounts ADD COLUMN account_number VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'institution_name') THEN
        ALTER TABLE accounts ADD COLUMN institution_name VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'current_balance') THEN
        ALTER TABLE accounts ADD COLUMN current_balance NUMERIC(19,4) DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'available_balance') THEN
        ALTER TABLE accounts ADD COLUMN available_balance NUMERIC(19,4) DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'credit_limit') THEN
        ALTER TABLE accounts ADD COLUMN credit_limit NUMERIC(19,4);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'opening_balance') THEN
        ALTER TABLE accounts ADD COLUMN opening_balance NUMERIC(19,4) DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'opening_date') THEN
        ALTER TABLE accounts ADD COLUMN opening_date DATE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'interest_rate') THEN
        ALTER TABLE accounts ADD COLUMN interest_rate NUMERIC(5,4);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'notes') THEN
        ALTER TABLE accounts ADD COLUMN notes TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'is_archived') THEN
        ALTER TABLE accounts ADD COLUMN is_archived BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'sort_order') THEN
        ALTER TABLE accounts ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'accounts' AND column_name = 'deleted_at') THEN
        ALTER TABLE accounts ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- 3. Update ledgers table - make family_id nullable for personal ledgers (guarded)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'ledgers' AND column_name = 'family_id'
    ) THEN
        ALTER TABLE ledgers ALTER COLUMN family_id DROP NOT NULL;
    END IF;
END $$;

-- 4. Create default ledger for admin user if not exists
DO $$
DECLARE
    admin_user_id UUID;
    default_ledger_id UUID;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_user_id FROM users WHERE email = 'admin' LIMIT 1;
    
    IF admin_user_id IS NOT NULL THEN
        -- Check if admin has a default ledger
        SELECT l.id INTO default_ledger_id 
        FROM ledgers l
        WHERE l.created_by = admin_user_id AND l.is_default = true
        LIMIT 1;
        
        IF default_ledger_id IS NULL THEN
            -- Create default ledger for admin
            INSERT INTO ledgers (family_id, name, description, currency, is_default, created_by)
            VALUES (NULL, '默认账本', '管理员默认账本', 'CNY', true, admin_user_id);
        END IF;
    END IF;
END $$;

-- 5. Update existing accounts to link with default ledger if ledger_id is null
-- 5. Backfill accounts.ledger_id using family_id when column exists (guarded)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'accounts' AND column_name = 'family_id'
    ) THEN
        UPDATE accounts a
        SET ledger_id = (
            SELECT l.id FROM ledgers l
            WHERE l.family_id = a.family_id OR (l.family_id IS NULL AND a.family_id IS NULL)
            ORDER BY l.is_default DESC, l.created_at ASC
            LIMIT 1
        )
        WHERE a.ledger_id IS NULL;
    END IF;
END $$;

-- 6. Set default values for new columns based on existing data
-- 6a. Backfill account_type when source column exists (guarded)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accounts' AND column_name = 'subtype'
    ) THEN
        UPDATE accounts
        SET account_type = CASE
            WHEN subtype LIKE '%credit%' THEN 'credit_card'
            WHEN subtype LIKE '%saving%' THEN 'savings'
            WHEN subtype LIKE '%invest%' THEN 'investment'
            ELSE 'checking'
        END
        WHERE account_type IS NULL;
    END IF;
END $$;

-- 6b. Backfill current_balance from legacy balance when column exists (guarded)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accounts' AND column_name = 'balance'
    ) THEN
        UPDATE accounts
        SET current_balance = COALESCE(balance, 0)
        WHERE current_balance IS NULL;
    END IF;
END $$;

-- 6c. Backfill available_balance from legacy cash_balance when column exists (guarded)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accounts' AND column_name = 'cash_balance'
    ) THEN
        UPDATE accounts
        SET available_balance = COALESCE(cash_balance, current_balance, 0)
        WHERE available_balance IS NULL;
    END IF;
END $$;
