-- 填充30天历史汇率数据（测试/演示用）
-- 创建时间: 2025-10-11
-- 用途: 让用户能看到24h/7d/30d汇率趋势

-- ============================================
-- 加密货币历史数据（CNY）
-- ============================================

DO $$
DECLARE
    crypto_data RECORD;
    day_offset INT;
    base_price DECIMAL;
    day_price DECIMAL;
    price_24h_ago_val DECIMAL;
    price_7d_ago_val DECIMAL;
    price_30d_ago_val DECIMAL;
    change_24h_val DECIMAL;
    change_7d_val DECIMAL;
    change_30d_val DECIMAL;
    target_date TIMESTAMP;
BEGIN
    -- 加密货币基础价格（CNY）
    FOR crypto_data IN
        SELECT * FROM (VALUES
            ('BTC', 450000.0),   -- BTC基础价 45万CNY
            ('ETH', 30000.0),    -- ETH基础价 3万CNY
            ('USDT', 7.2),       -- USDT约等于1 USD
            ('USDC', 7.2),       -- USDC约等于1 USD
            ('BNB', 3000.0),     -- BNB 3千CNY
            ('ADA', 5.0),        -- ADA 5 CNY
            ('AAVE', 15000.0),   -- AAVE 1.5万CNY
            ('1INCH', 50.0),     -- 1INCH 50 CNY
            ('AGIX', 20.0),      -- AGIX 20 CNY
            ('ALGO', 10.0),      -- ALGO 10 CNY
            ('APE', 80.0),       -- APE 80 CNY
            ('APT', 100.0),      -- APT 100 CNY
            ('AR', 150.0)        -- AR 150 CNY
        ) AS t(code, base_price)
    LOOP
        base_price := crypto_data.base_price;

        -- 为每一天生成数据（从30天前到今天）
        FOR day_offset IN 0..30 LOOP
            target_date := NOW() - INTERVAL '1 day' * day_offset;

            -- 模拟价格波动：使用正弦波 + 随机噪音
            -- 价格在 ±15% 范围内波动
            day_price := base_price * (
                1.0 +
                0.15 * SIN(day_offset * 0.5) +  -- 正弦波长期趋势
                (RANDOM() - 0.5) * 0.05          -- ±2.5% 随机波动
            );

            -- 计算历史价格（用于趋势计算）
            IF day_offset >= 1 THEN
                price_24h_ago_val := base_price * (
                    1.0 +
                    0.15 * SIN((day_offset - 1) * 0.5) +
                    (RANDOM() - 0.5) * 0.05
                );
            ELSE
                price_24h_ago_val := NULL;
            END IF;

            IF day_offset >= 7 THEN
                price_7d_ago_val := base_price * (
                    1.0 +
                    0.15 * SIN((day_offset - 7) * 0.5) +
                    (RANDOM() - 0.5) * 0.05
                );
            ELSE
                price_7d_ago_val := NULL;
            END IF;

            IF day_offset >= 30 THEN
                price_30d_ago_val := base_price * (
                    1.0 +
                    0.15 * SIN((day_offset - 30) * 0.5) +
                    (RANDOM() - 0.5) * 0.05
                );
            ELSE
                price_30d_ago_val := NULL;
            END IF;

            -- 计算变化百分比
            IF price_24h_ago_val IS NOT NULL AND price_24h_ago_val > 0 THEN
                change_24h_val := ((day_price - price_24h_ago_val) / price_24h_ago_val) * 100;
            ELSE
                change_24h_val := NULL;
            END IF;

            IF price_7d_ago_val IS NOT NULL AND price_7d_ago_val > 0 THEN
                change_7d_val := ((day_price - price_7d_ago_val) / price_7d_ago_val) * 100;
            ELSE
                change_7d_val := NULL;
            END IF;

            IF price_30d_ago_val IS NOT NULL AND price_30d_ago_val > 0 THEN
                change_30d_val := ((day_price - price_30d_ago_val) / price_30d_ago_val) * 100;
            ELSE
                change_30d_val := NULL;
            END IF;

            -- 插入或更新记录
            INSERT INTO exchange_rates (
                id,
                from_currency,
                to_currency,
                rate,
                source,
                date,
                effective_date,
                updated_at,
                price_24h_ago,
                price_7d_ago,
                price_30d_ago,
                change_24h,
                change_7d,
                change_30d,
                is_manual,
                manual_rate_expiry
            ) VALUES (
                gen_random_uuid(),
                crypto_data.code,
                'CNY',
                day_price,
                'demo-historical',
                DATE(target_date),
                DATE(target_date),
                target_date,
                price_24h_ago_val,
                price_7d_ago_val,
                price_30d_ago_val,
                change_24h_val,
                change_7d_val,
                change_30d_val,
                false,
                NULL
            )
            ON CONFLICT (from_currency, to_currency, date) DO UPDATE SET
                rate = EXCLUDED.rate,
                source = EXCLUDED.source,
                effective_date = EXCLUDED.effective_date,
                updated_at = EXCLUDED.updated_at,
                price_24h_ago = EXCLUDED.price_24h_ago,
                price_7d_ago = EXCLUDED.price_7d_ago,
                price_30d_ago = EXCLUDED.price_30d_ago,
                change_24h = EXCLUDED.change_24h,
                change_7d = EXCLUDED.change_7d,
                change_30d = EXCLUDED.change_30d;

        END LOOP;

        RAISE NOTICE '✅ Filled 31 days of historical data for %', crypto_data.code;
    END LOOP;
END $$;

-- ============================================
-- 法定货币历史数据（以USD为基准）
-- ============================================

