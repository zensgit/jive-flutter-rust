-- 修复货币表结构和数据
-- Fix currency tables structure and insert data

-- 添加缺失的列（如果不存在）
ALTER TABLE currencies 
ADD COLUMN IF NOT EXISTS name_zh VARCHAR(100),
ADD COLUMN IF NOT EXISTS is_crypto BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS flag VARCHAR(10);

-- 插入常用法定货币（使用简化版本，匹配现有表结构）
INSERT INTO currencies (code, name, symbol, decimal_places, is_active) VALUES
-- 主要货币
('USD', 'US Dollar', '$', 2, true),
('EUR', 'Euro', '€', 2, true),
('GBP', 'British Pound', '£', 2, true),
('JPY', 'Japanese Yen', '¥', 0, true),
('CNY', 'Chinese Yuan', '¥', 2, true),
('CHF', 'Swiss Franc', 'CHF', 2, true),
('CAD', 'Canadian Dollar', '$', 2, true),
('AUD', 'Australian Dollar', '$', 2, true),
('NZD', 'New Zealand Dollar', '$', 2, true),
('HKD', 'Hong Kong Dollar', '$', 2, true),
('SGD', 'Singapore Dollar', '$', 2, true),
('KRW', 'South Korean Won', '₩', 0, true),
('SEK', 'Swedish Krona', 'kr', 2, true),
('NOK', 'Norwegian Krone', 'kr', 2, true),
('DKK', 'Danish Krone', 'kr', 2, true),
('PLN', 'Polish Zloty', 'zł', 2, true),
('CZK', 'Czech Koruna', 'Kč', 2, true),
('HUF', 'Hungarian Forint', 'Ft', 2, true),
('RUB', 'Russian Ruble', '₽', 2, true),
('INR', 'Indian Rupee', '₹', 2, true),
('BRL', 'Brazilian Real', 'R$', 2, true),
('MXN', 'Mexican Peso', '$', 2, true),
('ZAR', 'South African Rand', 'R', 2, true),
('TRY', 'Turkish Lira', '₺', 2, true),
('AED', 'UAE Dirham', 'د.إ', 2, true),
('SAR', 'Saudi Riyal', '﷼', 2, true),
('THB', 'Thai Baht', '฿', 2, true),
('MYR', 'Malaysian Ringgit', 'RM', 2, true),
('IDR', 'Indonesian Rupiah', 'Rp', 2, true),
('PHP', 'Philippine Peso', '₱', 2, true),
('VND', 'Vietnamese Dong', '₫', 0, true),
('TWD', 'Taiwan Dollar', 'NT$', 2, true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active;

-- 更新中文名称和国旗
UPDATE currencies SET name_zh = '美元', flag = '🇺🇸' WHERE code = 'USD';
UPDATE currencies SET name_zh = '欧元', flag = '🇪🇺' WHERE code = 'EUR';
UPDATE currencies SET name_zh = '英镑', flag = '🇬🇧' WHERE code = 'GBP';
UPDATE currencies SET name_zh = '日元', flag = '🇯🇵' WHERE code = 'JPY';
UPDATE currencies SET name_zh = '人民币', flag = '🇨🇳' WHERE code = 'CNY';
UPDATE currencies SET name_zh = '瑞士法郎', flag = '🇨🇭' WHERE code = 'CHF';
UPDATE currencies SET name_zh = '加拿大元', flag = '🇨🇦' WHERE code = 'CAD';
UPDATE currencies SET name_zh = '澳大利亚元', flag = '🇦🇺' WHERE code = 'AUD';
UPDATE currencies SET name_zh = '新西兰元', flag = '🇳🇿' WHERE code = 'NZD';
UPDATE currencies SET name_zh = '港元', flag = '🇭🇰' WHERE code = 'HKD';
UPDATE currencies SET name_zh = '新加坡元', flag = '🇸🇬' WHERE code = 'SGD';
UPDATE currencies SET name_zh = '韩元', flag = '🇰🇷' WHERE code = 'KRW';
UPDATE currencies SET name_zh = '瑞典克朗', flag = '🇸🇪' WHERE code = 'SEK';
UPDATE currencies SET name_zh = '挪威克朗', flag = '🇳🇴' WHERE code = 'NOK';
UPDATE currencies SET name_zh = '丹麦克朗', flag = '🇩🇰' WHERE code = 'DKK';
UPDATE currencies SET name_zh = '波兰兹罗提', flag = '🇵🇱' WHERE code = 'PLN';
UPDATE currencies SET name_zh = '捷克克朗', flag = '🇨🇿' WHERE code = 'CZK';
UPDATE currencies SET name_zh = '匈牙利福林', flag = '🇭🇺' WHERE code = 'HUF';
UPDATE currencies SET name_zh = '俄罗斯卢布', flag = '🇷🇺' WHERE code = 'RUB';
UPDATE currencies SET name_zh = '印度卢比', flag = '🇮🇳' WHERE code = 'INR';
UPDATE currencies SET name_zh = '巴西雷亚尔', flag = '🇧🇷' WHERE code = 'BRL';
UPDATE currencies SET name_zh = '墨西哥比索', flag = '🇲🇽' WHERE code = 'MXN';
UPDATE currencies SET name_zh = '南非兰特', flag = '🇿🇦' WHERE code = 'ZAR';
UPDATE currencies SET name_zh = '土耳其里拉', flag = '🇹🇷' WHERE code = 'TRY';
UPDATE currencies SET name_zh = '阿联酋迪拉姆', flag = '🇦🇪' WHERE code = 'AED';
UPDATE currencies SET name_zh = '沙特里亚尔', flag = '🇸🇦' WHERE code = 'SAR';
UPDATE currencies SET name_zh = '泰铢', flag = '🇹🇭' WHERE code = 'THB';
UPDATE currencies SET name_zh = '马来西亚林吉特', flag = '🇲🇾' WHERE code = 'MYR';
UPDATE currencies SET name_zh = '印尼盾', flag = '🇮🇩' WHERE code = 'IDR';
UPDATE currencies SET name_zh = '菲律宾比索', flag = '🇵🇭' WHERE code = 'PHP';
UPDATE currencies SET name_zh = '越南盾', flag = '🇻🇳' WHERE code = 'VND';
UPDATE currencies SET name_zh = '新台币', flag = '🇹🇼' WHERE code = 'TWD';

-- 插入主要加密货币
INSERT INTO currencies (code, name, symbol, decimal_places, is_active, is_crypto) VALUES
('BTC', 'Bitcoin', '₿', 8, true, true),
('ETH', 'Ethereum', 'Ξ', 8, true, true),
('USDT', 'Tether', '₮', 6, true, true),
('BNB', 'Binance Coin', 'BNB', 8, true, true),
('SOL', 'Solana', 'SOL', 6, true, true),
('XRP', 'XRP', 'XRP', 6, true, true),
('USDC', 'USD Coin', 'USDC', 6, true, true),
('ADA', 'Cardano', '₳', 6, true, true),
('AVAX', 'Avalanche', 'AVAX', 8, true, true),
('DOGE', 'Dogecoin', 'DOGE', 8, true, true)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active,
    is_crypto = EXCLUDED.is_crypto;

-- 更新加密货币的中文名称
UPDATE currencies SET name_zh = '比特币', flag = '₿' WHERE code = 'BTC';
UPDATE currencies SET name_zh = '以太坊', flag = 'Ξ' WHERE code = 'ETH';
UPDATE currencies SET name_zh = '泰达币', flag = '₮' WHERE code = 'USDT';
UPDATE currencies SET name_zh = '币安币', flag = '🔸' WHERE code = 'BNB';
UPDATE currencies SET name_zh = 'Solana', flag = '◎' WHERE code = 'SOL';
UPDATE currencies SET name_zh = '瑞波币', flag = '✕' WHERE code = 'XRP';
UPDATE currencies SET name_zh = 'USD币', flag = '💵' WHERE code = 'USDC';
UPDATE currencies SET name_zh = '卡尔达诺', flag = '₳' WHERE code = 'ADA';
UPDATE currencies SET name_zh = '雪崩', flag = '🔺' WHERE code = 'AVAX';
UPDATE currencies SET name_zh = '狗狗币', flag = '🐕' WHERE code = 'DOGE';

-- 检查并修复exchange_rates表结构
ALTER TABLE exchange_rates 
ALTER COLUMN created_at SET DEFAULT CURRENT_TIMESTAMP,
ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;

-- 插入基础汇率（CNY为基准）
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
ON CONFLICT (from_currency, to_currency, date) DO UPDATE SET
    rate = EXCLUDED.rate,
    source = EXCLUDED.source,
    effective_date = EXCLUDED.effective_date;

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