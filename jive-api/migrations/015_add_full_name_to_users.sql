-- Migration: Add full_name column to users and backfill from name
-- Reason: API queries reference users.full_name; missing column caused 500 on /auth/login

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS full_name VARCHAR(100);

-- Backfill existing rows so API selections of full_name don't return NULL
UPDATE users
SET full_name = name
WHERE full_name IS NULL;

