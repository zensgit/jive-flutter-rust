-- 020_adjust_templates_schema.sql
-- Align system_category_templates schema with API expectations used by template_handler.rs
-- Idempotent: safe to re-run

-- 1) Add missing columns if not present
ALTER TABLE system_category_templates
    ADD COLUMN IF NOT EXISTS classification VARCHAR(20),
    ADD COLUMN IF NOT EXISTS category_group VARCHAR(50),
    ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS global_usage_count INTEGER DEFAULT 0;

-- name_zh is referenced by API; ensure column exists and backfill
ALTER TABLE system_category_templates
    ADD COLUMN IF NOT EXISTS name_zh VARCHAR(100);

UPDATE system_category_templates
SET name_zh = COALESCE(name_zh, name)
WHERE name_zh IS NULL;

-- 2) Backfill classification from legacy `type` column when missing
UPDATE system_category_templates
SET classification = CASE
    WHEN lower(type) IN ('expense','income','transfer') THEN lower(type)
    ELSE 'expense'
END
WHERE classification IS NULL;

-- 3) Set sensible defaults
UPDATE system_category_templates
SET category_group = COALESCE(category_group, 'general')
WHERE category_group IS NULL;

UPDATE system_category_templates
SET global_usage_count = COALESCE(global_usage_count, 0)
WHERE global_usage_count IS NULL;

-- 4) If legacy usage_count exists, prefer it to initialize global_usage_count
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'system_category_templates' AND column_name = 'usage_count'
  ) THEN
    UPDATE system_category_templates
    SET global_usage_count = COALESCE(global_usage_count, usage_count)
    WHERE global_usage_count IS NULL OR global_usage_count = 0;
  END IF;
END $$;

-- 5) Ensure `version` is VARCHAR(20) as expected by API
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'system_category_templates' AND column_name = 'version' AND data_type <> 'character varying'
  ) THEN
    ALTER TABLE system_category_templates
      ALTER COLUMN version TYPE VARCHAR(20) USING version::text;
  END IF;
END $$;

-- Default version if missing
UPDATE system_category_templates
SET version = COALESCE(NULLIF(version, ''), '1.0.0');

-- 6) Helpful indexes for filtering
CREATE INDEX IF NOT EXISTS idx_sct_group ON system_category_templates(category_group);
CREATE INDEX IF NOT EXISTS idx_sct_classification ON system_category_templates(classification);
CREATE INDEX IF NOT EXISTS idx_sct_featured ON system_category_templates(is_featured);

