-- Create payees table that was referenced but never created
-- This table stores payee information for transactions

-- Create payees table
CREATE TABLE IF NOT EXISTS payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    default_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Ensure unique payee names within a family
    CONSTRAINT unique_payee_name_per_family UNIQUE(family_id, name)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_payees_family_id ON payees(family_id);
CREATE INDEX IF NOT EXISTS idx_payees_name ON payees(name);
CREATE INDEX IF NOT EXISTS idx_payees_category_id ON payees(category_id);
CREATE INDEX IF NOT EXISTS idx_payees_is_active ON payees(is_active);
CREATE INDEX IF NOT EXISTS idx_payees_created_at ON payees(created_at DESC);

-- Add foreign key constraint to transactions table (was TODO in migration 013)
ALTER TABLE transactions
DROP CONSTRAINT IF EXISTS transactions_payee_id_fkey;

ALTER TABLE transactions
ADD CONSTRAINT transactions_payee_id_fkey
FOREIGN KEY (payee_id)
REFERENCES payees(id)
ON DELETE SET NULL;

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_payees_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_payees_updated_at ON payees;
CREATE TRIGGER update_payees_updated_at
    BEFORE UPDATE ON payees
    FOR EACH ROW
    EXECUTE FUNCTION update_payees_updated_at();

-- Add some common system payees for each family (optional, can be customized)
-- These will be created via application logic when a new family is created
COMMENT ON TABLE payees IS 'Stores payee information for transaction tracking';
COMMENT ON COLUMN payees.family_id IS 'Family this payee belongs to';
COMMENT ON COLUMN payees.name IS 'Payee name (unique within family)';
COMMENT ON COLUMN payees.category_id IS 'Default category for this payee';
COMMENT ON COLUMN payees.default_account_id IS 'Default account for transactions with this payee';
COMMENT ON COLUMN payees.metadata IS 'Additional payee information in JSON format';