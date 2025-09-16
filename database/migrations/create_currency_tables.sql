-- 创建货币相关的表结构
-- Create currency-related tables for Jive Money

-- 1. 货币基础表
CREATE TABLE IF NOT EXISTS currencies (
    code VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    name_zh VARCHAR(100),
    symbol VARCHAR(10),
    decimal_places INT DEFAULT 2,
    is_active BOOLEAN DEFAULT true,
    is_crypto BOOLEAN DEFAULT false,
    flag VARCHAR(10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. 汇率表
CREATE TABLE IF NOT EXISTS exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency VARCHAR(10) NOT NULL,
    to_currency VARCHAR(10) NOT NULL,
    rate DECIMAL(20, 10) NOT NULL,
    source VARCHAR(50) DEFAULT 'manual',
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_currency, to_currency, date)
);

-- 3. 用户货币偏好表
CREATE TABLE IF NOT EXISTS user_currency_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    currency_code VARCHAR(10) NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, currency_code)
);

-- 4. 家庭货币设置表
CREATE TABLE IF NOT EXISTS family_currency_settings (
    family_id UUID PRIMARY KEY,
    base_currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    allow_multi_currency BOOLEAN DEFAULT true,
    auto_convert BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_exchange_rates_from_to ON exchange_rates(from_currency, to_currency);
CREATE INDEX idx_exchange_rates_date ON exchange_rates(effective_date);
CREATE INDEX idx_user_currency_preferences_user ON user_currency_preferences(user_id);
CREATE INDEX idx_currencies_active ON currencies(is_active);

-- 插入常用法定货币
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, flag) VALUES
-- 主要货币
('USD', 'US Dollar', '美元', '$', 2, true, false, '🇺🇸'),
('EUR', 'Euro', '欧元', '€', 2, true, false, '🇪🇺'),
('GBP', 'British Pound', '英镑', '£', 2, true, false, '🇬🇧'),
('JPY', 'Japanese Yen', '日元', '¥', 0, true, false, '🇯🇵'),
('CNY', 'Chinese Yuan', '人民币', '¥', 2, true, false, '🇨🇳'),
('CHF', 'Swiss Franc', '瑞士法郎', 'CHF', 2, true, false, '🇨🇭'),
('CAD', 'Canadian Dollar', '加拿大元', '$', 2, true, false, '🇨🇦'),
('AUD', 'Australian Dollar', '澳大利亚元', '$', 2, true, false, '🇦🇺'),
('NZD', 'New Zealand Dollar', '新西兰元', '$', 2, true, false, '🇳🇿'),
('HKD', 'Hong Kong Dollar', '港元', '$', 2, true, false, '🇭🇰'),
('SGD', 'Singapore Dollar', '新加坡元', '$', 2, true, false, '🇸🇬'),
('KRW', 'South Korean Won', '韩元', '₩', 0, true, false, '🇰🇷'),
('SEK', 'Swedish Krona', '瑞典克朗', 'kr', 2, true, false, '🇸🇪'),
('NOK', 'Norwegian Krone', '挪威克朗', 'kr', 2, true, false, '🇳🇴'),
('DKK', 'Danish Krone', '丹麦克朗', 'kr', 2, true, false, '🇩🇰'),
('PLN', 'Polish Zloty', '波兰兹罗提', 'zł', 2, true, false, '🇵🇱'),
('CZK', 'Czech Koruna', '捷克克朗', 'Kč', 2, true, false, '🇨🇿'),
('HUF', 'Hungarian Forint', '匈牙利福林', 'Ft', 2, true, false, '🇭🇺'),
('RUB', 'Russian Ruble', '俄罗斯卢布', '₽', 2, true, false, '🇷🇺'),
('INR', 'Indian Rupee', '印度卢比', '₹', 2, true, false, '🇮🇳'),
('BRL', 'Brazilian Real', '巴西雷亚尔', 'R$', 2, true, false, '🇧🇷'),
('MXN', 'Mexican Peso', '墨西哥比索', '$', 2, true, false, '🇲🇽'),
('ZAR', 'South African Rand', '南非兰特', 'R', 2, true, false, '🇿🇦'),
('TRY', 'Turkish Lira', '土耳其里拉', '₺', 2, true, false, '🇹🇷'),
('AED', 'UAE Dirham', '阿联酋迪拉姆', 'د.إ', 2, true, false, '🇦🇪'),
('SAR', 'Saudi Riyal', '沙特里亚尔', '﷼', 2, true, false, '🇸🇦'),
('THB', 'Thai Baht', '泰铢', '฿', 2, true, false, '🇹🇭'),
('MYR', 'Malaysian Ringgit', '马来西亚林吉特', 'RM', 2, true, false, '🇲🇾'),
('IDR', 'Indonesian Rupiah', '印尼盾', 'Rp', 2, true, false, '🇮🇩'),
('PHP', 'Philippine Peso', '菲律宾比索', '₱', 2, true, false, '🇵🇭'),
('VND', 'Vietnamese Dong', '越南盾', '₫', 0, true, false, '🇻🇳'),
('TWD', 'Taiwan Dollar', '新台币', 'NT$', 2, true, false, '🇹🇼')
ON CONFLICT (code) DO NOTHING;

