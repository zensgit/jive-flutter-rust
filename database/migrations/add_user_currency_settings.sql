-- 添加用户货币设置表来支持增强的货币功能
-- Add user currency settings table for enhanced currency features

-- 创建用户货币设置表
CREATE TABLE IF NOT EXISTS user_currency_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    multi_currency_enabled BOOLEAN DEFAULT false,
    crypto_enabled BOOLEAN DEFAULT false,
    base_currency VARCHAR(10) DEFAULT 'USD',
    selected_currencies TEXT[] DEFAULT ARRAY['USD', 'CNY', 'EUR'],
    show_currency_code BOOLEAN DEFAULT true,
    show_currency_symbol BOOLEAN DEFAULT false,
    auto_refresh_rates BOOLEAN DEFAULT true,
    refresh_interval_minutes INT DEFAULT 15,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建加密货币价格缓存表
CREATE TABLE IF NOT EXISTS crypto_price_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    crypto_code VARCHAR(10) NOT NULL,
    fiat_code VARCHAR(10) NOT NULL,
    price DECIMAL(20, 10) NOT NULL,
    volume_24h DECIMAL(20, 2),
    change_24h DECIMAL(10, 4),
    market_cap DECIMAL(20, 2),
    source VARCHAR(50) DEFAULT 'coingecko',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crypto_code, fiat_code)
);

-- 创建汇率刷新日志表
CREATE TABLE IF NOT EXISTS exchange_rate_refresh_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base_currency VARCHAR(10) NOT NULL,
    source VARCHAR(50) NOT NULL,
    success BOOLEAN NOT NULL,
    rates_updated INT DEFAULT 0,
    error_message TEXT,
    refreshed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建热门货币对表
CREATE TABLE IF NOT EXISTS popular_currency_pairs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency VARCHAR(10) NOT NULL,
    to_currency VARCHAR(10) NOT NULL,
    pair_name VARCHAR(100),
    usage_count INT DEFAULT 0,
    last_used TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_currency, to_currency)
);

-- 插入默认的热门货币对
INSERT INTO popular_currency_pairs (from_currency, to_currency, pair_name, usage_count) VALUES
('USD', 'CNY', 'USD/CNY', 100),
('CNY', 'USD', 'CNY/USD', 100),
('EUR', 'USD', 'EUR/USD', 90),
('USD', 'EUR', 'USD/EUR', 90),
('GBP', 'USD', 'GBP/USD', 80),
('USD', 'JPY', 'USD/JPY', 80),
('CNY', 'EUR', 'CNY/EUR', 70),
('CNY', 'JPY', 'CNY/JPY', 60),
('CNY', 'HKD', 'CNY/HKD', 50),
('BTC', 'USD', 'BTC/USD', 100),
('ETH', 'USD', 'ETH/USD', 90),
('BTC', 'CNY', 'BTC/CNY', 80)
ON CONFLICT (from_currency, to_currency) DO NOTHING;

-- 为现有用户创建默认设置
INSERT INTO user_currency_settings (user_id, base_currency, selected_currencies)
SELECT 
    u.id,
    COALESCE(
        (SELECT currency_code 
         FROM user_currency_preferences 
         WHERE user_id = u.id AND is_primary = true 
         LIMIT 1),
        'USD'
    ),
    ARRAY(
        SELECT DISTINCT currency_code 
        FROM user_currency_preferences 
        WHERE user_id = u.id
        UNION 
        SELECT 'USD'
        UNION
        SELECT 'CNY'
        LIMIT 5
    )
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_currency_settings ucs WHERE ucs.user_id = u.id
);

-- 创建索引优化查询性能
CREATE INDEX idx_crypto_price_cache_codes ON crypto_price_cache(crypto_code, fiat_code);
CREATE INDEX idx_crypto_price_cache_created ON crypto_price_cache(created_at);
CREATE INDEX idx_exchange_rate_refresh_log_currency ON exchange_rate_refresh_log(base_currency);
CREATE INDEX idx_exchange_rate_refresh_log_time ON exchange_rate_refresh_log(refreshed_at);
CREATE INDEX idx_popular_currency_pairs_usage ON popular_currency_pairs(usage_count DESC);

-- 创建更新时间触发器
CREATE TRIGGER update_user_currency_settings_updated_at 
    BEFORE UPDATE ON user_currency_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 创建函数来更新货币对使用统计
CREATE OR REPLACE FUNCTION update_currency_pair_usage(
    p_from_currency VARCHAR,
    p_to_currency VARCHAR
) RETURNS void AS $$
BEGIN
    INSERT INTO popular_currency_pairs (from_currency, to_currency, usage_count, last_used)
    VALUES (p_from_currency, p_to_currency, 1, CURRENT_TIMESTAMP)
    ON CONFLICT (from_currency, to_currency) 
    DO UPDATE SET 
        usage_count = popular_currency_pairs.usage_count + 1,
        last_used = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- 创建函数来清理过期的缓存
CREATE OR REPLACE FUNCTION clean_expired_cache() RETURNS void AS $$
BEGIN
    -- 删除超过5分钟的加密货币价格缓存
    DELETE FROM crypto_price_cache 
    WHERE created_at < NOW() - INTERVAL '5 minutes';
    
    -- 删除超过30天的汇率刷新日志
    DELETE FROM exchange_rate_refresh_log 
    WHERE refreshed_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;