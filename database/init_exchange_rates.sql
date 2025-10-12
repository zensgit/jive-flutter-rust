-- 初始化汇率数据
-- 用于首次启动时提供基础汇率数据

-- 清理现有数据（可选）
-- TRUNCATE TABLE exchange_rates CASCADE;
-- TRUNCATE TABLE crypto_prices CASCADE;

-- 插入基础货币配置
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_crypto, is_active, flag, country_code, is_popular, display_order)
VALUES 
    -- 主要法定货币
    ('USD', 'US Dollar', '美元', '$', 2, false, true, '🇺🇸', 'US', true, 1),
    ('EUR', 'Euro', '欧元', '€', 2, false, true, '🇪🇺', 'EU', true, 2),
    ('CNY', 'Chinese Yuan', '人民币', '¥', 2, false, true, '🇨🇳', 'CN', true, 3),
    ('JPY', 'Japanese Yen', '日元', '¥', 0, false, true, '🇯🇵', 'JP', true, 4),
    ('GBP', 'British Pound', '英镑', '£', 2, false, true, '🇬🇧', 'GB', true, 5),
    ('HKD', 'Hong Kong Dollar', '港币', 'HK$', 2, false, true, '🇭🇰', 'HK', true, 6),
    ('SGD', 'Singapore Dollar', '新币', 'S$', 2, false, true, '🇸🇬', 'SG', true, 7),
    ('AUD', 'Australian Dollar', '澳元', 'A$', 2, false, true, '🇦🇺', 'AU', true, 8),
    ('CAD', 'Canadian Dollar', '加元', 'C$', 2, false, true, '🇨🇦', 'CA', true, 9),
    ('CHF', 'Swiss Franc', '瑞士法郎', 'Fr', 2, false, true, '🇨🇭', 'CH', true, 10),
    ('KRW', 'South Korean Won', '韩元', '₩', 0, false, true, '🇰🇷', 'KR', false, 11),
    ('INR', 'Indian Rupee', '印度卢比', '₹', 2, false, true, '🇮🇳', 'IN', false, 12),
    ('TWD', 'Taiwan Dollar', '台币', 'NT$', 2, false, true, '🇹🇼', 'TW', false, 13),
    ('MYR', 'Malaysian Ringgit', '马币', 'RM', 2, false, true, '🇲🇾', 'MY', false, 14),
    ('THB', 'Thai Baht', '泰铢', '฿', 2, false, true, '🇹🇭', 'TH', false, 15),
    ('NZD', 'New Zealand Dollar', '纽币', 'NZ$', 2, false, true, '🇳🇿', 'NZ', false, 16),
    ('SEK', 'Swedish Krona', '瑞典克朗', 'kr', 2, false, true, '🇸🇪', 'SE', false, 17),
    ('NOK', 'Norwegian Krone', '挪威克朗', 'kr', 2, false, true, '🇳🇴', 'NO', false, 18),
    ('DKK', 'Danish Krone', '丹麦克朗', 'kr', 2, false, true, '🇩🇰', 'DK', false, 19),
    ('MXN', 'Mexican Peso', '墨西哥比索', '$', 2, false, true, '🇲🇽', 'MX', false, 20),
    
    -- 主要加密货币
    ('BTC', 'Bitcoin', '比特币', '₿', 8, true, true, '🪙', NULL, true, 101),
    ('ETH', 'Ethereum', '以太坊', 'Ξ', 8, true, true, '⟠', NULL, true, 102),
    ('USDT', 'Tether', '泰达币', '₮', 2, true, true, '💵', NULL, true, 103),
    ('BNB', 'Binance Coin', '币安币', 'BNB', 8, true, true, '🟡', NULL, true, 104),
    ('SOL', 'Solana', 'Solana', 'SOL', 8, true, true, '☀️', NULL, true, 105),
    ('XRP', 'Ripple', '瑞波币', 'XRP', 6, true, true, '💧', NULL, true, 106),
    ('USDC', 'USD Coin', 'USD币', 'USDC', 2, true, true, '💲', NULL, true, 107),
    ('ADA', 'Cardano', '卡尔达诺', '₳', 6, true, true, '🔷', NULL, false, 108),
    ('DOGE', 'Dogecoin', '狗狗币', 'Ð', 8, true, true, '🐕', NULL, false, 109),
    ('AVAX', 'Avalanche', '雪崩', 'AVAX', 8, true, true, '🔺', NULL, false, 110),
    ('DOT', 'Polkadot', '波卡', 'DOT', 10, true, true, '⚪', NULL, false, 111),
    ('MATIC', 'Polygon', 'Polygon', 'MATIC', 8, true, true, '🟣', NULL, false, 112),
    ('LINK', 'Chainlink', 'Chainlink', 'LINK', 8, true, true, '🔗', NULL, false, 113),
    ('LTC', 'Litecoin', '莱特币', 'Ł', 8, true, true, '🪙', NULL, false, 114),
    ('UNI', 'Uniswap', 'Uniswap', 'UNI', 8, true, true, '🦄', NULL, false, 115),
    ('ATOM', 'Cosmos', 'Cosmos', 'ATOM', 6, true, true, '⚛️', NULL, false, 116),
    ('COMP', 'Compound', 'Compound', 'COMP', 8, true, true, '💚', NULL, false, 117),
    ('MKR', 'Maker', 'Maker', 'MKR', 8, true, true, '🏛️', NULL, false, 118),
    ('AAVE', 'Aave', 'Aave', 'AAVE', 8, true, true, '👻', NULL, false, 119),
    ('SUSHI', 'SushiSwap', 'SushiSwap', 'SUSHI', 8, true, true, '🍣', NULL, false, 120),
    ('ARB', 'Arbitrum', 'Arbitrum', 'ARB', 8, true, true, '🔵', NULL, false, 121),
    ('OP', 'Optimism', 'Optimism', 'OP', 8, true, true, '🔴', NULL, false, 122),
    ('SHIB', 'Shiba Inu', '柴犬币', 'SHIB', 8, true, true, '🐕', NULL, false, 123),
    ('TRX', 'TRON', '波场', 'TRX', 6, true, true, '🔶', NULL, false, 124)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    name_zh = EXCLUDED.name_zh,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_crypto = EXCLUDED.is_crypto,
    is_active = EXCLUDED.is_active,
    flag = EXCLUDED.flag,
    country_code = EXCLUDED.country_code,
    is_popular = EXCLUDED.is_popular,
    display_order = EXCLUDED.display_order;

