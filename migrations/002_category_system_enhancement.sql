-- ============================================================================
-- Jive Money 分类系统增强
-- 版本: 2.0
-- 创建日期: 2025-01-01
-- 描述: 实现完整的三层分类架构（系统模板 → 用户分类 → 标签）
-- ============================================================================

-- ============================================================================
-- 1. 分类组表 - 用于组织系统分类模板
-- ============================================================================
CREATE TABLE IF NOT EXISTS category_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_category_groups_key ON category_groups(key);
CREATE INDEX idx_category_groups_order ON category_groups(display_order);
CREATE INDEX idx_category_groups_active ON category_groups(is_active);

-- ============================================================================
-- 2. 系统分类模板表
-- ============================================================================
CREATE TABLE IF NOT EXISTS system_category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    
    -- 分类属性
    classification VARCHAR(20) NOT NULL CHECK (classification IN ('income', 'expense', 'transfer')),
    color VARCHAR(7) NOT NULL CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
    icon VARCHAR(50),
    category_group VARCHAR(50) REFERENCES category_groups(key),
    
    -- 元数据
    version VARCHAR(20) DEFAULT '1.0.0',
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    global_usage_count INTEGER DEFAULT 0,
    tags TEXT[],
    
    -- 审计字段
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 约束
    CONSTRAINT uk_template_name_group UNIQUE(name, category_group)
);

-- 创建索引
CREATE INDEX idx_templates_group ON system_category_templates(category_group);
CREATE INDEX idx_templates_classification ON system_category_templates(classification);
CREATE INDEX idx_templates_featured ON system_category_templates(is_featured) WHERE is_featured = true;
CREATE INDEX idx_templates_active ON system_category_templates(is_active) WHERE is_active = true;
CREATE INDEX idx_templates_usage ON system_category_templates(global_usage_count DESC);

-- ============================================================================
-- 3. 增强用户分类表
-- ============================================================================
ALTER TABLE categories ADD COLUMN IF NOT EXISTS source_type VARCHAR(20) DEFAULT 'custom' 
    CHECK (source_type IN ('system', 'custom', 'imported'));
ALTER TABLE categories ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES system_category_templates(id);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS template_version VARCHAR(20);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS position INTEGER DEFAULT 0;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0;
ALTER TABLE categories ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMP WITH TIME ZONE;

-- 创建新索引
CREATE INDEX IF NOT EXISTS idx_categories_template ON categories(template_id);
CREATE INDEX IF NOT EXISTS idx_categories_position ON categories(ledger_id, position);
CREATE INDEX IF NOT EXISTS idx_categories_usage ON categories(usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_categories_last_used ON categories(last_used_at DESC NULLS LAST);

-- ============================================================================
-- 4. 批量操作记录表
-- ============================================================================
CREATE TABLE IF NOT EXISTS category_batch_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('recategorize', 'convert', 'merge', 'delete')),
    original_data JSONB,
    affected_transactions INTEGER DEFAULT 0,
    can_revert BOOLEAN DEFAULT true,
    reverted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP + INTERVAL '24 hours',
    
    -- 约束
    CONSTRAINT chk_revert_before_expire CHECK (reverted_at IS NULL OR reverted_at <= expires_at)
);

-- 创建索引
CREATE INDEX idx_batch_operations_user ON category_batch_operations(user_id, created_at DESC);
CREATE INDEX idx_batch_operations_type ON category_batch_operations(operation_type);
CREATE INDEX idx_batch_operations_expires ON category_batch_operations(expires_at) WHERE can_revert = true;

-- ============================================================================
-- 5. 分类转换历史表
-- ============================================================================
CREATE TABLE IF NOT EXISTS category_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    ledger_id UUID NOT NULL REFERENCES ledgers(id),
    
    -- 转换信息
    source_category_id UUID NOT NULL,
    source_category_name VARCHAR(100) NOT NULL,
    target_tag_id UUID REFERENCES tags(id),
    target_tag_name VARCHAR(100) NOT NULL,
    
    -- 转换选项
    applied_to_transactions BOOLEAN DEFAULT false,
    transaction_count INTEGER DEFAULT 0,
    date_range_start DATE,
    date_range_end DATE,
    category_deleted BOOLEAN DEFAULT false,
    
    -- 审计
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    CONSTRAINT fk_conversions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_conversions_user ON category_conversions(user_id, created_at DESC);
CREATE INDEX idx_conversions_category ON category_conversions(source_category_id);
CREATE INDEX idx_conversions_tag ON category_conversions(target_tag_id);

