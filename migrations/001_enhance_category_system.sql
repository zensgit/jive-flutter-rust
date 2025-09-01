-- Jive Money 分类系统增强迁移
-- 添加系统分类模板、分类组和批量操作支持

-- =====================================================
-- 分类组表
-- =====================================================
CREATE TABLE category_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 插入默认分类组
INSERT INTO category_groups (key, name, name_en, name_zh, display_order) VALUES
('income', '收入类别', 'Income', '收入类别', 1),
('daily_expense', '日常消费', 'Daily Expenses', '日常消费', 2),
('housing', '居住相关', 'Housing', '居住相关', 3),
('health_education', '健康教育', 'Health & Education', '健康教育', 4),
('entertainment_social', '娱乐社交', 'Entertainment & Social', '娱乐社交', 5),
('financial', '金融理财', 'Financial', '金融理财', 6),
('business', '商务办公', 'Business', '商务办公', 7);

-- =====================================================
-- 系统分类模板表
-- =====================================================
CREATE TABLE system_category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    
    -- 分类属性
    classification VARCHAR(20) NOT NULL CHECK (classification IN ('income', 'expense', 'transfer')),
    color VARCHAR(7) NOT NULL,
    icon VARCHAR(50),
    category_group VARCHAR(50) REFERENCES category_groups(key),
    
    -- 元数据
    version VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    global_usage_count INTEGER DEFAULT 0,
    tags TEXT[],
    
    -- 审计字段
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    INDEX idx_templates_group (category_group),
    INDEX idx_templates_classification (classification),
    INDEX idx_templates_featured (is_featured),
    INDEX idx_templates_active (is_active)
);

-- =====================================================
-- 更新现有分类表结构
-- =====================================================

-- 添加新字段到现有分类表
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS position INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS source_type VARCHAR(20) DEFAULT 'custom',
ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES system_category_templates(id),
ADD COLUMN IF NOT EXISTS template_version VARCHAR(20),
ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 重命名现有字段以匹配新设计
ALTER TABLE categories RENAME COLUMN category_type TO classification;

-- 更新分类表约束
ALTER TABLE categories 
ADD CONSTRAINT check_classification 
CHECK (classification IN ('income', 'expense', 'transfer'));

-- 更新索引
CREATE INDEX IF NOT EXISTS idx_categories_position ON categories(position);
CREATE INDEX IF NOT EXISTS idx_categories_usage ON categories(usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_categories_template ON categories(template_id);
CREATE INDEX IF NOT EXISTS idx_categories_source ON categories(source_type);

-- =====================================================
-- 批量操作记录表
-- =====================================================
CREATE TABLE category_batch_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('recategorize', 'convert', 'merge', 'delete')),
    
    -- 操作数据
    original_data JSONB,
    affected_transactions INTEGER DEFAULT 0,
    
    -- 撤销支持
    can_revert BOOLEAN DEFAULT TRUE,
    reverted_at TIMESTAMP WITH TIME ZONE,
    
    -- 过期时间
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '24 hours'),
    
    -- 索引
    INDEX idx_batch_ops_user_created (user_id, created_at DESC),
    INDEX idx_batch_ops_type (operation_type),
    INDEX idx_batch_ops_expires (expires_at)
);

-- =====================================================
-- 插入默认系统分类模板
-- =====================================================

-- 收入类模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('工资收入', 'Salary', '工资收入', 'income', '#10B981', 'circle-dollar-sign', 'income', TRUE, ARRAY['必备', '常用']),
('奖金收入', 'Bonus', '奖金收入', 'income', '#059669', 'award', 'income', FALSE, ARRAY['常用']),
('投资收益', 'Investment Returns', '投资收益', 'income', '#047857', 'trending-up', 'income', FALSE, ARRAY['理财']),
('副业收入', 'Side Business', '副业收入', 'income', '#065F46', 'briefcase', 'income', FALSE, ARRAY['创业']),
('租金收入', 'Rental Income', '租金收入', 'income', '#064E3B', 'home', 'income', FALSE, ARRAY['投资']),
('利息收入', 'Interest Income', '利息收入', 'income', '#022C22', 'percent', 'income', FALSE, ARRAY['理财']),
('其他收入', 'Other Income', '其他收入', 'income', '#052E16', 'plus-circle', 'income', FALSE, ARRAY['杂项']);

