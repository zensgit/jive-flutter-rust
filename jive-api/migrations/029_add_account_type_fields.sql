-- Migration: Add account type classification fields
-- Date: 2025-09-28
-- Description: Add account_main_type and account_sub_type fields to support dual-layer account classification

-- Add new columns
ALTER TABLE accounts
ADD COLUMN account_main_type VARCHAR(20),
ADD COLUMN account_sub_type VARCHAR(30);

-- Create enum-like constraints
ALTER TABLE accounts
ADD CONSTRAINT check_account_main_type
  CHECK (account_main_type IN ('asset', 'liability'));

ALTER TABLE accounts
ADD CONSTRAINT check_account_sub_type
  CHECK (account_sub_type IN (
    'cash',
    'debit_card',
    'savings_account',
    'checking',
    'investment',
    'prepaid_card',
    'digital_wallet',
    'credit_card',
    'loan',
    'mortgage'
  ));

-- Migrate existing data based on account_type
UPDATE accounts
SET
  account_main_type = CASE
    WHEN account_type IN ('credit_card', 'loan', 'creditCard') THEN 'liability'
    ELSE 'asset'
  END,
  account_sub_type = CASE
    WHEN account_type = 'cash' THEN 'cash'
    WHEN account_type = 'debit' THEN 'debit_card'
    WHEN account_type = 'credit' OR account_type = 'creditCard' OR account_type = 'credit_card' THEN 'credit_card'
    WHEN account_type = 'savings' THEN 'savings_account'
    WHEN account_type = 'checking' THEN 'checking'
    WHEN account_type = 'investment' THEN 'investment'
    WHEN account_type = 'loan' THEN 'loan'
    WHEN account_type = 'other' THEN 'cash'
    ELSE 'cash'
  END
WHERE account_main_type IS NULL;

-- Add NOT NULL constraints after data migration
ALTER TABLE accounts
ALTER COLUMN account_main_type SET NOT NULL,
ALTER COLUMN account_sub_type SET NOT NULL;

-- Add indexes for common queries
CREATE INDEX idx_accounts_main_type ON accounts(account_main_type);
CREATE INDEX idx_accounts_sub_type ON accounts(account_sub_type);
CREATE INDEX idx_accounts_type_combo ON accounts(account_main_type, account_sub_type);

-- Add comment for documentation
COMMENT ON COLUMN accounts.account_main_type IS 'Main account classification: asset or liability';
COMMENT ON COLUMN accounts.account_sub_type IS 'Detailed account sub-type: cash, debit_card, savings_account, checking, investment, prepaid_card, digital_wallet, credit_card, loan, mortgage';