-- 插入默认汇率（以USD为基准的近似值）
-- 这些是初始值，会被实时API数据更新
INSERT INTO exchange_rates (from_currency, to_currency, rate, source, is_manual, updated_at)
VALUES
    -- USD到其他货币
    ('USD', 'EUR', 0.85, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'CNY', 7.25, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'JPY', 150.0, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'GBP', 0.73, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'HKD', 7.85, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'SGD', 1.35, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'AUD', 1.52, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'CAD', 1.36, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'CHF', 0.88, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'KRW', 1300.0, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'INR', 83.0, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'TWD', 32.0, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'MYR', 4.7, 'initial', false, CURRENT_TIMESTAMP),
    ('USD', 'THB', 36.0, 'initial', false, CURRENT_TIMESTAMP),
    
    -- CNY到其他主要货币
    ('CNY', 'USD', 0.138, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'EUR', 0.117, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'JPY', 20.7, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'GBP', 0.101, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'HKD', 1.08, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'SGD', 0.186, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'AUD', 0.210, 'initial', false, CURRENT_TIMESTAMP),
    ('CNY', 'CAD', 0.188, 'initial', false, CURRENT_TIMESTAMP),
    
    -- EUR到其他主要货币
    ('EUR', 'USD', 1.18, 'initial', false, CURRENT_TIMESTAMP),
    ('EUR', 'CNY', 8.53, 'initial', false, CURRENT_TIMESTAMP),
    ('EUR', 'JPY', 176.5, 'initial', false, CURRENT_TIMESTAMP),
    ('EUR', 'GBP', 0.86, 'initial', false, CURRENT_TIMESTAMP),
    ('EUR', 'CHF', 1.04, 'initial', false, CURRENT_TIMESTAMP)
