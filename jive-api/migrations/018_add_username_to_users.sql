-- 018_add_username_to_users.sql
-- Add optional username column with case-insensitive uniqueness

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'users'
          AND column_name = 'username'
    ) THEN
        ALTER TABLE users
            ADD COLUMN username VARCHAR(100);
    END IF;
END $$;

-- Case-insensitive unique constraint via partial unique index
-- Note: WHERE username IS NOT NULL to allow NULLs for users without username
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username_ci
    ON users (LOWER(username))
    WHERE username IS NOT NULL;

-- Helpful index for email lookups (if not already present)
CREATE INDEX IF NOT EXISTS idx_users_email_ci
    ON users (LOWER(email));

