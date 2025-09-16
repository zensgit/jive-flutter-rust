-- 插入测试数据

-- 1. 创建测试用户
INSERT INTO users (id, email, password_hash, name) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'test@example.com', '$2b$12$KIXxPfAZkNhV3ps3wLpJOe3YzQvvVxQu2sYZHHgGg0Eiq6XqKqy.a', 'Test User'),
('550e8400-e29b-41d4-a716-446655440002', 'admin@example.com', '$2b$12$KIXxPfAZkNhV3ps3wLpJOe3YzQvvVxQu2sYZHHgGg0Eiq6XqKqy.a', 'Admin User')
ON CONFLICT DO NOTHING;

-- 2. 创建测试家庭
INSERT INTO families (id, name, owner_id) VALUES
('650e8400-e29b-41d4-a716-446655440001', 'Test Family', '550e8400-e29b-41d4-a716-446655440001')
ON CONFLICT DO NOTHING;

-- 3. 添加家庭成员
INSERT INTO family_members (family_id, user_id, role) VALUES
('650e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'owner'),
('650e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002', 'member')
ON CONFLICT DO NOTHING;

-- 4. 创建默认账本
INSERT INTO ledgers (id, family_id, name, is_default, created_by) VALUES
('750e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440001', 'Default Ledger', true, '550e8400-e29b-41d4-a716-446655440001')
ON CONFLICT DO NOTHING;

-- 5. 创建测试账户
INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_by) VALUES
('850e8400-e29b-41d4-a716-446655440001', '750e8400-e29b-41d4-a716-446655440001', '现金钱包', 'cash', 1000.00, '550e8400-e29b-41d4-a716-446655440001'),
('850e8400-e29b-41d4-a716-446655440002', '750e8400-e29b-41d4-a716-446655440001', '招商银行', 'debit', 50000.00, '550e8400-e29b-41d4-a716-446655440001'),
('850e8400-e29b-41d4-a716-446655440003', '750e8400-e29b-41d4-a716-446655440001', '信用卡', 'credit', -2000.00, '550e8400-e29b-41d4-a716-446655440001')
ON CONFLICT DO NOTHING;

-- 6. 创建测试分类
INSERT INTO categories (id, ledger_id, name, icon, color, type, created_by) VALUES
('950e8400-e29b-41d4-a716-446655440001', '750e8400-e29b-41d4-a716-446655440001', '餐饮', 'restaurant', '#FF6B6B', 'expense', '550e8400-e29b-41d4-a716-446655440001'),
('950e8400-e29b-41d4-a716-446655440002', '750e8400-e29b-41d4-a716-446655440001', '交通', 'directions_car', '#4ECDC4', 'expense', '550e8400-e29b-41d4-a716-446655440001'),
('950e8400-e29b-41d4-a716-446655440003', '750e8400-e29b-41d4-a716-446655440001', '工资', 'account_balance_wallet', '#66BB6A', 'income', '550e8400-e29b-41d4-a716-446655440001')
ON CONFLICT DO NOTHING;

-- 7. 创建测试交易
INSERT INTO transactions (ledger_id, transaction_type, amount, category_id, account_id, transaction_date, description, created_by) VALUES
('750e8400-e29b-41d4-a716-446655440001', 'expense', 85.00, '950e8400-e29b-41d4-a716-446655440001', '850e8400-e29b-41d4-a716-446655440001', CURRENT_DATE, '午餐', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440001', 'expense', 50.00, '950e8400-e29b-41d4-a716-446655440002', '850e8400-e29b-41d4-a716-446655440002', CURRENT_DATE - 1, '打车', '550e8400-e29b-41d4-a716-446655440001'),
('750e8400-e29b-41d4-a716-446655440001', 'income', 15000.00, '950e8400-e29b-41d4-a716-446655440003', '850e8400-e29b-41d4-a716-446655440002', CURRENT_DATE - 5, '月薪', '550e8400-e29b-41d4-a716-446655440001')
ON CONFLICT DO NOTHING;