-- 021_extend_categories_for_user_features.sql
-- Extend categories table to support user-facing features aligned with design
-- Idempotent additions only

-- Add ordering/usage/source fields
ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS position INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(20), -- 'system' | 'custom'
    ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES system_category_templates(id),
    ADD COLUMN IF NOT EXISTS template_version VARCHAR(20),
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_position ON categories(position);
CREATE INDEX IF NOT EXISTS idx_categories_usage ON categories(usage_count);

-- Case-insensitive uniqueness per ledger for active categories
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='uq_categories_ledger_name_ci'
  ) THEN
    CREATE UNIQUE INDEX uq_categories_ledger_name_ci
      ON categories (ledger_id, LOWER(name))
      WHERE is_deleted = false;
  END IF;
END $$;