-- 插入主要加密货币
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, flag) VALUES
('BTC', 'Bitcoin', '比特币', '₿', 8, true, true, '₿'),
('ETH', 'Ethereum', '以太坊', 'Ξ', 8, true, true, 'Ξ'),
('USDT', 'Tether', '泰达币', '₮', 6, true, true, '₮'),
('BNB', 'Binance Coin', '币安币', 'BNB', 8, true, true, '🔸'),
('SOL', 'Solana', 'Solana', 'SOL', 6, true, true, '◎'),
('XRP', 'XRP', '瑞波币', 'XRP', 6, true, true, '✕'),
('USDC', 'USD Coin', 'USD币', 'USDC', 6, true, true, '💵'),
('ADA', 'Cardano', '卡尔达诺', '₳', 6, true, true, '₳'),
('AVAX', 'Avalanche', '雪崩', 'AVAX', 8, true, true, '🔺'),
('DOGE', 'Dogecoin', '狗狗币', 'DOGE', 8, true, true, '🐕')
ON CONFLICT (code) DO NOTHING;

-- 插入一些基础汇率（CNY为基准）
INSERT INTO exchange_rates (from_currency, to_currency, rate, source, date, effective_date) VALUES
('CNY', 'USD', 0.1380, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'EUR', 0.1276, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'GBP', 0.1093, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'JPY', 20.3551, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'HKD', 1.0768, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'SGD', 0.1859, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'AUD', 0.2111, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'CAD', 0.1874, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'CHF', 0.1217, 'initial', CURRENT_DATE, CURRENT_DATE),
('CNY', 'KRW', 181.9431, 'initial', CURRENT_DATE, CURRENT_DATE),
('USD', 'CNY', 7.2462, 'initial', CURRENT_DATE, CURRENT_DATE),
('USD', 'EUR', 0.9246, 'initial', CURRENT_DATE, CURRENT_DATE),
('USD', 'GBP', 0.7922, 'initial', CURRENT_DATE, CURRENT_DATE),
('USD', 'JPY', 147.5234, 'initial', CURRENT_DATE, CURRENT_DATE),
('EUR', 'CNY', 7.8368, 'initial', CURRENT_DATE, CURRENT_DATE),
('EUR', 'USD', 1.0817, 'initial', CURRENT_DATE, CURRENT_DATE),
('GBP', 'CNY', 9.1511, 'initial', CURRENT_DATE, CURRENT_DATE),
('GBP', 'USD', 1.2625, 'initial', CURRENT_DATE, CURRENT_DATE),
('JPY', 'CNY', 0.0491, 'initial', CURRENT_DATE, CURRENT_DATE),
('JPY', 'USD', 0.0068, 'initial', CURRENT_DATE, CURRENT_DATE)
ON CONFLICT (from_currency, to_currency, date) DO NOTHING;

-- 为现有家庭创建默认货币设置
INSERT INTO family_currency_settings (family_id, base_currency, allow_multi_currency, auto_convert)
SELECT DISTINCT f.id, 'CNY', true, false
FROM families f
WHERE NOT EXISTS (
    SELECT 1 FROM family_currency_settings fcs WHERE fcs.family_id = f.id
);

-- 为现有用户创建默认货币偏好
INSERT INTO user_currency_preferences (user_id, currency_code, is_primary, display_order)
SELECT DISTINCT u.id, 'CNY', true, 0
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_currency_preferences ucp WHERE ucp.user_id = u.id
);

-- 添加更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_currencies_updated_at BEFORE UPDATE ON currencies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_exchange_rates_updated_at BEFORE UPDATE ON exchange_rates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_currency_preferences_updated_at BEFORE UPDATE ON user_currency_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_family_currency_settings_updated_at BEFORE UPDATE ON family_currency_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();