-- Add missing columns used by transactions handler
-- - recurring_rule: stores recurrence rule text
-- - category_name: denormalized category display name for stats
-- - payee: free-text payee name when no payee_id

ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS recurring_rule TEXT,
    ADD COLUMN IF NOT EXISTS category_name TEXT,
    ADD COLUMN IF NOT EXISTS payee TEXT;

-- No additional indexes required for these display fields.

