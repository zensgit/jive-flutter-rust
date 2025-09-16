-- 016_fix_families_member_count_and_superadmin.sql
-- Purpose:
--   1) Add families.member_count column used by services and backfill values
--   2) Ensure a unified superadmin account exists with a known Argon2 password
--
-- Notes:
--   - Chosen unified superadmin email: superadmin@jive.money
--   - Unified password: admin123 (Argon2id hash below)

-- 1) families.member_count column (idempotent)
ALTER TABLE families ADD COLUMN IF NOT EXISTS member_count INTEGER;

-- Backfill using current family_members count; ensure at least 1 for existing families
UPDATE families f
SET member_count = GREATEST(
  1,
  COALESCE((SELECT COUNT(*) FROM family_members fm WHERE fm.family_id = f.id), 0)
)
WHERE member_count IS NULL;

-- Set a sensible default for future inserts
ALTER TABLE families ALTER COLUMN member_count SET DEFAULT 1;

-- 2) Unified superadmin account (idempotent)
-- Use a stable UUID to avoid duplication across environments
-- Argon2id hash for password 'admin123'
--   From existing migration 006_update_superadmin_password.sql
--   $argon2id$v=19$m=19456,t=2,p=1$OkQ7dHUcv3u+5P4qsqqtOg$aowl63jBc1bawd1RNsORvSbbS+IqnHbjgpuFAoq8ehA

DO $$
BEGIN
  -- Ensure user row exists or is updated
  INSERT INTO users (id, email, password_hash, name, is_active, email_verified, created_at, updated_at)
  VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'superadmin@jive.money',
    '$argon2id$v=19$m=19456,t=2,p=1$OkQ7dHUcv3u+5P4qsqqtOg$aowl63jBc1bawd1RNsORvSbbS+IqnHbjgpuFAoq8ehA',
    'Super Admin',
    true,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    name = EXCLUDED.name,
    is_active = EXCLUDED.is_active,
    email_verified = EXCLUDED.email_verified,
    updated_at = NOW();

  -- If there is an old superadmin email, align its password too
  UPDATE users
    SET password_hash = '$argon2id$v=19$m=19456,t=2,p=1$OkQ7dHUcv3u+5P4qsqqtOg$aowl63jBc1bawd1RNsORvSbbS+IqnHbjgpuFAoq8ehA'
  WHERE email IN ('superadmin@jive.com', 'superadmin@jive.money');

  -- Ensure superadmin related family and membership exist (ids consistent with prior migrations)
  INSERT INTO families (id, name, owner_id, created_at, updated_at)
  VALUES (
    '650e8400-e29b-41d4-a716-446655440000',
    'Admin Family',
    '550e8400-e29b-41d4-a716-446655440000',
    NOW(), NOW()
  ) ON CONFLICT DO NOTHING;

  INSERT INTO family_members (family_id, user_id, role)
  VALUES ('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 'owner')
  ON CONFLICT DO NOTHING;

  INSERT INTO ledgers (id, family_id, name, is_default, created_by, created_at, updated_at)
  VALUES (
    '750e8400-e29b-41d4-a716-446655440000',
    '650e8400-e29b-41d4-a716-446655440000',
    'Admin Ledger',
    true,
    '550e8400-e29b-41d4-a716-446655440000',
    NOW(), NOW()
  ) ON CONFLICT DO NOTHING;
END $$;