-- ============================================================================
-- 6. 分类使用统计表（用于智能推荐）
-- ============================================================================
CREATE TABLE IF NOT EXISTS category_usage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    ledger_id UUID NOT NULL REFERENCES ledgers(id),
    
    -- 统计数据
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP WITH TIME ZONE,
    total_amount DECIMAL(19, 4) DEFAULT 0,
    average_amount DECIMAL(19, 4) DEFAULT 0,
    
    -- 时间分布
    morning_count INTEGER DEFAULT 0,    -- 6:00-12:00
    afternoon_count INTEGER DEFAULT 0,  -- 12:00-18:00
    evening_count INTEGER DEFAULT 0,    -- 18:00-24:00
    night_count INTEGER DEFAULT 0,      -- 0:00-6:00
    
    -- 星期分布
    weekday_count INTEGER DEFAULT 0,
    weekend_count INTEGER DEFAULT 0,
    
    -- 更新时间
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- 唯一约束
    CONSTRAINT uk_category_user_ledger UNIQUE(category_id, user_id, ledger_id)
);

CREATE INDEX idx_usage_stats_category ON category_usage_stats(category_id);
CREATE INDEX idx_usage_stats_user ON category_usage_stats(user_id);
CREATE INDEX idx_usage_stats_count ON category_usage_stats(usage_count DESC);

-- ============================================================================
-- 7. 插入默认分类组
-- ============================================================================
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
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 8. 插入系统分类模板（50+ 预设模板）
-- ============================================================================

-- 收入类别
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
ON CONFLICT (name, category_group) DO NOTHING;

-- 日常消费
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('餐饮美食', 'Food & Dining', '餐饮美食', 'expense', '#EF4444', '🍽️', 'daily_expense', true, ARRAY['热门', '必备']),
    ('早餐', 'Breakfast', '早餐', 'expense', '#F87171', '🥐', 'daily_expense', false, ARRAY['餐饮']),
    ('午餐', 'Lunch', '午餐', 'expense', '#F87171', '🍱', 'daily_expense', false, ARRAY['餐饮']),
    ('晚餐', 'Dinner', '晚餐', 'expense', '#F87171', '🍝', 'daily_expense', false, ARRAY['餐饮']),
    ('咖啡茶饮', 'Coffee & Tea', '咖啡茶饮', 'expense', '#FB923C', '☕', 'daily_expense', true, ARRAY['热门']),
    ('零食饮料', 'Snacks & Drinks', '零食饮料', 'expense', '#FDBA74', '🥤', 'daily_expense', false, ARRAY['日常']),
    ('买菜', 'Groceries', '买菜', 'expense', '#FCD34D', '🥬', 'daily_expense', true, ARRAY['必备']),
    ('日用品', 'Daily Necessities', '日用品', 'expense', '#FDE047', '🧻', 'daily_expense', true, ARRAY['必备']),
    ('服装鞋包', 'Clothing & Shoes', '服装鞋包', 'expense', '#FACC15', '👔', 'daily_expense', true, ARRAY['购物']),
    ('化妆品', 'Cosmetics', '化妆品', 'expense', '#FBD144', '💄', 'daily_expense', false, ARRAY['美妆'])
ON CONFLICT (name, category_group) DO NOTHING;

-- 交通出行
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('公共交通', 'Public Transport', '公共交通', 'expense', '#F97316', '🚇', 'transportation', true, ARRAY['必备']),
    ('打车', 'Taxi/Ride', '打车', 'expense', '#FB923C', '🚕', 'transportation', true, ARRAY['热门']),
    ('加油', 'Gas/Fuel', '加油', 'expense', '#FDBA74', '⛽', 'transportation', true, ARRAY['车辆']),
    ('停车费', 'Parking', '停车费', 'expense', '#FED7AA', '🅿️', 'transportation', false, ARRAY['车辆']),
    ('汽车保养', 'Car Maintenance', '汽车保养', 'expense', '#FFEDD5', '🔧', 'transportation', false, ARRAY['车辆']),
    ('火车票', 'Train Ticket', '火车票', 'expense', '#EA580C', '🚄', 'transportation', false, ARRAY['出行']),
    ('机票', 'Flight Ticket', '机票', 'expense', '#DC2626', '✈️', 'transportation', false, ARRAY['旅行']),
    ('高速费', 'Highway Toll', '高速费', 'expense', '#C2410C', '🛣️', 'transportation', false, ARRAY['车辆'])
ON CONFLICT (name, category_group) DO NOTHING;

