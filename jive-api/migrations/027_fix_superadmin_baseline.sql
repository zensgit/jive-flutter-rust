-- 027_fix_superadmin_baseline.sql
-- Purpose: Normalize superadmin baseline so login and permissions behave consistently.
-- - Ensure canonical email/username/full_name
-- - Ensure family, membership, current_family_id, and default ledger exist
-- - Keep password_hash as Argon2 known value (idempotent)

-- Canonical IDs used across seeds
DO $$
DECLARE
  v_user_id   UUID := '550e8400-e29b-41d4-a716-446655440000';
  v_family_id UUID := '650e8400-e29b-41d4-a716-446655440000';
  v_ledger_id UUID := '750e8400-e29b-41d4-a716-446655440000';
  v_email     TEXT := 'superadmin@jive.money';
  v_name      TEXT := 'Super Admin';
  v_hash      TEXT := '$argon2id$v=19$m=19456,t=2,p=1$VnRaV3dqQ3I5emZLc0tXSQ$B5q+BXWvBzVNFLCCPfyqxqhYf2Kx0Mmdz4HDUX9+KMI';
BEGIN
  -- Ensure user exists and normalize fields
  INSERT INTO users (id, email, username, full_name, name, password_hash, is_active, email_verified, created_at, updated_at)
  VALUES (v_user_id, v_email, 'superadmin', v_name, v_name, v_hash, true, true, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = 'superadmin',
    full_name = COALESCE(users.full_name, EXCLUDED.full_name),
    name = COALESCE(users.name, EXCLUDED.name),
    password_hash = EXCLUDED.password_hash,
    is_active = true,
    email_verified = true,
    updated_at = NOW();

  -- Ensure family exists with owner_id and baseline fields
  INSERT INTO families (id, name, owner_id, currency, timezone, locale, invite_code, created_at, updated_at)
  VALUES (v_family_id, 'Admin Family', v_user_id, 'CNY', 'Asia/Shanghai', 'zh-CN', 'ADM1NFAM', NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    owner_id = v_user_id,
    name = 'Admin Family',
    updated_at = NOW();

  -- Ensure membership (owner)
  INSERT INTO family_members (family_id, user_id, role, joined_at)
  VALUES (v_family_id, v_user_id, 'owner', NOW())
  ON CONFLICT (family_id, user_id) DO UPDATE SET
    role = 'owner';

  -- Ensure current_family_id set on user
  UPDATE users SET current_family_id = v_family_id, updated_at = NOW()
  WHERE id = v_user_id AND (current_family_id IS NULL OR current_family_id <> v_family_id);

  -- Ensure default ledger exists
  INSERT INTO ledgers (id, family_id, name, currency, created_by, is_default, is_active, created_at, updated_at)
  VALUES (v_ledger_id, v_family_id, 'Admin Ledger', 'CNY', v_user_id, true, true, NOW(), NOW())
  ON CONFLICT (id) DO NOTHING;
END $$;

