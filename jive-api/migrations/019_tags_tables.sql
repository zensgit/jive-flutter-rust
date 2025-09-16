-- 019_tags_tables.sql
-- Create tag_groups and tags tables for unified tag management

CREATE TABLE IF NOT EXISTS tag_groups (
    id UUID PRIMARY KEY,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    color VARCHAR(16),
    icon VARCHAR(32),
    archived BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Unique per family (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS uq_tag_groups_family_name_ci
    ON tag_groups (family_id, LOWER(name));

CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY,
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    group_id UUID REFERENCES tag_groups(id) ON DELETE SET NULL,
    name VARCHAR(64) NOT NULL,
    color VARCHAR(16),
    icon VARCHAR(32),
    archived BOOLEAN DEFAULT false,
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Unique per family (case-insensitive)
-- Only create this index if the tags table has family_id column
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='tags' AND column_name='family_id'
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS uq_tags_family_name_ci
            ON tags (family_id, LOWER(name));
    END IF;
END$$;

-- ETag-friendly updated_at trigger
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
        CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW;
        END; $func$ LANGUAGE plpgsql;
    END IF;
END$$;

DO $$
BEGIN
    CREATE TRIGGER trg_tag_groups_updated_at
        BEFORE UPDATE ON tag_groups
        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END$$;

DO $$
BEGIN
    CREATE TRIGGER trg_tags_updated_at
        BEFORE UPDATE ON tags
        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END$$;

-- Ensure legacy ledger-based tags table has updated_at for ETag support
ALTER TABLE tags
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