-- 日常支出类模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('餐饮美食', 'Food & Dining', '餐饮美食', 'expense', '#EF4444', 'utensils', 'daily_expense', TRUE, ARRAY['热门', '必备']),
('交通出行', 'Transportation', '交通出行', 'expense', '#F97316', 'car', 'daily_expense', TRUE, ARRAY['热门', '必备']),
('购物消费', 'Shopping', '购物消费', 'expense', '#F59E0B', 'shopping-cart', 'daily_expense', TRUE, ARRAY['热门']),
('生活用品', 'Groceries', '生活用品', 'expense', '#EAB308', 'shopping-bag', 'daily_expense', FALSE, ARRAY['日常']),
('服装配饰', 'Clothing', '服装配饰', 'expense', '#84CC16', 'shirt', 'daily_expense', FALSE, ARRAY['购物']),
('美容美发', 'Personal Care', '美容美发', 'expense', '#22C55E', 'scissors', 'daily_expense', FALSE, ARRAY['个护']),
('手机通讯', 'Phone & Internet', '手机通讯', 'expense', '#10B981', 'smartphone', 'daily_expense', FALSE, ARRAY['通讯']),
('数码电器', 'Electronics', '数码电器', 'expense', '#059669', 'monitor', 'daily_expense', FALSE, ARRAY['科技']);

-- 居住相关模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('房租房贷', 'Rent & Mortgage', '房租房贷', 'expense', '#8B5A2B', 'home', 'housing', TRUE, ARRAY['必备']),
('水电煤气', 'Utilities', '水电煤气', 'expense', '#A16207', 'zap', 'housing', TRUE, ARRAY['必备']),
('物业管理', 'Property Management', '物业管理', 'expense', '#92400E', 'building', 'housing', FALSE, ARRAY['住房']),
('家具家电', 'Furniture', '家具家电', 'expense', '#78350F', 'sofa', 'housing', FALSE, ARRAY['家居']),
('装修维修', 'Home Improvement', '装修维修', 'expense', '#451A03', 'hammer', 'housing', FALSE, ARRAY['装修']),
('家政服务', 'Home Services', '家政服务', 'expense', '#1C0A00', 'user-check', 'housing', FALSE, ARRAY['服务']);

-- 健康教育模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('医疗健康', 'Healthcare', '医疗健康', 'expense', '#DC2626', 'heart-pulse', 'health_education', TRUE, ARRAY['重要', '健康']),
('教育培训', 'Education', '教育培训', 'expense', '#0EA5E9', 'graduation-cap', 'health_education', FALSE, ARRAY['教育']),
('运动健身', 'Fitness', '运动健身', 'expense', '#059669', 'dumbbell', 'health_education', FALSE, ARRAY['健康']),
('保险费用', 'Insurance', '保险费用', 'expense', '#7C2D12', 'shield', 'health_education', FALSE, ARRAY['保障']),
('图书学习', 'Books & Learning', '图书学习', 'expense', '#0F766E', 'book-open', 'health_education', FALSE, ARRAY['学习']);

-- 娱乐社交模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('娱乐休闲', 'Entertainment', '娱乐休闲', 'expense', '#7C3AED', 'gamepad-2', 'entertainment_social', TRUE, ARRAY['热门']),
('旅游度假', 'Travel', '旅游度假', 'expense', '#5B21B6', 'plane', 'entertainment_social', FALSE, ARRAY['旅行']),
('聚餐聚会', 'Social Dining', '聚餐聚会', 'expense', '#4C1D95', 'users', 'entertainment_social', FALSE, ARRAY['社交']),
('礼品礼金', 'Gifts & Donations', '礼品礼金', 'expense', '#3730A3', 'gift', 'entertainment_social', FALSE, ARRAY['人情']),
('宠物相关', 'Pets', '宠物相关', 'expense', '#312E81', 'heart', 'entertainment_social', FALSE, ARRAY['宠物']),
('兴趣爱好', 'Hobbies', '兴趣爱好', 'expense', '#1E1B4B', 'palette', 'entertainment_social', FALSE, ARRAY['爱好']);

-- 金融理财模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('投资理财', 'Investment', '投资理财', 'expense', '#059669', 'trending-up', 'financial', FALSE, ARRAY['投资']),
('银行手续费', 'Bank Fees', '银行手续费', 'expense', '#047857', 'banknote', 'financial', FALSE, ARRAY['费用']),
('信用卡还款', 'Credit Card Payment', '信用卡还款', 'expense', '#065F46', 'credit-card', 'financial', FALSE, ARRAY['还款']),
('贷款还款', 'Loan Payments', '贷款还款', 'expense', '#064E3B', 'credit-card', 'financial', FALSE, ARRAY['还款']),
('保险理财', 'Insurance Investment', '保险理财', 'expense', '#022C22', 'shield-plus', 'financial', FALSE, ARRAY['保险']),
('税费缴纳', 'Tax Payments', '税费缴纳', 'expense', '#052E16', 'receipt', 'financial', FALSE, ARRAY['税务']);

