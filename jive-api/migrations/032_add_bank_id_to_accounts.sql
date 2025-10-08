-- Add optional bank_id to accounts (nullable UUID, no FK constraint for now)
-- TODO: Add REFERENCES banks(id) constraint once banks table is created
ALTER TABLE accounts
ADD COLUMN IF NOT EXISTS bank_id UUID;

-- Helpful index
CREATE INDEX IF NOT EXISTS idx_accounts_bank_id ON accounts(bank_id);