-- 居住相关
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('房租', 'Rent', '房租', 'expense', '#8B5CF6', '🏠', 'housing', true, ARRAY['必备']),
    ('房贷', 'Mortgage', '房贷', 'expense', '#A78BFA', '🏦', 'housing', true, ARRAY['必备']),
    ('水费', 'Water Bill', '水费', 'expense', '#C4B5FD', '💧', 'housing', true, ARRAY['必备']),
    ('电费', 'Electricity Bill', '电费', 'expense', '#DDD6FE', '⚡', 'housing', true, ARRAY['必备']),
    ('燃气费', 'Gas Bill', '燃气费', 'expense', '#E9D5FF', '🔥', 'housing', true, ARRAY['必备']),
    ('物业费', 'Property Fee', '物业费', 'expense', '#F3E8FF', '🏢', 'housing', false, ARRAY['物业']),
    ('网费', 'Internet', '网费', 'expense', '#EDE9FE', '🌐', 'housing', true, ARRAY['必备']),
    ('家具家电', 'Furniture', '家具家电', 'expense', '#7C3AED', '🛋️', 'housing', false, ARRAY['装修'])
ON CONFLICT (name, category_group) DO NOTHING;

-- 健康教育
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('医疗费', 'Medical', '医疗费', 'expense', '#DC2626', '🏥', 'health_education', true, ARRAY['重要']),
    ('药品费', 'Medicine', '药品费', 'expense', '#EF4444', '💊', 'health_education', true, ARRAY['健康']),
    ('体检', 'Health Check', '体检', 'expense', '#F87171', '🩺', 'health_education', false, ARRAY['健康']),
    ('健身', 'Fitness', '健身', 'expense', '#10B981', '💪', 'health_education', true, ARRAY['运动']),
    ('教育培训', 'Education', '教育培训', 'expense', '#0EA5E9', '📚', 'health_education', true, ARRAY['学习']),
    ('书籍', 'Books', '书籍', 'expense', '#0284C7', '📖', 'health_education', false, ARRAY['学习']),
    ('在线课程', 'Online Course', '在线课程', 'expense', '#0369A1', '💻', 'health_education', false, ARRAY['学习'])
ON CONFLICT (name, category_group) DO NOTHING;

-- 娱乐社交
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('电影', 'Movies', '电影', 'expense', '#7C3AED', '🎬', 'entertainment_social', true, ARRAY['热门']),
    ('游戏', 'Games', '游戏', 'expense', '#8B5CF6', '🎮', 'entertainment_social', true, ARRAY['热门']),
    ('KTV', 'KTV', 'KTV', 'expense', '#A78BFA', '🎤', 'entertainment_social', false, ARRAY['社交']),
    ('旅游', 'Travel', '旅游', 'expense', '#C4B5FD', '🌍', 'entertainment_social', true, ARRAY['热门']),
    ('聚餐', 'Dining Out', '聚餐', 'expense', '#DDD6FE', '🍻', 'entertainment_social', true, ARRAY['社交']),
    ('礼物', 'Gifts', '礼物', 'expense', '#E9D5FF', '🎁', 'entertainment_social', false, ARRAY['社交']),
    ('会员订阅', 'Subscriptions', '会员订阅', 'expense', '#F3E8FF', '📱', 'entertainment_social', true, ARRAY['订阅'])
ON CONFLICT (name, category_group) DO NOTHING;

-- 金融理财
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
    ('投资理财', 'Investment', '投资理财', 'expense', '#059669', '📈', 'financial', true, ARRAY['理财']),
    ('保险', 'Insurance', '保险', 'expense', '#10B981', '🛡️', 'financial', true, ARRAY['保障']),
    ('信用卡还款', 'Credit Card', '信用卡还款', 'expense', '#34D399', '💳', 'financial', true, ARRAY['还款']),
    ('贷款还款', 'Loan Payment', '贷款还款', 'expense', '#6EE7B7', '🏦', 'financial', false, ARRAY['还款']),
    ('手续费', 'Service Fee', '手续费', 'expense', '#A7F3D0', '💸', 'financial', false, ARRAY['费用'])
ON CONFLICT (name, category_group) DO NOTHING;

-- ============================================================================
-- 9. 创建触发器函数 - 自动更新分类使用统计
-- ============================================================================
CREATE OR REPLACE FUNCTION update_category_usage_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.category_id IS DISTINCT FROM NEW.category_id) THEN
        -- 更新新分类的统计
        IF NEW.category_id IS NOT NULL THEN
            UPDATE categories 
            SET usage_count = usage_count + 1,
                last_used_at = CURRENT_TIMESTAMP
            WHERE id = NEW.category_id;
            
            -- 更新或插入使用统计
            INSERT INTO category_usage_stats (
                category_id, user_id, ledger_id, 
                usage_count, last_used_at, total_amount
            ) VALUES (
                NEW.category_id, NEW.user_id, NEW.ledger_id,
                1, CURRENT_TIMESTAMP, NEW.amount
            )
            ON CONFLICT (category_id, user_id, ledger_id) 
            DO UPDATE SET
                usage_count = category_usage_stats.usage_count + 1,
                last_used_at = CURRENT_TIMESTAMP,
                total_amount = category_usage_stats.total_amount + EXCLUDED.total_amount,
                average_amount = (category_usage_stats.total_amount + EXCLUDED.total_amount) / (category_usage_stats.usage_count + 1);
        END IF;
        
        -- 更新旧分类的统计（如果是UPDATE操作）
        IF TG_OP = 'UPDATE' AND OLD.category_id IS NOT NULL AND OLD.category_id IS DISTINCT FROM NEW.category_id THEN
            UPDATE categories 
            SET usage_count = GREATEST(usage_count - 1, 0)
            WHERE id = OLD.category_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS trg_update_category_usage ON transactions;
