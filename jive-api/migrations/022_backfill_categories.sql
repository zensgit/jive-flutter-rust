-- 022_backfill_categories.sql
-- Backfill categories ordering/usage/source fields safely and idempotently

-- Ensure defaults where NULL
UPDATE categories
SET usage_count = 0
WHERE usage_count IS NULL;

UPDATE categories
SET is_deleted = COALESCE(is_deleted, false)
WHERE is_deleted IS NULL;

UPDATE categories
SET source_type = COALESCE(source_type, 'custom')
WHERE source_type IS NULL;

-- If a template_id exists but template_version is NULL or empty, set a default
UPDATE categories
SET template_version = '1.0.0'
WHERE template_id IS NOT NULL AND (template_version IS NULL OR template_version = '');

-- Backfill dense positions per (ledger_id, parent_id)
-- Use a stable order: existing position first, then created_at, then name
WITH ranked AS (
  SELECT c.id,
         ROW_NUMBER() OVER (
           PARTITION BY c.ledger_id, c.parent_id
           ORDER BY c.position NULLS LAST, c.created_at NULLS LAST, LOWER(c.name)
         ) - 1 AS new_pos
  FROM categories c
  WHERE c.is_deleted = false
)
UPDATE categories AS c
SET position = r.new_pos
FROM ranked r
WHERE c.id = r.id AND COALESCE(c.position, -1) <> r.new_pos;

-- Helpful composite index for list queries
CREATE INDEX IF NOT EXISTS idx_categories_ledger_parent_position
  ON categories(ledger_id, parent_id, position);