ON CONFLICT (from_currency, to_currency, date) DO UPDATE SET
    rate = EXCLUDED.rate,
    source = EXCLUDED.source,
    updated_at = CURRENT_TIMESTAMP;

-- 插入初始加密货币价格（USD）
INSERT INTO crypto_prices (crypto_code, base_currency, price, source, last_updated)
VALUES
    ('BTC', 'USD', 45000.00, 'initial', CURRENT_TIMESTAMP),
    ('ETH', 'USD', 2500.00, 'initial', CURRENT_TIMESTAMP),
    ('USDT', 'USD', 1.00, 'initial', CURRENT_TIMESTAMP),
    ('BNB', 'USD', 320.00, 'initial', CURRENT_TIMESTAMP),
    ('SOL', 'USD', 110.00, 'initial', CURRENT_TIMESTAMP),
    ('XRP', 'USD', 0.52, 'initial', CURRENT_TIMESTAMP),
    ('USDC', 'USD', 1.00, 'initial', CURRENT_TIMESTAMP),
    ('ADA', 'USD', 0.35, 'initial', CURRENT_TIMESTAMP),
    ('DOGE', 'USD', 0.08, 'initial', CURRENT_TIMESTAMP),
    ('AVAX', 'USD', 35.00, 'initial', CURRENT_TIMESTAMP),
    ('DOT', 'USD', 7.20, 'initial', CURRENT_TIMESTAMP),
    ('MATIC', 'USD', 0.85, 'initial', CURRENT_TIMESTAMP),
    ('LINK', 'USD', 14.50, 'initial', CURRENT_TIMESTAMP),
    ('LTC', 'USD', 72.00, 'initial', CURRENT_TIMESTAMP),
    ('UNI', 'USD', 6.20, 'initial', CURRENT_TIMESTAMP),
    ('ATOM', 'USD', 9.80, 'initial', CURRENT_TIMESTAMP)
ON CONFLICT (crypto_code, base_currency) DO UPDATE SET
    price = EXCLUDED.price,
    source = EXCLUDED.source,
    last_updated = CURRENT_TIMESTAMP;

-- 插入汇率提供商配置
INSERT INTO exchange_rate_providers (provider_name, api_endpoint, is_active, priority, rate_limit)
VALUES
    ('frankfurter', 'https://api.frankfurter.app', true, 1, 0),
    ('exchangerate-api', 'https://api.exchangerate-api.com/v4', true, 2, 100),
    ('coingecko', 'https://api.coingecko.com/api/v3', true, 1, 30),
    ('coincap', 'https://api.coincap.io/v2', true, 2, 0)
ON CONFLICT (provider_name) DO UPDATE SET
    is_active = EXCLUDED.is_active,
    priority = EXCLUDED.priority;

-- 插入系统配置
INSERT INTO system_currency_config (config_key, config_value, config_type, description)
VALUES
    ('auto_update_enabled', 'true', 'boolean', '是否启用自动汇率更新'),
    ('update_interval_minutes', '15', 'number', '汇率更新间隔（分钟）'),
    ('crypto_update_interval_minutes', '5', 'number', '加密货币价格更新间隔（分钟）'),
    ('max_manual_rate_days', '7', 'number', '手动汇率最大有效天数'),
    ('default_base_currency', 'USD', 'string', '系统默认基础货币')
ON CONFLICT (config_key) DO UPDATE SET
    config_value = EXCLUDED.config_value,
    description = EXCLUDED.description;

-- 创建示例用户货币设置（可选）
-- INSERT INTO user_currency_settings (user_id, base_currency, multi_currency_enabled, crypto_enabled)
-- SELECT id, 'USD', true, true FROM users LIMIT 1;

COMMIT;