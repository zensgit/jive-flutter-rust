-- 增强的多币种数据库表结构
-- 创建时间: 2025-09-08

-- ============================================
-- 1. 货币基础表（已存在，进行增强）
-- ============================================
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS flag VARCHAR(10);
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS country_code VARCHAR(2);
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE;
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 999;
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS min_amount DECIMAL(20, 8) DEFAULT 0.01;
ALTER TABLE currencies ADD COLUMN IF NOT EXISTS max_amount DECIMAL(20, 8) DEFAULT 999999999;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_currencies_is_active ON currencies(is_active);
CREATE INDEX IF NOT EXISTS idx_currencies_is_crypto ON currencies(is_crypto);
CREATE INDEX IF NOT EXISTS idx_currencies_is_popular ON currencies(is_popular);
CREATE INDEX IF NOT EXISTS idx_currencies_display_order ON currencies(display_order);

-- ============================================
-- 2. 用户货币偏好设置表（增强）
-- ============================================
ALTER TABLE user_currency_settings 
ADD COLUMN IF NOT EXISTS show_currency_symbol BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS show_currency_code BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS auto_update_rates BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS rate_update_frequency INTEGER DEFAULT 15, -- 分钟
ADD COLUMN IF NOT EXISTS crypto_update_frequency INTEGER DEFAULT 5; -- 分钟

-- ============================================
-- 3. 汇率表（增强）
-- ============================================
ALTER TABLE exchange_rates 
ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS manual_rate_expiry TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS source VARCHAR(50) DEFAULT 'auto', -- 'auto', 'manual', 'api'
ADD COLUMN IF NOT EXISTS confidence_level DECIMAL(5, 2) DEFAULT 100.00;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_exchange_rates_base_target ON exchange_rates(base_currency, target_currency);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_updated ON exchange_rates(last_updated);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_manual_expiry ON exchange_rates(manual_rate_expiry);

-- ============================================
-- 4. 加密货币价格表（新增）
-- ============================================
CREATE TABLE IF NOT EXISTS crypto_prices (
    id SERIAL PRIMARY KEY,
    crypto_code VARCHAR(10) NOT NULL,
    base_currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    price DECIMAL(20, 8) NOT NULL,
    price_24h_ago DECIMAL(20, 8),
    price_7d_ago DECIMAL(20, 8),
    price_30d_ago DECIMAL(20, 8),
    volume_24h DECIMAL(20, 2),
    market_cap DECIMAL(20, 2),
    change_24h DECIMAL(10, 4),
    change_7d DECIMAL(10, 4),
    change_30d DECIMAL(10, 4),
    is_manual BOOLEAN DEFAULT FALSE,
    manual_price_expiry TIMESTAMPTZ,
    source VARCHAR(50) DEFAULT 'api',
    last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crypto_code, base_currency)
);

CREATE INDEX idx_crypto_prices_code ON crypto_prices(crypto_code);
CREATE INDEX idx_crypto_prices_updated ON crypto_prices(last_updated);

-- ============================================
-- 5. 用户选择的货币表
-- ============================================
CREATE TABLE IF NOT EXISTS user_selected_currencies (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    currency_code VARCHAR(10) NOT NULL,
    is_base_currency BOOLEAN DEFAULT FALSE,
    custom_exchange_rate DECIMAL(20, 10),
    use_manual_rate BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 999,
    is_favorite BOOLEAN DEFAULT FALSE,
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, currency_code)
);

CREATE INDEX idx_user_selected_currencies_user ON user_selected_currencies(user_id);
CREATE INDEX idx_user_selected_currencies_base ON user_selected_currencies(user_id, is_base_currency);

-- ============================================
-- 6. 汇率转换历史表
-- ============================================
CREATE TABLE IF NOT EXISTS exchange_conversion_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    from_currency VARCHAR(10) NOT NULL,
    to_currency VARCHAR(10) NOT NULL,
    amount DECIMAL(20, 8) NOT NULL,
    converted_amount DECIMAL(20, 8) NOT NULL,
    exchange_rate DECIMAL(20, 10) NOT NULL,
    conversion_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    device_info JSONB
);

