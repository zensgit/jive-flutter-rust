-- Jive Money 数据库架构设计
-- 专为Jive财务管理系统设计的完整数据库结构
-- 基于PostgreSQL，支持多账本、分类系统、预算、投资等功能

-- =====================================================
-- 扩展和基础配置
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "plpgsql";

-- 创建枚举类型
CREATE TYPE account_status AS ENUM ('active', 'syncing', 'error', 'disabled');
CREATE TYPE transaction_status AS ENUM ('pending', 'cleared', 'reconciled');
CREATE TYPE classification_type AS ENUM ('income', 'expense', 'transfer');
CREATE TYPE category_source AS ENUM ('custom', 'template', 'system');
CREATE TYPE batch_operation_type AS ENUM ('recategorize', 'convert', 'merge', 'delete');

-- =====================================================
-- 用户和认证相关表
-- =====================================================

-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200),
    phone VARCHAR(50),
    avatar_url TEXT,
    
    -- 认证相关
    email_verified BOOLEAN DEFAULT FALSE,
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    
    -- 状态和角色
    status VARCHAR(20) DEFAULT 'active',
    role VARCHAR(20) DEFAULT 'user',
    
    -- 偏好设置
    preferences JSONB DEFAULT '{}',
    
    -- 时间戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- 家庭/组织表
CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    currency VARCHAR(3) DEFAULT 'CNY',
    timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
    locale VARCHAR(10) DEFAULT 'zh-CN',
    
    -- 设置
    settings JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 家庭成员关系表
CREATE TABLE family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(family_id, user_id)
);

-- 用户会话表
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    refresh_token_hash VARCHAR(255) UNIQUE,
    
    device_info JSONB,
    ip_address INET,
    user_agent TEXT,
    
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 账本系统
-- =====================================================

-- 账本表
CREATE TABLE ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- 账本类型和设置
    ledger_type VARCHAR(20) DEFAULT 'personal',
    currency VARCHAR(3) DEFAULT 'CNY',
    color VARCHAR(7) DEFAULT '#3B82F6',
    icon VARCHAR(50),
    
    -- 状态
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- 设置
    settings JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_ledgers_family (family_id),
    INDEX idx_ledgers_active (is_active)
);

-- 账本成员权限表
CREATE TABLE ledger_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission VARCHAR(20) DEFAULT 'viewer',
    
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(ledger_id, user_id)
);

-- =====================================================
-- 分类系统增强版
-- =====================================================

-- 分类组表
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

-- 系统分类模板表
CREATE TABLE system_category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    
    -- 分类属性
    classification classification_type NOT NULL,
    color VARCHAR(7) NOT NULL,
    icon VARCHAR(50),
    category_group VARCHAR(50) REFERENCES category_groups(key),
    
    -- 元数据
    version VARCHAR(20) DEFAULT '1.0',
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    global_usage_count INTEGER DEFAULT 0,
    tags TEXT[],
    
    -- 审计字段
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 用户分类表（增强版）
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    
    -- 基础信息
    name VARCHAR(200) NOT NULL,
    description TEXT,
    classification classification_type NOT NULL,
    color VARCHAR(7) NOT NULL,
    icon VARCHAR(50),
    
    -- 位置和状态
    position INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- 来源和模板信息
    source_type category_source DEFAULT 'custom',
    template_id UUID REFERENCES system_category_templates(id),
    template_version VARCHAR(20),
    
    -- 统计信息
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP WITH TIME ZONE,
    
    -- 审计字段
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_categories_ledger (ledger_id),
    INDEX idx_categories_parent (parent_id),
    INDEX idx_categories_template (template_id),
    INDEX idx_categories_position (ledger_id, position),
    INDEX idx_categories_usage (usage_count DESC),
    INDEX idx_categories_source (source_type)
);

-- 分类批量操作记录表
CREATE TABLE category_batch_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    operation_type batch_operation_type NOT NULL,
    
    -- 操作数据
    original_data JSONB NOT NULL,
    affected_transactions INTEGER DEFAULT 0,
    
    -- 撤销支持
    can_revert BOOLEAN DEFAULT TRUE,
    reverted_at TIMESTAMP WITH TIME ZONE,
    
    -- 过期时间
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '24 hours'),
    
    INDEX idx_batch_ops_user_created (user_id, created_at DESC),
    INDEX idx_batch_ops_expires (expires_at)
);

-- =====================================================
-- 账户系统
-- =====================================================

