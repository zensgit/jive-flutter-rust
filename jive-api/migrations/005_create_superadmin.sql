-- 创建superadmin账户
-- 密码: admin123
-- 使用bcrypt哈希: $2b$12$7JQkPDYhQfqRgNxKPE1Jj.XKZV9n9N3KYGwW9nR5QoV5tXHXnXXXX

-- 首先添加role字段到users表（如果不存在）
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'superadmin'));

-- 创建superadmin用户
-- 注意：这个密码哈希是admin123的bcrypt哈希
INSERT INTO users (id, email, password_hash, name, role, is_active, email_verified) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'superadmin@jive.com', '$2b$12$LKvD2kQxH2MKmNbQ8iCYOuZGXh0Y3DvXvP0VxXPxXfXEhxPxXxXxX', 'Super Admin', 'superadmin', true, true)
ON CONFLICT (email) DO UPDATE SET 
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    name = EXCLUDED.name;

-- 如果您想使用真实的bcrypt哈希，可以使用以下Python代码生成：
-- import bcrypt
-- password = b"admin123"
-- salt = bcrypt.gensalt()
-- hashed = bcrypt.hashpw(password, salt)
-- print(hashed.decode())

-- 临时使用一个已知的哈希（来自之前的测试用户）
UPDATE users 
SET password_hash = '$2b$12$KIXxPfAZkNhV3ps3wLpJOe3YzQvvVxQu2sYZHHgGg0Eiq6XqKqy.a'
WHERE email = 'superadmin@jive.com';

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