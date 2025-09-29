-- Add optional bank_id to accounts referencing banks(id)
ALTER TABLE accounts
ADD COLUMN IF NOT EXISTS bank_id UUID REFERENCES banks(id);

-- Helpful index
CREATE INDEX IF NOT EXISTS idx_accounts_bank_id ON accounts(bank_id);