-- 账户表
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 账户类型和属性
    account_type VARCHAR(30) NOT NULL,
    account_number VARCHAR(100),
    institution_name VARCHAR(200),
    currency VARCHAR(3) DEFAULT 'CNY',
    
    -- 余额信息
    current_balance DECIMAL(19,4) DEFAULT 0,
    available_balance DECIMAL(19,4),
    credit_limit DECIMAL(19,4),
    
    -- 状态
    status account_status DEFAULT 'active',
    is_manual BOOLEAN DEFAULT TRUE,
    
    -- 外观设置
    color VARCHAR(7),
    icon VARCHAR(50),
    notes TEXT,
    
    -- 元数据
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_accounts_ledger (ledger_id),
    INDEX idx_accounts_type (account_type),
    INDEX idx_accounts_status (status)
);

-- 账户余额历史
CREATE TABLE account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    balance DECIMAL(19,4) NOT NULL,
    balance_date DATE NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(account_id, balance_date)
);

-- =====================================================
-- 交易系统
-- =====================================================

-- 收款人/商家表
CREATE TABLE payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 商家信息
    logo_url TEXT,
    website TEXT,
    phone VARCHAR(50),
    address TEXT,
    
    -- 默认设置
    default_category_id UUID REFERENCES categories(id),
    
    -- 统计
    transaction_count INTEGER DEFAULT 0,
    total_amount DECIMAL(19,4) DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_payees_ledger (ledger_id),
    INDEX idx_payees_name (name)
);

-- 标签表
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(ledger_id, name)
);

-- 交易表
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    
    -- 金额和日期
    amount DECIMAL(19,4) NOT NULL,
    transaction_date DATE NOT NULL,
    posted_date DATE,
    
    -- 分类和商家
    category_id UUID REFERENCES categories(id),
    payee_id UUID REFERENCES payees(id),
    payee_name VARCHAR(200),
    
    -- 描述
    description TEXT,
    notes TEXT,
    
    -- 类型和状态
    transaction_type classification_type DEFAULT 'expense',
    status transaction_status DEFAULT 'cleared',
    
    -- 特殊标记
    is_transfer BOOLEAN DEFAULT FALSE,
    transfer_pair_id UUID,
    is_reimbursable BOOLEAN DEFAULT FALSE,
    is_recurring BOOLEAN DEFAULT FALSE,
    parent_id UUID REFERENCES transactions(id),
    
    -- 位置信息
    location JSONB,
    
    -- 元数据
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_transactions_account (account_id),
    INDEX idx_transactions_date (transaction_date),
    INDEX idx_transactions_category (category_id),
    INDEX idx_transactions_payee (payee_id),
    INDEX idx_transactions_type (transaction_type),
    INDEX idx_transactions_account_date (account_id, transaction_date DESC)
);

-- 交易标签关系表
CREATE TABLE transaction_tags (
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    
    PRIMARY KEY (transaction_id, tag_id)
);

-- 交易附件表
CREATE TABLE transaction_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(100),
    
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 预算系统
-- =====================================================

-- 预算表
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 预算周期
    period_type VARCHAR(20) DEFAULT 'monthly',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- 预算金额
    total_amount DECIMAL(19,4),
    
    -- 设置
    alert_threshold DECIMAL(5,2) DEFAULT 0.8,
    rollover_enabled BOOLEAN DEFAULT FALSE,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_budgets_ledger (ledger_id),
    INDEX idx_budgets_period (period_start, period_end)
);

-- 预算项表
CREATE TABLE budget_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    
    budgeted_amount DECIMAL(19,4) NOT NULL,
    spent_amount DECIMAL(19,4) DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(budget_id, category_id)
);

-- =====================================================
-- 通知系统
-- =====================================================

-- 通知表
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 通知内容
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    
    -- 状态
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- 相关数据
    related_entity_type VARCHAR(50),
    related_entity_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_notifications_user (user_id),
    INDEX idx_notifications_unread (user_id, is_read),
    INDEX idx_notifications_created (created_at)
);

-- =====================================================
-- 触发器和函数
-- =====================================================

-- 更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 分类使用统计更新函数
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

-- 为所有需要的表创建更新触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_families_updated_at BEFORE UPDATE ON families
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ledgers_updated_at BEFORE UPDATE ON ledgers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_category_groups_updated_at BEFORE UPDATE ON category_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_category_templates_updated_at BEFORE UPDATE ON system_category_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 为交易表添加分类使用统计触发器
CREATE TRIGGER update_category_usage_on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW 
    WHEN (pg_trigger_depth() = 0)  -- 防止递归触发
    EXECUTE FUNCTION update_category_usage_count();

-- =====================================================
-- 视图
-- =====================================================

