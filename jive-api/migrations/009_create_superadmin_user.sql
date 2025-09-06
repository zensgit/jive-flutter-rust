-- 创建superadmin账户
-- 密码: SuperAdmin@123
INSERT INTO users (id, email, password_hash, name, role, is_active, email_verified) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'superadmin@jive.money', '$argon2id$v=19$m=19456,t=2,p=1$VnRaV3dqQ3I5emZLc0tXSQ$B5q+BXWvBzVNFLCCPfyqxqhYf2Kx0Mmdz4HDUX9+KMI', 'Super Admin', 'superadmin', true, true)
ON CONFLICT (id) DO UPDATE SET 
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    name = EXCLUDED.name;

-- 创建superadmin的家庭和账本
INSERT INTO families (id, name, owner_id) VALUES
('650e8400-e29b-41d4-a716-446655440000', 'Admin Family', '550e8400-e29b-41d4-a716-446655440000')
ON CONFLICT DO NOTHING;

INSERT INTO family_members (family_id, user_id, role) VALUES
('650e8400-e29b-41d4-a716-446655440000', '550e8400-e29b-41d4-a716-446655440000', 'owner')
ON CONFLICT DO NOTHING;

INSERT INTO ledgers (id, family_id, name, is_default, created_by) VALUES
('750e8400-e29b-41d4-a716-446655440000', '650e8400-e29b-41d4-a716-446655440000', 'Admin Ledger', true, '550e8400-e29b-41d4-a716-446655440000')
ON CONFLICT DO NOTHING;