-- 商务办公模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('办公用品', 'Office Supplies', '办公用品', 'expense', '#0EA5E9', 'briefcase', 'business', FALSE, ARRAY['办公']),
('商务差旅', 'Business Travel', '商务差旅', 'expense', '#0284C7', 'plane', 'business', FALSE, ARRAY['差旅']),
('会议培训', 'Meetings & Training', '会议培训', 'expense', '#0369A1', 'presentation', 'business', FALSE, ARRAY['培训']),
('营销推广', 'Marketing', '营销推广', 'expense', '#075985', 'megaphone', 'business', FALSE, ARRAY['营销']),
('软件服务', 'Software & Services', '软件服务', 'expense', '#0C4A6E', 'monitor', 'business', FALSE, ARRAY['软件']),
('专业服务', 'Professional Services', '专业服务', 'expense', '#082F49', 'user-check', 'business', FALSE, ARRAY['服务']);

-- 转账类模板
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('账户转账', 'Account Transfer', '账户转账', 'transfer', '#444CE7', 'arrow-left-right', 'transfer', TRUE, ARRAY['转账']);

-- =====================================================
-- 更新触发器
-- =====================================================

-- 创建更新时间触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为新表添加触发器
CREATE TRIGGER update_category_groups_updated_at 
    BEFORE UPDATE ON category_groups 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_category_templates_updated_at 
    BEFORE UPDATE ON system_category_templates 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 为现有分类表添加使用统计更新函数
CREATE OR REPLACE FUNCTION update_category_usage_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE categories 
        SET usage_count = usage_count + 1,
            last_used_at = CURRENT_TIMESTAMP
        WHERE id = NEW.category_id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' AND OLD.category_id != NEW.category_id THEN
        -- 减少旧分类的使用次数
        UPDATE categories 
        SET usage_count = GREATEST(usage_count - 1, 0)
        WHERE id = OLD.category_id;
        -- 增加新分类的使用次数
        UPDATE categories 
        SET usage_count = usage_count + 1,
            last_used_at = CURRENT_TIMESTAMP
        WHERE id = NEW.category_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE categories 
        SET usage_count = GREATEST(usage_count - 1, 0)
        WHERE id = OLD.category_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- 为交易表添加分类使用统计触发器
CREATE TRIGGER update_category_usage_on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW 
    WHEN (pg_trigger_depth() = 0)  -- 防止递归触发
    EXECUTE FUNCTION update_category_usage_count();

-- =====================================================
-- 创建视图和函数
-- =====================================================

-- 创建分类统计视图
CREATE OR REPLACE VIEW category_statistics AS
SELECT 
    c.id,
    c.name,
    c.classification,
    c.ledger_id,
    c.usage_count,
    c.last_used_at,
    COALESCE(t.transaction_count, 0) as actual_transaction_count,
    COALESCE(t.total_amount, 0) as total_amount,
    CASE 
        WHEN c.usage_count = 0 THEN 'unused'
        WHEN c.usage_count < 5 THEN 'low'
        WHEN c.usage_count < 20 THEN 'medium'
        ELSE 'high'
    END as usage_level
FROM categories c
LEFT JOIN (
    SELECT 
        category_id,
        COUNT(*) as transaction_count,
        SUM(amount) as total_amount
    FROM transactions 
    WHERE deleted_at IS NULL 
      AND category_id IS NOT NULL
    GROUP BY category_id
) t ON c.id = t.category_id
WHERE c.deleted_at IS NULL;

-- 创建获取分类层级的函数
CREATE OR REPLACE FUNCTION get_category_hierarchy(category_uuid UUID)
RETURNS TABLE(
    id UUID,
    name VARCHAR(200),
    level INTEGER,
    path TEXT
) AS $$
WITH RECURSIVE category_tree AS (
    -- 基础情况：根分类
    SELECT 
        c.id,
        c.name,
        0 as level,
        c.name::text as path,
        c.parent_id
    FROM categories c
    WHERE c.id = category_uuid
    
    UNION ALL
    
    -- 递归情况：子分类
    SELECT 
        c.id,
        c.name,
        ct.level + 1,
        ct.path || ' > ' || c.name,
        c.parent_id
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_id = ct.id
    WHERE ct.level < 10  -- 防止无限递归
)
SELECT ct.id, ct.name, ct.level, ct.path
FROM category_tree ct;
$$ LANGUAGE sql;