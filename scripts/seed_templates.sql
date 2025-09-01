-- ============================================================================
-- Jive Money 系统分类模板种子数据
-- 用于将系统模板写入数据库
-- ============================================================================

-- 先清理现有的模板数据（可选，用于重新导入）
-- DELETE FROM system_category_templates;

-- 确保分类组存在
INSERT INTO category_groups (key, name, name_en, name_zh, icon, display_order) VALUES
    ('income', '收入类别', 'Income', '收入类别', '💰', 1),
    ('daily_expense', '日常消费', 'Daily Expenses', '日常消费', '🛒', 2),
    ('housing', '居住相关', 'Housing', '居住相关', '🏠', 3),
    ('transportation', '交通出行', 'Transportation', '交通出行', '🚗', 4),
    ('health_education', '健康教育', 'Health & Education', '健康教育', '🏥', 5),
    ('entertainment_social', '娱乐社交', 'Entertainment & Social', '娱乐社交', '🎬', 6),
    ('financial', '金融理财', 'Financial', '金融理财', '💳', 7),
    ('business', '商务办公', 'Business', '商务办公', '💼', 8),
    ('other', '其他', 'Other', '其他', '📦', 9)
ON CONFLICT (key) DO UPDATE SET
    name = EXCLUDED.name,
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    icon = EXCLUDED.icon,
    display_order = EXCLUDED.display_order;

