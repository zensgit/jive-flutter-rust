-- 创建货币表
CREATE TABLE IF NOT EXISTS currencies (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    decimal_places INTEGER DEFAULT 2,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建汇率表
CREATE TABLE IF NOT EXISTS exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency VARCHAR(10) NOT NULL REFERENCES currencies(code),
    to_currency VARCHAR(10) NOT NULL REFERENCES currencies(code),
    rate DECIMAL(20, 10) NOT NULL,
    source VARCHAR(50) DEFAULT 'manual', -- manual, api, bank
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_currency, to_currency, effective_date)
);

-- 创建用户货币偏好表（每个用户可以设置多个常用货币）
CREATE TABLE IF NOT EXISTS user_currency_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    currency_code VARCHAR(10) NOT NULL REFERENCES currencies(code),
    is_primary BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, currency_code)
);

-- 创建家庭货币设置表
CREATE TABLE IF NOT EXISTS family_currency_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    base_currency VARCHAR(10) NOT NULL REFERENCES currencies(code),
    allow_multi_currency BOOLEAN DEFAULT true,
    auto_convert BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(family_id)
);

-- 插入常用货币
INSERT INTO currencies (code, name, symbol, decimal_places) VALUES
    ('CNY', '人民币', '¥', 2),
    ('USD', '美元', '$', 2),
    ('EUR', '欧元', '€', 2),
    ('GBP', '英镑', '£', 2),
    ('JPY', '日元', '¥', 0),
    ('HKD', '港币', 'HK$', 2),
    ('TWD', '台币', 'NT$', 2),
    ('SGD', '新加坡元', 'S$', 2),
    ('AUD', '澳元', 'A$', 2),
    ('CAD', '加元', 'C$', 2),
    ('CHF', '瑞士法郎', 'CHF', 2),
    ('KRW', '韩元', '₩', 0),
    ('INR', '印度卢比', '₹', 2),
    ('THB', '泰铢', '฿', 2),
    ('MYR', '马来西亚令吉', 'RM', 2)
ON CONFLICT (code) DO NOTHING;

-- 插入示例汇率（以CNY为基准）
INSERT INTO exchange_rates (from_currency, to_currency, rate, source) VALUES
    ('CNY', 'USD', 0.1380, 'manual'),
    ('USD', 'CNY', 7.2464, 'manual'),
    ('CNY', 'EUR', 0.1266, 'manual'),
    ('EUR', 'CNY', 7.8994, 'manual'),
    ('CNY', 'GBP', 0.1089, 'manual'),
    ('GBP', 'CNY', 9.1827, 'manual'),
    ('CNY', 'JPY', 20.3551, 'manual'),
    ('JPY', 'CNY', 0.0491, 'manual'),
    ('CNY', 'HKD', 1.0784, 'manual'),
    ('HKD', 'CNY', 0.9273, 'manual'),
    ('USD', 'EUR', 0.9176, 'manual'),
    ('EUR', 'USD', 1.0898, 'manual')
ON CONFLICT (from_currency, to_currency, effective_date) DO NOTHING;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_exchange_rates_currencies ON exchange_rates(from_currency, to_currency);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_date ON exchange_rates(effective_date);
CREATE INDEX IF NOT EXISTS idx_user_currency_preferences_user ON user_currency_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_family_currency_settings_family ON family_currency_settings(family_id);

-- 添加注释
COMMENT ON TABLE currencies IS '支持的货币列表';
COMMENT ON TABLE exchange_rates IS '汇率表';
COMMENT ON TABLE user_currency_preferences IS '用户货币偏好设置';
COMMENT ON TABLE family_currency_settings IS '家庭多币种设置';