CREATE TRIGGER trg_update_category_usage
    AFTER INSERT OR UPDATE OF category_id ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_category_usage_stats();

-- ============================================================================
-- 10. 创建视图 - 分类层级视图
-- ============================================================================
CREATE OR REPLACE VIEW v_category_hierarchy AS
WITH RECURSIVE category_tree AS (
    -- 根分类
    SELECT 
        c.id,
        c.name,
        c.parent_id,
        c.color,
        c.icon,
        c.classification,
        c.usage_count,
        0 as depth,
        ARRAY[c.id] as path,
        c.name as full_path
    FROM categories c
    WHERE c.parent_id IS NULL AND c.deleted_at IS NULL
    
    UNION ALL
    
    -- 子分类
    SELECT 
        c.id,
        c.name,
        c.parent_id,
        c.color,
        c.icon,
        c.classification,
        c.usage_count,
        ct.depth + 1,
        ct.path || c.id,
        ct.full_path || ' > ' || c.name
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_id = ct.id
    WHERE c.deleted_at IS NULL
)
SELECT * FROM category_tree;

-- ============================================================================
-- 11. 创建函数 - 获取分类推荐
-- ============================================================================
CREATE OR REPLACE FUNCTION get_category_suggestions(
    p_description TEXT,
    p_user_id UUID,
    p_ledger_id UUID,
    p_limit INT DEFAULT 5
)
RETURNS TABLE (
    category_id UUID,
    category_name VARCHAR,
    confidence_score FLOAT,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH keyword_matches AS (
        -- 基于关键词匹配
        SELECT 
            c.id,
            c.name,
            0.8 as score,
            '关键词匹配' as reason
        FROM categories c
        WHERE c.ledger_id = p_ledger_id
            AND c.deleted_at IS NULL
            AND c.is_active = true
            AND (
                p_description ILIKE '%' || c.name || '%'
                OR c.name ILIKE '%' || p_description || '%'
            )
    ),
    frequent_categories AS (
        -- 基于使用频率
        SELECT 
            c.id,
            c.name,
            0.6 as score,
            '常用分类' as reason
        FROM categories c
        INNER JOIN category_usage_stats s ON c.id = s.category_id
        WHERE s.user_id = p_user_id
            AND s.ledger_id = p_ledger_id
            AND c.deleted_at IS NULL
            AND c.is_active = true
        ORDER BY s.usage_count DESC
        LIMIT 3
    ),
    recent_categories AS (
        -- 基于最近使用
        SELECT 
            c.id,
            c.name,
            0.5 as score,
            '最近使用' as reason
        FROM categories c
        WHERE c.ledger_id = p_ledger_id
            AND c.deleted_at IS NULL
            AND c.is_active = true
            AND c.last_used_at IS NOT NULL
        ORDER BY c.last_used_at DESC
        LIMIT 3
    )
    -- 合并结果
    SELECT DISTINCT ON (id)
        id as category_id,
        name as category_name,
        MAX(score) as confidence_score,
        MAX(reason) as reason
    FROM (
        SELECT * FROM keyword_matches
        UNION ALL
        SELECT * FROM frequent_categories
        UNION ALL
        SELECT * FROM recent_categories
    ) suggestions
    GROUP BY id, name
    ORDER BY id, MAX(score) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 12. 权限设置
-- ============================================================================
GRANT SELECT ON category_groups TO authenticated;
GRANT SELECT ON system_category_templates TO authenticated;
GRANT ALL ON categories TO authenticated;
GRANT ALL ON category_batch_operations TO authenticated;
GRANT ALL ON category_conversions TO authenticated;
GRANT ALL ON category_usage_stats TO authenticated;
GRANT SELECT ON v_category_hierarchy TO authenticated;
GRANT EXECUTE ON FUNCTION get_category_suggestions TO authenticated;

-- ============================================================================
-- 更新时间戳触发器
-- ============================================================================
CREATE TRIGGER update_category_groups_updated_at
    BEFORE UPDATE ON category_groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_category_templates_updated_at
    BEFORE UPDATE ON system_category_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 结束
-- ============================================================================