-- ============================================================================
-- 收入类别模板 (10个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('工资收入', 'Salary', '工资收入', 'income', '#10B981', '💰', 'income', true, ARRAY['必备', '常用']),
    ('奖金收入', 'Bonus', '奖金收入', 'income', '#059669', '🎁', 'income', true, ARRAY['常用']),
    ('投资收益', 'Investment Income', '投资收益', 'income', '#047857', '📈', 'income', false, ARRAY['理财']),
    ('副业收入', 'Side Income', '副业收入', 'income', '#065F46', '💼', 'income', false, ARRAY['兼职']),
    ('租金收入', 'Rental Income', '租金收入', 'income', '#064E3B', '🏘️', 'income', false, ARRAY['房产']),
    ('分红收入', 'Dividend', '分红收入', 'income', '#14B8A6', '💹', 'income', false, ARRAY['投资']),
    ('利息收入', 'Interest', '利息收入', 'income', '#0D9488', '🏦', 'income', false, ARRAY['理财']),
    ('退税', 'Tax Refund', '退税', 'income', '#0F766E', '📋', 'income', false, ARRAY['政府']),
    ('礼金', 'Gift Money', '礼金', 'income', '#115E59', '🧧', 'income', false, ARRAY['节日']),
    ('其他收入', 'Other Income', '其他收入', 'income', '#134E4A', '📥', 'income', false, ARRAY['其他'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 日常消费模板 (15个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('餐饮美食', 'Food & Dining', '餐饮美食', 'expense', '#EF4444', '🍽️', 'daily_expense', true, ARRAY['热门', '必备']),
    ('早餐', 'Breakfast', '早餐', 'expense', '#F87171', '🥐', 'daily_expense', false, ARRAY['餐饮']),
    ('午餐', 'Lunch', '午餐', 'expense', '#F87171', '🍱', 'daily_expense', false, ARRAY['餐饮']),
    ('晚餐', 'Dinner', '晚餐', 'expense', '#F87171', '🍝', 'daily_expense', false, ARRAY['餐饮']),
    ('咖啡茶饮', 'Coffee & Tea', '咖啡茶饮', 'expense', '#FB923C', '☕', 'daily_expense', true, ARRAY['热门']),
    ('零食饮料', 'Snacks & Drinks', '零食饮料', 'expense', '#FDBA74', '🥤', 'daily_expense', false, ARRAY['日常']),
    ('买菜', 'Groceries', '买菜', 'expense', '#FCD34D', '🥬', 'daily_expense', true, ARRAY['必备']),
    ('水果', 'Fruits', '水果', 'expense', '#FDE68A', '🍎', 'daily_expense', false, ARRAY['日常']),
    ('日用品', 'Daily Necessities', '日用品', 'expense', '#FDE047', '🧻', 'daily_expense', true, ARRAY['必备']),
    ('服装鞋包', 'Clothing & Shoes', '服装鞋包', 'expense', '#FACC15', '👔', 'daily_expense', true, ARRAY['购物']),
    ('化妆品', 'Cosmetics', '化妆品', 'expense', '#FBD144', '💄', 'daily_expense', false, ARRAY['美妆']),
    ('烟酒', 'Tobacco & Alcohol', '烟酒', 'expense', '#F59E0B', '🍺', 'daily_expense', false, ARRAY['嗜好']),
    ('宠物', 'Pet', '宠物', 'expense', '#FBBF24', '🐾', 'daily_expense', false, ARRAY['宠物']),
    ('外卖', 'Delivery', '外卖', 'expense', '#FCD34D', '📦', 'daily_expense', true, ARRAY['热门']),
    ('超市', 'Supermarket', '超市', 'expense', '#FDE68A', '🛒', 'daily_expense', true, ARRAY['购物'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 交通出行模板 (10个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('公共交通', 'Public Transport', '公共交通', 'expense', '#F97316', '🚇', 'transportation', true, ARRAY['必备']),
    ('地铁', 'Subway', '地铁', 'expense', '#FB923C', '🚊', 'transportation', false, ARRAY['通勤']),
    ('公交', 'Bus', '公交', 'expense', '#FDBA74', '🚌', 'transportation', false, ARRAY['通勤']),
    ('打车', 'Taxi/Ride', '打车', 'expense', '#FB923C', '🚕', 'transportation', true, ARRAY['热门']),
    ('加油', 'Gas/Fuel', '加油', 'expense', '#FDBA74', '⛽', 'transportation', true, ARRAY['车辆']),
    ('停车费', 'Parking', '停车费', 'expense', '#FED7AA', '🅿️', 'transportation', false, ARRAY['车辆']),
    ('汽车保养', 'Car Maintenance', '汽车保养', 'expense', '#FFEDD5', '🔧', 'transportation', false, ARRAY['车辆']),
    ('火车票', 'Train Ticket', '火车票', 'expense', '#EA580C', '🚄', 'transportation', false, ARRAY['出行']),
    ('机票', 'Flight Ticket', '机票', 'expense', '#DC2626', '✈️', 'transportation', false, ARRAY['旅行']),
    ('高速费', 'Highway Toll', '高速费', 'expense', '#C2410C', '🛣️', 'transportation', false, ARRAY['车辆'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 居住相关模板 (10个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('房租', 'Rent', '房租', 'expense', '#8B5CF6', '🏠', 'housing', true, ARRAY['必备']),
    ('房贷', 'Mortgage', '房贷', 'expense', '#A78BFA', '🏦', 'housing', true, ARRAY['必备']),
    ('水费', 'Water Bill', '水费', 'expense', '#C4B5FD', '💧', 'housing', true, ARRAY['必备']),
    ('电费', 'Electricity Bill', '电费', 'expense', '#DDD6FE', '⚡', 'housing', true, ARRAY['必备']),
    ('燃气费', 'Gas Bill', '燃气费', 'expense', '#E9D5FF', '🔥', 'housing', true, ARRAY['必备']),
    ('物业费', 'Property Fee', '物业费', 'expense', '#F3E8FF', '🏢', 'housing', false, ARRAY['物业']),
    ('网费', 'Internet', '网费', 'expense', '#EDE9FE', '🌐', 'housing', true, ARRAY['必备']),
    ('家具家电', 'Furniture', '家具家电', 'expense', '#7C3AED', '🛋️', 'housing', false, ARRAY['装修']),
    ('维修保养', 'Maintenance', '维修保养', 'expense', '#9333EA', '🔨', 'housing', false, ARRAY['维护']),
    ('清洁用品', 'Cleaning Supplies', '清洁用品', 'expense', '#A855F7', '🧹', 'housing', false, ARRAY['日常'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 健康教育模板 (10个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('医疗费', 'Medical', '医疗费', 'expense', '#DC2626', '🏥', 'health_education', true, ARRAY['重要']),
    ('药品费', 'Medicine', '药品费', 'expense', '#EF4444', '💊', 'health_education', true, ARRAY['健康']),
    ('体检', 'Health Check', '体检', 'expense', '#F87171', '🩺', 'health_education', false, ARRAY['健康']),
    ('健身', 'Fitness', '健身', 'expense', '#10B981', '💪', 'health_education', true, ARRAY['运动']),
    ('保健品', 'Supplements', '保健品', 'expense', '#14B8A6', '🍃', 'health_education', false, ARRAY['健康']),
    ('教育培训', 'Education', '教育培训', 'expense', '#0EA5E9', '📚', 'health_education', true, ARRAY['学习']),
    ('书籍', 'Books', '书籍', 'expense', '#0284C7', '📖', 'health_education', false, ARRAY['学习']),
    ('在线课程', 'Online Course', '在线课程', 'expense', '#0369A1', '💻', 'health_education', false, ARRAY['学习']),
    ('考试费', 'Exam Fee', '考试费', 'expense', '#075985', '📝', 'health_education', false, ARRAY['教育']),
    ('学费', 'Tuition', '学费', 'expense', '#0C4A6E', '🎓', 'health_education', false, ARRAY['教育'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 娱乐社交模板 (10个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('电影', 'Movies', '电影', 'expense', '#7C3AED', '🎬', 'entertainment_social', true, ARRAY['热门']),
    ('游戏', 'Games', '游戏', 'expense', '#8B5CF6', '🎮', 'entertainment_social', true, ARRAY['热门']),
    ('KTV', 'KTV', 'KTV', 'expense', '#A78BFA', '🎤', 'entertainment_social', false, ARRAY['社交']),
    ('旅游', 'Travel', '旅游', 'expense', '#C4B5FD', '🌍', 'entertainment_social', true, ARRAY['热门']),
    ('聚餐', 'Dining Out', '聚餐', 'expense', '#DDD6FE', '🍻', 'entertainment_social', true, ARRAY['社交']),
    ('礼物', 'Gifts', '礼物', 'expense', '#E9D5FF', '🎁', 'entertainment_social', false, ARRAY['社交']),
    ('会员订阅', 'Subscriptions', '会员订阅', 'expense', '#F3E8FF', '📱', 'entertainment_social', true, ARRAY['订阅']),
    ('演出门票', 'Concert/Show', '演出门票', 'expense', '#FAE8FF', '🎭', 'entertainment_social', false, ARRAY['娱乐']),
    ('运动', 'Sports', '运动', 'expense', '#FCE7F3', '⚽', 'entertainment_social', false, ARRAY['运动']),
    ('酒店住宿', 'Hotel', '酒店住宿', 'expense', '#FBCFE8', '🏨', 'entertainment_social', false, ARRAY['旅行'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 金融理财模板 (8个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('投资理财', 'Investment', '投资理财', 'expense', '#059669', '📈', 'financial', true, ARRAY['理财']),
    ('保险', 'Insurance', '保险', 'expense', '#10B981', '🛡️', 'financial', true, ARRAY['保障']),
    ('信用卡还款', 'Credit Card', '信用卡还款', 'expense', '#34D399', '💳', 'financial', true, ARRAY['还款']),
    ('贷款还款', 'Loan Payment', '贷款还款', 'expense', '#6EE7B7', '🏦', 'financial', false, ARRAY['还款']),
    ('手续费', 'Service Fee', '手续费', 'expense', '#A7F3D0', '💸', 'financial', false, ARRAY['费用']),
    ('利息支出', 'Interest Payment', '利息支出', 'expense', '#D1FAE5', '📊', 'financial', false, ARRAY['费用']),
    ('税费', 'Tax', '税费', 'expense', '#ECFDF5', '📋', 'financial', false, ARRAY['政府']),
    ('罚款', 'Fine/Penalty', '罚款', 'expense', '#F0FDF4', '⚠️', 'financial', false, ARRAY['费用'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 商务办公模板 (7个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('办公用品', 'Office Supplies', '办公用品', 'expense', '#0891B2', '📎', 'business', false, ARRAY['办公']),
    ('差旅费', 'Business Travel', '差旅费', 'expense', '#0E7490', '✈️', 'business', true, ARRAY['差旅']),
    ('通讯费', 'Communication', '通讯费', 'expense', '#155E75', '📞', 'business', false, ARRAY['办公']),
    ('快递费', 'Express/Shipping', '快递费', 'expense', '#164E63', '📮', 'business', false, ARRAY['物流']),
    ('广告推广', 'Advertising', '广告推广', 'expense', '#083344', '📢', 'business', false, ARRAY['营销']),
    ('软件服务', 'Software Service', '软件服务', 'expense', '#0C4A6E', '💻', 'business', true, ARRAY['订阅']),
    ('设备采购', 'Equipment', '设备采购', 'expense', '#082F49', '🖥️', 'business', false, ARRAY['资产'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 转账类模板 (5个)
-- ============================================================================
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('账户转账', 'Account Transfer', '账户转账', 'transfer', '#6B7280', '🔄', 'other', true, ARRAY['必备']),
    ('提现', 'Withdrawal', '提现', 'transfer', '#9CA3AF', '💵', 'other', false, ARRAY['转账']),
    ('充值', 'Deposit', '充值', 'transfer', '#D1D5DB', '💰', 'other', false, ARRAY['转账']),
    ('还款', 'Repayment', '还款', 'transfer', '#E5E7EB', '↩️', 'other', false, ARRAY['转账']),
    ('借款', 'Borrowing', '借款', 'transfer', '#F3F4F6', '🤝', 'other', false, ARRAY['转账'])
ON CONFLICT (name, category_group) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_zh = EXCLUDED.name_zh,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    is_featured = EXCLUDED.is_featured,
    tags = EXCLUDED.tags;

-- ============================================================================
-- 查询统计
-- ============================================================================
SELECT 
    cg.name as group_name,
    COUNT(t.id) as template_count,
    COUNT(CASE WHEN t.is_featured THEN 1 END) as featured_count
FROM category_groups cg
LEFT JOIN system_category_templates t ON cg.key = t.category_group
GROUP BY cg.name, cg.display_order
ORDER BY cg.display_order;

-- 总计
SELECT 
    COUNT(*) as total_templates,
    COUNT(CASE WHEN is_featured THEN 1 END) as featured_templates,
    COUNT(DISTINCT category_group) as groups_used
FROM system_category_templates;

COMMIT;