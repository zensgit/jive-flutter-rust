-- Jive Money 数据库架构设计
-- 基于 Maybe 的数据库结构，适配 PostgreSQL 和 SQLite

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
    status VARCHAR(20) DEFAULT 'pending', -- pending, active, suspended, deleted
    role VARCHAR(20) DEFAULT 'member', -- super_admin, admin, member, guest
    
    -- 偏好设置 (JSON)
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
    fiscal_year_start INTEGER DEFAULT 1,
    
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
    role VARCHAR(20) DEFAULT 'member', -- owner, admin, member, viewer
    
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(family_id, user_id)
);

-- 会话表
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    refresh_token_hash VARCHAR(255) UNIQUE,
    
    device_info JSONB,
    ip_address INET,
    user_agent TEXT,
    
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_sessions_user_id (user_id),
    INDEX idx_sessions_expires_at (expires_at)
);

-- =====================================================
-- 账本相关表
-- =====================================================

-- 账本表
CREATE TABLE ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    ledger_type VARCHAR(20) DEFAULT 'personal', -- personal, family, business, project, travel, event
    
    -- 自定义
    color VARCHAR(7) DEFAULT '#3B82F6',
    icon VARCHAR(50),
    cover_image TEXT,
    description TEXT,
    
    -- 设置
    currency VARCHAR(3) DEFAULT 'CNY',
    settings JSONB DEFAULT '{}',
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_ledgers_family_id (family_id)
);

-- 账本成员权限表
CREATE TABLE ledger_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission VARCHAR(20) DEFAULT 'viewer', -- owner, admin, editor, viewer
    
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(ledger_id, user_id)
);

-- =====================================================
-- 账户相关表
-- =====================================================

-- 账户表
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    account_type VARCHAR(30) NOT NULL, -- checking, savings, credit_card, investment, crypto, loan, property, vehicle, prepaid_card, other_asset, other_liability
    
    -- 账户详情
    account_number VARCHAR(100),
    institution_name VARCHAR(200),
    currency VARCHAR(3) DEFAULT 'CNY',
    
    -- 余额
    current_balance DECIMAL(19,4) DEFAULT 0,
    available_balance DECIMAL(19,4),
    credit_limit DECIMAL(19,4),
    
    -- 状态
    status VARCHAR(20) DEFAULT 'active', -- draft, active, disabled, deleted
    is_manual BOOLEAN DEFAULT TRUE,
    
    -- 自定义
    color VARCHAR(7),
    icon VARCHAR(50),
    notes TEXT,
    
    -- 元数据
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_accounts_ledger_id (ledger_id),
    INDEX idx_accounts_type (account_type),
    INDEX idx_accounts_status (status)
);

-- 账户余额历史表
CREATE TABLE account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    balance DECIMAL(19,4) NOT NULL,
    balance_date DATE NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(account_id, balance_date),
    INDEX idx_balances_account_date (account_id, balance_date)
);

-- 账户分组表
CREATE TABLE account_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    color VARCHAR(7),
    icon VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 账户分组关系表
CREATE TABLE account_group_members (
    account_group_id UUID NOT NULL REFERENCES account_groups(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    display_order INTEGER DEFAULT 0,
    
    PRIMARY KEY (account_group_id, account_id)
);

-- =====================================================
-- 交易相关表
-- =====================================================

-- 交易表
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    
    -- 金额和日期
    amount DECIMAL(19,4) NOT NULL,
    transaction_date DATE NOT NULL,
    posted_date DATE,
    
    -- 分类和商家
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    payee_id UUID REFERENCES payees(id) ON DELETE SET NULL,
    payee_name VARCHAR(200),
    
    -- 描述
    description TEXT,
    notes TEXT,
    
    -- 类型和状态
    transaction_type VARCHAR(20) DEFAULT 'expense', -- income, expense, transfer, investment, refund
    status VARCHAR(20) DEFAULT 'cleared', -- pending, cleared, reconciled
    
    -- 特殊标记
    is_transfer BOOLEAN DEFAULT FALSE,
    transfer_pair_id UUID,
    is_reimbursable BOOLEAN DEFAULT FALSE,
    is_recurring BOOLEAN DEFAULT FALSE,
    parent_id UUID REFERENCES transactions(id) ON DELETE CASCADE, -- 用于拆分交易
    
    -- 位置信息
    location JSONB,
    
    -- 元数据
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    INDEX idx_transactions_account_id (account_id),
    INDEX idx_transactions_date (transaction_date),
    INDEX idx_transactions_category_id (category_id),
    INDEX idx_transactions_payee_id (payee_id),
    INDEX idx_transactions_type (transaction_type),
    INDEX idx_transactions_transfer_pair (transfer_pair_id)
);

