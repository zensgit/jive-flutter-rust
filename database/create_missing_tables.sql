-- 创建缺失的表以支持多货币功能

-- 1. 货币表
CREATE TABLE IF NOT EXISTS currencies (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(10),
    decimal_places INT DEFAULT 2,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 用户货币偏好表
CREATE TABLE IF NOT EXISTS user_currency_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    currency_code VARCHAR(10) NOT NULL REFERENCES currencies(code),
    is_primary BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, currency_code)
);

-- 3. 家庭货币设置表
CREATE TABLE IF NOT EXISTS family_currency_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    base_currency VARCHAR(10) NOT NULL,
    allow_multi_currency BOOLEAN DEFAULT false,
    auto_convert BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_id)
);

-- 4. 汇率表 (修改以包含缺失的列)
ALTER TABLE exchange_rates ADD COLUMN IF NOT EXISTS source VARCHAR(50);
ALTER TABLE exchange_rates ADD COLUMN IF NOT EXISTS effective_date DATE;

-- 5. 初始化一些基本货币
INSERT INTO currencies (code, name, symbol, decimal_places, is_active) VALUES
('USD', 'US Dollar', '$', 2, true),
('EUR', 'Euro', '€', 2, true),
('GBP', 'British Pound', '£', 2, true),
('CNY', 'Chinese Yuan', '¥', 2, true),
('JPY', 'Japanese Yen', '¥', 0, true),
('HKD', 'Hong Kong Dollar', 'HK$', 2, true),
('SGD', 'Singapore Dollar', 'S$', 2, true),
('AUD', 'Australian Dollar', 'A$', 2, true),
('CAD', 'Canadian Dollar', 'C$', 2, true),
('CHF', 'Swiss Franc', 'Fr', 2, true)
ON CONFLICT (code) DO NOTHING;

-- 6. 创建索引
CREATE INDEX IF NOT EXISTS idx_user_currency_preferences_user_id ON user_currency_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_family_currency_settings_family_id ON family_currency_settings(family_id);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_effective_date ON exchange_rates(effective_date);