-- 分类统计视图
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

-- 账户余额汇总视图
CREATE OR REPLACE VIEW account_summary AS
SELECT 
    a.id,
    a.name,
    a.account_type,
    a.current_balance,
    a.currency,
    l.name as ledger_name,
    l.family_id
FROM accounts a
JOIN ledgers l ON a.ledger_id = l.id
WHERE a.deleted_at IS NULL AND a.status = 'active';

-- =====================================================
-- 初始数据插入
-- =====================================================

-- 插入默认分类组
INSERT INTO category_groups (key, name, name_en, name_zh, display_order) VALUES
('income', '收入类别', 'Income', '收入类别', 1),
('daily_expense', '日常消费', 'Daily Expenses', '日常消费', 2),
('housing', '居住相关', 'Housing', '居住相关', 3),
('health_education', '健康教育', 'Health & Education', '健康教育', 4),
('entertainment_social', '娱乐社交', 'Entertainment & Social', '娱乐社交', 5),
('financial', '金融理财', 'Financial', '金融理财', 6),
('business', '商务办公', 'Business', '商务办公', 7);

-- 插入系统分类模板（收入类）
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('工资收入', 'Salary', '工资收入', 'income', '#10B981', 'circle-dollar-sign', 'income', TRUE, ARRAY['必备', '常用']),
('奖金收入', 'Bonus', '奖金收入', 'income', '#059669', 'award', 'income', FALSE, ARRAY['常用']),
('投资收益', 'Investment Returns', '投资收益', 'income', '#047857', 'trending-up', 'income', FALSE, ARRAY['理财']),
('副业收入', 'Side Business', '副业收入', 'income', '#065F46', 'briefcase', 'income', FALSE, ARRAY['创业']),
('租金收入', 'Rental Income', '租金收入', 'income', '#064E3B', 'home', 'income', FALSE, ARRAY['投资']),
('利息收入', 'Interest Income', '利息收入', 'income', '#022C22', 'percent', 'income', FALSE, ARRAY['理财']),
('其他收入', 'Other Income', '其他收入', 'income', '#052E16', 'plus-circle', 'income', FALSE, ARRAY['杂项']);

-- 插入系统分类模板（支出类）
INSERT INTO system_category_templates (name, name_en, name_zh, classification, color, icon, category_group, is_featured, tags) VALUES
('餐饮美食', 'Food & Dining', '餐饮美食', 'expense', '#EF4444', 'utensils', 'daily_expense', TRUE, ARRAY['热门', '必备']),
('交通出行', 'Transportation', '交通出行', 'expense', '#F97316', 'car', 'daily_expense', TRUE, ARRAY['热门', '必备']),
('购物消费', 'Shopping', '购物消费', 'expense', '#F59E0B', 'shopping-cart', 'daily_expense', TRUE, ARRAY['热门']),
('生活用品', 'Groceries', '生活用品', 'expense', '#EAB308', 'shopping-bag', 'daily_expense', FALSE, ARRAY['日常']),
('房租房贷', 'Rent & Mortgage', '房租房贷', 'expense', '#8B5A2B', 'home', 'housing', TRUE, ARRAY['必备']),
('水电煤气', 'Utilities', '水电煤气', 'expense', '#A16207', 'zap', 'housing', TRUE, ARRAY['必备']),
('医疗健康', 'Healthcare', '医疗健康', 'expense', '#DC2626', 'heart-pulse', 'health_education', TRUE, ARRAY['重要', '健康']),
('教育培训', 'Education', '教育培训', 'expense', '#0EA5E9', 'graduation-cap', 'health_education', FALSE, ARRAY['教育']),
('娱乐休闲', 'Entertainment', '娱乐休闲', 'expense', '#7C3AED', 'gamepad-2', 'entertainment_social', TRUE, ARRAY['热门']),
('旅游度假', 'Travel', '旅游度假', 'expense', '#5B21B6', 'plane', 'entertainment_social', FALSE, ARRAY['旅行']);

-- =====================================================
-- 索引优化
-- =====================================================

-- 复合索引
CREATE INDEX idx_categories_ledger_classification ON categories(ledger_id, classification);
CREATE INDEX idx_transactions_account_category ON transactions(account_id, category_id);
CREATE INDEX idx_transactions_date_category ON transactions(transaction_date, category_id);
CREATE INDEX idx_budget_items_category_spent ON budget_items(category_id, spent_amount);

-- 分区索引（如果数据量大）
-- CREATE INDEX CONCURRENTLY idx_transactions_date_partition ON transactions(transaction_date) 
--     WHERE deleted_at IS NULL;