-- 分类表
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID REFERENCES ledgers(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 自定义
    color VARCHAR(7),
    icon VARCHAR(50),
    
    -- 类型
    category_type VARCHAR(20) DEFAULT 'expense', -- income, expense, both
    
    display_order INTEGER DEFAULT 0,
    is_system BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_categories_ledger_id (ledger_id),
    INDEX idx_categories_parent_id (parent_id)
);

-- 商家/收款人表
CREATE TABLE payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 商家信息
    logo_url TEXT,
    website TEXT,
    phone VARCHAR(50),
    address TEXT,
    
    -- 默认分类
    default_category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    
    -- 统计
    transaction_count INTEGER DEFAULT 0,
    total_amount DECIMAL(19,4) DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_payees_ledger_id (ledger_id),
    INDEX idx_payees_name (name)
);

-- 标签表
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(ledger_id, name)
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
    
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_attachments_transaction_id (transaction_id)
);

-- =====================================================
-- 预算相关表
-- =====================================================

-- 预算表
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    
    -- 预算周期
    period_type VARCHAR(20) DEFAULT 'monthly', -- monthly, quarterly, yearly, custom
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- 预算金额
    total_amount DECIMAL(19,4),
    
    -- 设置
    alert_threshold DECIMAL(5,2) DEFAULT 0.8, -- 0.8 = 80%警告
    rollover_enabled BOOLEAN DEFAULT FALSE,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_budgets_ledger_id (ledger_id),
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
-- 投资相关表
-- =====================================================

-- 证券表
CREATE TABLE securities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(200) NOT NULL,
    security_type VARCHAR(20), -- stock, bond, fund, etf, crypto
    exchange VARCHAR(50),
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- 当前价格
    current_price DECIMAL(19,4),
    price_updated_at TIMESTAMP WITH TIME ZONE,
    
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(symbol, exchange)
);

-- 交易记录表
CREATE TABLE trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    security_id UUID NOT NULL REFERENCES securities(id) ON DELETE CASCADE,
    
    trade_type VARCHAR(20) NOT NULL, -- buy, sell, dividend, split
    trade_date DATE NOT NULL,
    quantity DECIMAL(19,8) NOT NULL,
    price DECIMAL(19,4) NOT NULL,
    fees DECIMAL(19,4) DEFAULT 0,
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_trades_account_id (account_id),
    INDEX idx_trades_security_id (security_id),
    INDEX idx_trades_date (trade_date)
);

-- 持仓表
CREATE TABLE holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    security_id UUID NOT NULL REFERENCES securities(id) ON DELETE CASCADE,
    
    quantity DECIMAL(19,8) NOT NULL,
    cost_basis DECIMAL(19,4) NOT NULL,
    current_value DECIMAL(19,4),
    
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(account_id, security_id)
);

-- =====================================================
-- 规则引擎相关表
-- =====================================================

-- 规则表
CREATE TABLE rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    priority INTEGER DEFAULT 0,
    
    -- 条件 (JSON)
    conditions JSONB NOT NULL,
    
    -- 动作 (JSON)
    actions JSONB NOT NULL,
    
    is_enabled BOOLEAN DEFAULT TRUE,
    
    -- 统计
    execution_count INTEGER DEFAULT 0,
    last_executed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_rules_ledger_id (ledger_id),
    INDEX idx_rules_priority (priority)
);

-- 规则执行日志表
CREATE TABLE rule_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
    
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    result VARCHAR(20), -- success, failed, skipped
    details JSONB,
    
    INDEX idx_rule_logs_rule_id (rule_id),
    INDEX idx_rule_logs_transaction_id (transaction_id)
);

