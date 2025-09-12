-- =============================================================
-- 011_add_currency_exchange_tables.sql
-- 补充：货币 / 汇率 / 用户与家庭货币偏好 / 加密价格 / 汇率缓存 等表
-- 说明：这些表在代码中已被引用，但此前迁移缺失，导致 sqlx 宏编译失败。
-- 执行方式：
--   - 新库：Postgres 初始化时自动执行（docker 第一次启动）
--   - 现有库：请手动执行本文件内容或复制到 psql 中运行
-- =============================================================

-- 1. 货币主数据表
CREATE TABLE IF NOT EXISTS currencies (
    code              VARCHAR(10) PRIMARY KEY,
    name              VARCHAR(100) NOT NULL,
    name_zh           VARCHAR(100),
    symbol            VARCHAR(10),
    decimal_places    INTEGER DEFAULT 2,
    is_active         BOOLEAN DEFAULT true,
    is_crypto         BOOLEAN DEFAULT false,
    flag              TEXT,
    created_at        TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_currencies_active ON currencies(is_active);
CREATE INDEX IF NOT EXISTS idx_currencies_is_crypto ON currencies(is_crypto);

-- 2. 用户货币设置
CREATE TABLE IF NOT EXISTS user_currency_settings (
    user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    multi_currency_enabled BOOLEAN DEFAULT false,
    crypto_enabled         BOOLEAN DEFAULT false,
    base_currency          VARCHAR(10) DEFAULT 'USD',
    selected_currencies    TEXT[] DEFAULT ARRAY['USD','CNY'],
    show_currency_code     BOOLEAN DEFAULT true,
    show_currency_symbol   BOOLEAN DEFAULT false,
    created_at             TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. 用户货币偏好（排序 / 主货币标记）
CREATE TABLE IF NOT EXISTS user_currency_preferences (
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    currency_code  VARCHAR(10) NOT NULL REFERENCES currencies(code) ON DELETE CASCADE,
    is_primary     BOOLEAN DEFAULT false,
    display_order  INTEGER DEFAULT 0,
    created_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, currency_code)
);
CREATE INDEX IF NOT EXISTS idx_user_currency_preferences_user ON user_currency_preferences(user_id);

-- 4. 家庭货币设置
CREATE TABLE IF NOT EXISTS family_currency_settings (
    family_id           UUID PRIMARY KEY REFERENCES families(id) ON DELETE CASCADE,
    base_currency       VARCHAR(10) DEFAULT 'CNY',
    allow_multi_currency BOOLEAN DEFAULT true,
    auto_convert         BOOLEAN DEFAULT false,
    supported_currencies TEXT[] DEFAULT ARRAY['CNY','USD'],
    created_at           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. 汇率表（法币 + 可能的加密中转）
CREATE TABLE IF NOT EXISTS exchange_rates (
    id             UUID PRIMARY KEY,
    from_currency  VARCHAR(10) NOT NULL REFERENCES currencies(code) ON DELETE CASCADE,
    to_currency    VARCHAR(10) NOT NULL REFERENCES currencies(code) ON DELETE CASCADE,
    rate           DECIMAL(30, 12) NOT NULL,
    source         VARCHAR(50),
    date           DATE NOT NULL,            -- 业务日期（唯一约束组成部分）
    effective_date DATE NOT NULL,            -- 生效日期（可与 date 相同）
    is_manual      BOOLEAN DEFAULT true,
    created_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_currency, to_currency, date)
);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_from ON exchange_rates(from_currency, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_to ON exchange_rates(to_currency, created_at DESC);

-- 6. 加密价格（按基准法币）
CREATE TABLE IF NOT EXISTS crypto_prices (
    crypto_code   VARCHAR(15) NOT NULL,
    base_currency VARCHAR(10) NOT NULL,
    price         DECIMAL(30, 12) NOT NULL,
    source        VARCHAR(50),
    last_updated  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (crypto_code, base_currency)
);
CREATE INDEX IF NOT EXISTS idx_crypto_prices_updated ON crypto_prices(last_updated DESC);

-- 7. 汇率缓存（可用于临时 API 缓存）
CREATE TABLE IF NOT EXISTS exchange_rate_cache (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency VARCHAR(10) NOT NULL,
    to_currency   VARCHAR(10) NOT NULL,
    rate          DECIMAL(30,12) NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_currency, to_currency)
);
CREATE INDEX IF NOT EXISTS idx_exchange_rate_cache_expires ON exchange_rate_cache(expires_at);

-- 8. 汇率转换历史（用于审计 / 统计）
CREATE TABLE IF NOT EXISTS exchange_conversion_history (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency    VARCHAR(10) NOT NULL,
    to_currency      VARCHAR(10) NOT NULL,
    original_amount  DECIMAL(30,12),
    converted_amount DECIMAL(30,12),
    rate_used        DECIMAL(30,12),
    conversion_date  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_exchange_conv_hist_date ON exchange_conversion_history(conversion_date);

-- 9. 预置常用货币（存在则跳过）
INSERT INTO currencies(code, name, symbol, decimal_places, is_active, is_crypto, flag)
VALUES
    ('USD','US Dollar','$',2,true,false,'🇺🇸'),
    ('CNY','Chinese Yuan','¥',2,true,false,'🇨🇳'),
    ('EUR','Euro','€',2,true,false,'🇪🇺'),
    ('GBP','British Pound','£',2,true,false,'🇬🇧'),
    ('JPY','Japanese Yen','¥',0,true,false,'🇯🇵'),
    ('BTC','Bitcoin','₿',8,true,true,'₿'),
    ('ETH','Ethereum','Ξ',8,true,true,'Ξ')
ON CONFLICT (code) DO NOTHING;

-- 10. 触发器更新时间（可选）
-- 如果已在其它迁移中创建通用 updated_at 触发器，可跳过；这里做防御式创建
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'set_updated_at') THEN
        CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW;
        END; $$ LANGUAGE plpgsql;
    END IF;
END$$;

-- 为需要的表增加触发器（若不存在）
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT unnest(ARRAY['currencies','exchange_rates','user_currency_settings','family_currency_settings']) AS t LOOP
        EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                        FOR EACH ROW EXECUTE FUNCTION set_updated_at()', rec.t, rec.t);
    END LOOP;
EXCEPTION WHEN others THEN
    -- 忽略已存在触发器错误
END$$;

-- =============================================================
-- 结束
-- =============================================================
