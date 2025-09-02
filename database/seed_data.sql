-- 清理现有测试数据
TRUNCATE TABLE rule_matches CASCADE;
TRUNCATE TABLE rules CASCADE;
TRUNCATE TABLE transactions CASCADE;
TRUNCATE TABLE payees CASCADE;
TRUNCATE TABLE categories CASCADE;
TRUNCATE TABLE account_balances CASCADE;
TRUNCATE TABLE accounts CASCADE;
TRUNCATE TABLE ledgers CASCADE;

-- 创建测试账本
INSERT INTO ledgers (id, name, description, currency) VALUES
('550e8400-e29b-41d4-a716-446655440001', '个人账本', '个人日常收支管理', 'CNY'),
('550e8400-e29b-41d4-a716-446655440002', '家庭账本', '家庭共同开支', 'CNY');

-- 创建分类
INSERT INTO categories (id, ledger_id, name, type, parent_id, icon, color) VALUES
-- 支出分类
('770e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '餐饮', 'expense', NULL, '🍽️', '#FF6B6B'),
('770e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '交通', 'expense', NULL, '🚗', '#4ECDC4'),
('770e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', '购物', 'expense', NULL, '🛒', '#45B7D1'),
('770e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440001', '娱乐', 'expense', NULL, '🎮', '#96CEB4'),
('770e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440001', '住房', 'expense', NULL, '🏠', '#FFEAA7'),
('770e8400-e29b-41d4-a716-446655440006', '550e8400-e29b-41d4-a716-446655440001', '医疗', 'expense', NULL, '🏥', '#DFE6E9'),
-- 收入分类
('770e8400-e29b-41d4-a716-446655440011', '550e8400-e29b-41d4-a716-446655440001', '工资', 'income', NULL, '💰', '#00B894'),
('770e8400-e29b-41d4-a716-446655440012', '550e8400-e29b-41d4-a716-446655440001', '奖金', 'income', NULL, '🎁', '#FDCB6E'),
('770e8400-e29b-41d4-a716-446655440013', '550e8400-e29b-41d4-a716-446655440001', '投资收益', 'income', NULL, '📈', '#6C5CE7'),
('770e8400-e29b-41d4-a716-446655440014', '550e8400-e29b-41d4-a716-446655440001', '兼职', 'income', NULL, '💼', '#A29BFE');

-- 创建账户
INSERT INTO accounts (id, ledger_id, name, account_type, account_number, institution_name, currency, current_balance, status, is_manual) VALUES
('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '工商银行储蓄卡', 'checking', '6222****1234', '中国工商银行', 'CNY', 50000.00, 'active', true),
('660e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '支付宝', 'checking', 'alipay@example.com', '支付宝', 'CNY', 10000.00, 'active', true),
('660e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', '微信钱包', 'checking', 'wechat_wallet', '微信支付', 'CNY', 5000.00, 'active', true),
('660e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440001', '招商银行信用卡', 'credit_card', '6225****5678', '招商银行', 'CNY', -3500.00, 'active', true),
('660e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440001', '现金', 'cash', NULL, NULL, 'CNY', 2000.00, 'active', true);

-- 创建收款人
INSERT INTO payees (id, ledger_id, name, default_category_id, is_vendor, is_customer, is_active) VALUES
-- 餐饮类
('880e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '星巴克', '770e8400-e29b-41d4-a716-446655440001', true, false, true),
('880e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '麦当劳', '770e8400-e29b-41d4-a716-446655440001', true, false, true),
('880e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', '海底捞', '770e8400-e29b-41d4-a716-446655440001', true, false, true),
-- 交通类
('880e8400-e29b-41d4-a716-446655440011', '550e8400-e29b-41d4-a716-446655440001', '滴滴出行', '770e8400-e29b-41d4-a716-446655440002', true, false, true),
('880e8400-e29b-41d4-a716-446655440012', '550e8400-e29b-41d4-a716-446655440001', '中石化', '770e8400-e29b-41d4-a716-446655440002', true, false, true),
('880e8400-e29b-41d4-a716-446655440013', '550e8400-e29b-41d4-a716-446655440001', '地铁公司', '770e8400-e29b-41d4-a716-446655440002', true, false, true),
-- 购物类
('880e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440001', '京东', '770e8400-e29b-41d4-a716-446655440003', true, false, true),
('880e8400-e29b-41d4-a716-446655440022', '550e8400-e29b-41d4-a716-446655440001', '淘宝', '770e8400-e29b-41d4-a716-446655440003', true, false, true),
('880e8400-e29b-41d4-a716-446655440023', '550e8400-e29b-41d4-a716-446655440001', '盒马鲜生', '770e8400-e29b-41d4-a716-446655440003', true, false, true),
-- 收入来源
('880e8400-e29b-41d4-a716-446655440031', '550e8400-e29b-41d4-a716-446655440001', '公司', '770e8400-e29b-41d4-a716-446655440011', false, true, true),
('880e8400-e29b-41d4-a716-446655440032', '550e8400-e29b-41d4-a716-446655440001', '股票账户', '770e8400-e29b-41d4-a716-446655440013', false, true, true);

-- 创建交易记录（最近30天）
INSERT INTO transactions (
    id, ledger_id, account_id, transaction_date, amount, transaction_type,
    category_id, category_name, payee, notes, status
) VALUES
-- 工资收入
('990e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 
 CURRENT_DATE - INTERVAL '25 days', 15000.00, 'income', 
 '770e8400-e29b-41d4-a716-446655440011', '工资', '公司', '9月工资', 'cleared'),

-- 日常支出
('990e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440002', 
 CURRENT_DATE - INTERVAL '20 days', 45.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440001', '餐饮', '星巴克', '拿铁咖啡', 'cleared'),

('990e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440003', 
 CURRENT_DATE - INTERVAL '18 days', 68.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440001', '餐饮', '麦当劳', '午餐', 'cleared'),

('990e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440002', 
 CURRENT_DATE - INTERVAL '15 days', 156.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440002', '交通', '滴滴出行', '机场接送', 'cleared'),

('990e8400-e29b-41d4-a716-446655440005', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440004', 
 CURRENT_DATE - INTERVAL '14 days', 1299.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440003', '购物', '京东', 'iPhone手机壳', 'cleared'),

('990e8400-e29b-41d4-a716-446655440006', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 
 CURRENT_DATE - INTERVAL '10 days', 458.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440001', '餐饮', '海底捞', '朋友聚餐', 'cleared'),

('990e8400-e29b-41d4-a716-446655440007', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440002', 
 CURRENT_DATE - INTERVAL '8 days', 200.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440002', '交通', '中石化', '加油', 'cleared'),

('990e8400-e29b-41d4-a716-446655440008', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440003', 
 CURRENT_DATE - INTERVAL '5 days', 238.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440003', '购物', '盒马鲜生', '生鲜采购', 'cleared'),

('990e8400-e29b-41d4-a716-446655440009', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440001', 
 CURRENT_DATE - INTERVAL '3 days', 2000.00, 'income', 
 '770e8400-e29b-41d4-a716-446655440013', '投资收益', '股票账户', '股票分红', 'cleared'),

('990e8400-e29b-41d4-a716-446655440010', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440002', 
 CURRENT_DATE - INTERVAL '1 day', 38.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440001', '餐饮', '星巴克', '美式咖啡', 'cleared'),

('990e8400-e29b-41d4-a716-446655440011', '550e8400-e29b-41d4-a716-446655440001', '660e8400-e29b-41d4-a716-446655440005', 
 CURRENT_DATE, 100.00, 'expense', 
 '770e8400-e29b-41d4-a716-446655440004', '娱乐', '电影院', '电影票', 'pending');

-- 创建规则
INSERT INTO rules (id, ledger_id, name, description, rule_type, conditions, actions, priority, is_active) VALUES
('aa0e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 
 '星巴克自动分类', '自动将星巴克交易分类为餐饮', 'categorization',
 '[{"field": "payee", "operator": "contains", "value": "星巴克", "case_sensitive": false}]',
 '[{"action_type": "set_category", "target_field": "category_id", "target_value": "770e8400-e29b-41d4-a716-446655440001"}]',
 10, true),

('aa0e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', 
 '大额支出标记', '超过1000元的支出自动添加标签', 'tagging',
 '[{"field": "amount", "operator": "greater_than", "value": 1000}]',
 '[{"action_type": "add_tag", "target_field": "tags", "target_value": "大额支出"}]',
 20, true),

('aa0e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440001', 
 '交通费用识别', '识别交通相关支出', 'categorization',
 '[{"field": "payee", "operator": "contains", "value": "滴滴", "case_sensitive": false}]',
 '[{"action_type": "set_category", "target_field": "category_id", "target_value": "770e8400-e29b-41d4-a716-446655440002"}]',
 15, true);

-- 更新账户余额（基于交易）
UPDATE accounts SET current_balance = 
    COALESCE((SELECT SUM(CASE 
        WHEN transaction_type = 'income' THEN amount 
        WHEN transaction_type = 'expense' THEN -amount 
        ELSE 0 
    END) FROM transactions WHERE account_id = accounts.id), 0) + current_balance
WHERE ledger_id = '550e8400-e29b-41d4-a716-446655440001';

-- 显示统计信息
SELECT 
    'Ledgers' as table_name, COUNT(*) as count FROM ledgers
UNION ALL
SELECT 'Categories', COUNT(*) FROM categories
UNION ALL
SELECT 'Accounts', COUNT(*) FROM accounts
UNION ALL
SELECT 'Payees', COUNT(*) FROM payees
UNION ALL
SELECT 'Transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'Rules', COUNT(*) FROM rules;