-- =====================================================
-- 定时交易相关表
-- =====================================================

-- 定时交易表
CREATE TABLE scheduled_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    
    -- 交易信息
    amount DECIMAL(19,4) NOT NULL,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    payee_id UUID REFERENCES payees(id) ON DELETE SET NULL,
    description TEXT,
    
    -- 频率设置
    frequency VARCHAR(20) NOT NULL, -- daily, weekly, monthly, yearly, custom
    frequency_details JSONB, -- 详细的频率配置
    
    -- 执行设置
    start_date DATE NOT NULL,
    end_date DATE,
    next_execution_date DATE,
    
    auto_execute BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- 统计
    execution_count INTEGER DEFAULT 0,
    last_executed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_scheduled_ledger_id (ledger_id),
    INDEX idx_scheduled_next_date (next_execution_date)
);

-- =====================================================
-- 同步和导入相关表
-- =====================================================

-- 同步配置表
CREATE TABLE sync_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL, -- plaid, yodlee, manual
    
    -- 配置信息 (加密存储)
    credentials_encrypted TEXT,
    
    -- 同步设置
    sync_enabled BOOLEAN DEFAULT TRUE,
    sync_frequency VARCHAR(20) DEFAULT 'daily',
    
    -- 状态
    last_sync_at TIMESTAMP WITH TIME ZONE,
    last_sync_status VARCHAR(20),
    last_sync_error TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(account_id)
);

-- 导入任务表
CREATE TABLE imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL REFERENCES ledgers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 导入信息
    import_type VARCHAR(20) NOT NULL, -- csv, ofx, qif, json
    file_name VARCHAR(255),
    file_size INTEGER,
    
    -- 状态
    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed
    
    -- 统计
    total_rows INTEGER,
    imported_rows INTEGER,
    failed_rows INTEGER,
    
    -- 错误信息
    errors JSONB,
    
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_imports_ledger_id (ledger_id),
    INDEX idx_imports_user_id (user_id),
    INDEX idx_imports_status (status)
);

-- =====================================================
-- 通知相关表
-- =====================================================

-- 通知表
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 通知内容
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- budget_alert, transaction_alert, system, etc.
    
    -- 状态
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- 相关数据
    related_entity_type VARCHAR(50),
    related_entity_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_notifications_user_id (user_id),
    INDEX idx_notifications_is_read (is_read),
    INDEX idx_notifications_created_at (created_at)
);

-- =====================================================
-- 索引优化
-- =====================================================

-- 复合索引
CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date DESC);
CREATE INDEX idx_transactions_ledger_date ON transactions(account_id, transaction_date) 
    WHERE deleted_at IS NULL;
CREATE INDEX idx_categories_ledger_type ON categories(ledger_id, category_type);
CREATE INDEX idx_budget_items_spent ON budget_items(budget_id, spent_amount);

-- =====================================================
-- 触发器和函数
-- =====================================================

-- 自动更新 updated_at 时间戳
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为所有需要的表创建触发器
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_families_updated_at BEFORE UPDATE ON families
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ledgers_updated_at BEFORE UPDATE ON ledgers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 更多触发器...

-- =====================================================
-- 初始数据
-- =====================================================

-- 插入默认分类
INSERT INTO categories (id, name, category_type, icon, is_system) VALUES
    (gen_random_uuid(), '餐饮', 'expense', 'restaurant', true),
    (gen_random_uuid(), '交通', 'expense', 'directions_car', true),
    (gen_random_uuid(), '购物', 'expense', 'shopping_bag', true),
    (gen_random_uuid(), '娱乐', 'expense', 'sports_esports', true),
    (gen_random_uuid(), '医疗', 'expense', 'medical_services', true),
    (gen_random_uuid(), '教育', 'expense', 'school', true),
    (gen_random_uuid(), '住房', 'expense', 'home', true),
    (gen_random_uuid(), '工资', 'income', 'payments', true),
    (gen_random_uuid(), '奖金', 'income', 'card_giftcard', true),
    (gen_random_uuid(), '投资收益', 'income', 'trending_up', true),
    (gen_random_uuid(), '其他收入', 'income', 'monetization_on', true),
    (gen_random_uuid(), '其他支出', 'expense', 'more_horiz', true);