CREATE INDEX idx_conversion_history_user ON exchange_conversion_history(user_id);
CREATE INDEX idx_conversion_history_date ON exchange_conversion_history(conversion_date);

-- ============================================
-- 7. 汇率提供商配置表
-- ============================================
CREATE TABLE IF NOT EXISTS exchange_rate_providers (
    id SERIAL PRIMARY KEY,
    provider_name VARCHAR(50) NOT NULL UNIQUE,
    api_endpoint VARCHAR(255),
    api_key VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 1,
    rate_limit INTEGER DEFAULT 100, -- 请求/分钟
    last_called TIMESTAMPTZ,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    average_response_time INTEGER, -- 毫秒
    supported_currencies TEXT[], -- 数组存储支持的货币
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8. 汇率缓存表
-- ============================================
CREATE TABLE IF NOT EXISTS exchange_rate_cache (
    id SERIAL PRIMARY KEY,
    cache_key VARCHAR(100) NOT NULL UNIQUE,
    cache_data JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rate_cache_key ON exchange_rate_cache(cache_key);
CREATE INDEX idx_rate_cache_expires ON exchange_rate_cache(expires_at);

-- ============================================
-- 9. 货币使用统计表
-- ============================================
CREATE TABLE IF NOT EXISTS currency_usage_stats (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    currency_code VARCHAR(10) NOT NULL,
    usage_count INTEGER DEFAULT 0,
    last_used TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    total_amount_converted DECIMAL(20, 2) DEFAULT 0,
    UNIQUE(user_id, currency_code)
);

CREATE INDEX idx_currency_usage_user ON currency_usage_stats(user_id);
CREATE INDEX idx_currency_usage_count ON currency_usage_stats(usage_count DESC);

-- ============================================
-- 10. 系统货币配置表
-- ============================================
CREATE TABLE IF NOT EXISTS system_currency_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(50) NOT NULL UNIQUE,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string', -- string, number, boolean, json
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 插入默认配置
INSERT INTO system_currency_config (config_key, config_value, config_type, description) VALUES
('default_base_currency', 'USD', 'string', '系统默认基础货币'),
('max_selected_currencies', '20', 'number', '用户最多可选择的货币数量'),
('rate_update_interval', '15', 'number', '汇率更新间隔（分钟）'),
('crypto_price_update_interval', '5', 'number', '加密货币价格更新间隔（分钟）'),
('enable_manual_rates', 'true', 'boolean', '是否允许手动设置汇率'),
('manual_rate_max_validity', '7', 'number', '手动汇率最大有效天数'),
('restricted_countries', '["KP", "IR", "CU"]', 'json', '限制加密货币的国家代码')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================
-- 11. 触发器：自动更新时间戳
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表添加触发器
CREATE TRIGGER update_exchange_rates_updated_at 
    BEFORE UPDATE ON exchange_rates 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_crypto_prices_updated_at 
    BEFORE UPDATE ON crypto_prices 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at 
    BEFORE UPDATE ON system_currency_config 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 12. 函数：获取用户当前汇率
-- ============================================
CREATE OR REPLACE FUNCTION get_user_exchange_rate(
    p_user_id INTEGER,
    p_from_currency VARCHAR(10),
    p_to_currency VARCHAR(10)
) RETURNS DECIMAL(20, 10) AS $$
DECLARE
    v_rate DECIMAL(20, 10);
    v_manual_rate DECIMAL(20, 10);
    v_manual_expiry TIMESTAMPTZ;
BEGIN
    -- 检查是否有手动设置的汇率
    SELECT custom_exchange_rate, manual_rate_expiry
    INTO v_manual_rate, v_manual_expiry
    FROM user_selected_currencies usc
    JOIN exchange_rates er ON er.target_currency = usc.currency_code
    WHERE usc.user_id = p_user_id 
        AND usc.currency_code = p_to_currency
        AND usc.use_manual_rate = TRUE
        AND er.base_currency = p_from_currency
        AND er.is_manual = TRUE
        AND (er.manual_rate_expiry IS NULL OR er.manual_rate_expiry > CURRENT_TIMESTAMP);
    
    IF v_manual_rate IS NOT NULL THEN
        RETURN v_manual_rate;
    END IF;
    
    -- 获取自动汇率
    SELECT rate INTO v_rate
    FROM exchange_rates
    WHERE base_currency = p_from_currency 
        AND target_currency = p_to_currency
        AND is_manual = FALSE
    ORDER BY last_updated DESC
    LIMIT 1;
    
    RETURN COALESCE(v_rate, 1.0);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 13. 函数：记录汇率转换
-- ============================================
CREATE OR REPLACE FUNCTION record_currency_conversion(
    p_user_id INTEGER,
    p_from VARCHAR(10),
    p_to VARCHAR(10),
    p_amount DECIMAL(20, 8),
    p_converted DECIMAL(20, 8),
    p_rate DECIMAL(20, 10)
) RETURNS VOID AS $$
BEGIN
    -- 记录转换历史
    INSERT INTO exchange_conversion_history (
        user_id, from_currency, to_currency, 
        amount, converted_amount, exchange_rate
    ) VALUES (
        p_user_id, p_from, p_to, 
        p_amount, p_converted, p_rate
    );
    
    -- 更新使用统计
    INSERT INTO currency_usage_stats (user_id, currency_code, usage_count, total_amount_converted)
    VALUES (p_user_id, p_from, 1, p_amount)
    ON CONFLICT (user_id, currency_code) 
    DO UPDATE SET 
        usage_count = currency_usage_stats.usage_count + 1,
        total_amount_converted = currency_usage_stats.total_amount_converted + EXCLUDED.total_amount_converted,
        last_used = CURRENT_TIMESTAMP;
    
    INSERT INTO currency_usage_stats (user_id, currency_code, usage_count, total_amount_converted)
    VALUES (p_user_id, p_to, 1, p_converted)
    ON CONFLICT (user_id, currency_code) 
    DO UPDATE SET 
        usage_count = currency_usage_stats.usage_count + 1,
        total_amount_converted = currency_usage_stats.total_amount_converted + EXCLUDED.total_amount_converted,
        last_used = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 14. 视图：用户货币概览
-- ============================================
CREATE OR REPLACE VIEW user_currency_overview AS
SELECT 
    u.id as user_id,
    u.name as user_name,
    ucs.base_currency,
    ucs.multi_currency_enabled,
    ucs.crypto_enabled,
    ucs.show_currency_symbol,
    ucs.show_currency_code,
    COUNT(DISTINCT usc.currency_code) as selected_currencies_count,
    COUNT(DISTINCT CASE WHEN c.is_crypto THEN c.code END) as selected_crypto_count,
    MAX(usc.added_at) as last_currency_added
FROM users u
LEFT JOIN user_currency_settings ucs ON u.id = ucs.user_id
LEFT JOIN user_selected_currencies usc ON u.id = usc.user_id
LEFT JOIN currencies c ON usc.currency_code = c.code
GROUP BY u.id, u.name, ucs.base_currency, ucs.multi_currency_enabled, 
         ucs.crypto_enabled, ucs.show_currency_symbol, ucs.show_currency_code;

-- ============================================
-- 15. 定期清理过期缓存的函数
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_expired_cache() RETURNS VOID AS $$
BEGIN
    DELETE FROM exchange_rate_cache WHERE expires_at < CURRENT_TIMESTAMP;
    DELETE FROM exchange_conversion_history WHERE conversion_date < CURRENT_TIMESTAMP - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- 创建定期执行的任务（需要pg_cron扩展或外部调度）
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('cleanup-cache', '0 */6 * * *', 'SELECT cleanup_expired_cache();');

-- ============================================
-- 权限设置
-- ============================================
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO jive_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO jive_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO jive_user;