DO $$
DECLARE
    fiat_data RECORD;
    day_offset INT;
    base_rate DECIMAL;
    day_rate DECIMAL;
    rate_24h_ago_val DECIMAL;
    rate_7d_ago_val DECIMAL;
    rate_30d_ago_val DECIMAL;
    change_24h_val DECIMAL;
    change_7d_val DECIMAL;
    change_30d_val DECIMAL;
    target_date TIMESTAMP;
BEGIN
    -- 法定货币基础汇率（USD为基准）
    FOR fiat_data IN
        SELECT * FROM (VALUES
            ('USD', 'CNY', 7.12),    -- 1 USD = 7.12 CNY
            ('USD', 'EUR', 0.85),    -- 1 USD = 0.85 EUR
            ('USD', 'JPY', 110.0),   -- 1 USD = 110 JPY
            ('USD', 'HKD', 7.75),    -- 1 USD = 7.75 HKD
            ('USD', 'AED', 3.67)     -- 1 USD = 3.67 AED
        ) AS t(from_curr, to_curr, base_rate)
    LOOP
        base_rate := fiat_data.base_rate;

        -- 为每一天生成数据
        FOR day_offset IN 0..30 LOOP
            target_date := NOW() - INTERVAL '1 day' * day_offset;

            -- 法定货币波动较小：±2% 范围
            day_rate := base_rate * (
                1.0 +
                0.02 * SIN(day_offset * 0.3) +  -- 正弦波
                (RANDOM() - 0.5) * 0.01          -- ±0.5% 随机
            );

            -- 计算历史汇率
            IF day_offset >= 1 THEN
                rate_24h_ago_val := base_rate * (
                    1.0 +
                    0.02 * SIN((day_offset - 1) * 0.3) +
                    (RANDOM() - 0.5) * 0.01
                );
            ELSE
                rate_24h_ago_val := NULL;
            END IF;

            IF day_offset >= 7 THEN
                rate_7d_ago_val := base_rate * (
                    1.0 +
                    0.02 * SIN((day_offset - 7) * 0.3) +
                    (RANDOM() - 0.5) * 0.01
                );
            ELSE
                rate_7d_ago_val := NULL;
            END IF;

            IF day_offset >= 30 THEN
                rate_30d_ago_val := base_rate * (
                    1.0 +
                    0.02 * SIN((day_offset - 30) * 0.3) +
                    (RANDOM() - 0.5) * 0.01
                );
            ELSE
                rate_30d_ago_val := NULL;
            END IF;

            -- 计算变化百分比
            IF rate_24h_ago_val IS NOT NULL AND rate_24h_ago_val > 0 THEN
                change_24h_val := ((day_rate - rate_24h_ago_val) / rate_24h_ago_val) * 100;
            ELSE
                change_24h_val := NULL;
            END IF;

            IF rate_7d_ago_val IS NOT NULL AND rate_7d_ago_val > 0 THEN
                change_7d_val := ((day_rate - rate_7d_ago_val) / rate_7d_ago_val) * 100;
            ELSE
                change_7d_val := NULL;
            END IF;

            IF rate_30d_ago_val IS NOT NULL AND rate_30d_ago_val > 0 THEN
                change_30d_val := ((day_rate - rate_30d_ago_val) / rate_30d_ago_val) * 100;
            ELSE
                change_30d_val := NULL;
            END IF;

            -- 插入或更新记录
            INSERT INTO exchange_rates (
                id,
                from_currency,
                to_currency,
                rate,
                source,
                date,
                effective_date,
                updated_at,
                price_24h_ago,
                price_7d_ago,
                price_30d_ago,
                change_24h,
                change_7d,
                change_30d,
                is_manual,
                manual_rate_expiry
            ) VALUES (
                gen_random_uuid(),
                fiat_data.from_curr,
                fiat_data.to_curr,
                day_rate,
                'demo-historical',
                DATE(target_date),
                DATE(target_date),
                target_date,
                rate_24h_ago_val,
                rate_7d_ago_val,
                rate_30d_ago_val,
                change_24h_val,
                change_7d_val,
                change_30d_val,
                false,
                NULL
            )
            ON CONFLICT (from_currency, to_currency, date) DO UPDATE SET
                rate = EXCLUDED.rate,
                source = EXCLUDED.source,
                effective_date = EXCLUDED.effective_date,
                updated_at = EXCLUDED.updated_at,
                price_24h_ago = EXCLUDED.price_24h_ago,
                price_7d_ago = EXCLUDED.price_7d_ago,
                price_30d_ago = EXCLUDED.price_30d_ago,
                change_24h = EXCLUDED.change_24h,
                change_7d = EXCLUDED.change_7d,
                change_30d = EXCLUDED.change_30d;

        END LOOP;

        RAISE NOTICE '✅ Filled 31 days of historical data for % -> %', fiat_data.from_curr, fiat_data.to_curr;
    END LOOP;
END $$;

-- ============================================
-- 验证数据
-- ============================================

-- 查看填充的记录数
SELECT
    from_currency,
    to_currency,
    COUNT(*) as records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    AVG(change_24h) as avg_24h_change,
    AVG(change_7d) as avg_7d_change,
    AVG(change_30d) as avg_30d_change
FROM exchange_rates
WHERE source = 'demo-historical'
GROUP BY from_currency, to_currency
ORDER BY from_currency, to_currency;

-- 显示总结
SELECT
    COUNT(DISTINCT from_currency) as currencies_filled,
    COUNT(*) as total_records,
    MIN(date) as data_start_date,
    MAX(date) as data_end_date
FROM exchange_rates
WHERE source = 'demo-historical';
