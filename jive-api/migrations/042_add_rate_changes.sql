-- Migration: 添加汇率变化字段到exchange_rates表
-- Date: 2025-10-10
-- Purpose: 支持24h/7d/30d汇率变化百分比存储，用于定时任务更新

-- 添加汇率变化相关字段
ALTER TABLE exchange_rates
ADD COLUMN IF NOT EXISTS change_24h NUMERIC(10, 4),
ADD COLUMN IF NOT EXISTS change_7d NUMERIC(10, 4),
ADD COLUMN IF NOT EXISTS change_30d NUMERIC(10, 4),
ADD COLUMN IF NOT EXISTS price_24h_ago NUMERIC(20, 8),
ADD COLUMN IF NOT EXISTS price_7d_ago NUMERIC(20, 8),
ADD COLUMN IF NOT EXISTS price_30d_ago NUMERIC(20, 8);

-- 添加索引以加速查询
-- 用于快速查找特定货币对在特定日期的汇率变化
CREATE INDEX IF NOT EXISTS idx_exchange_rates_date_currency
ON exchange_rates(from_currency, to_currency, date DESC);

-- 添加复合索引优化常见查询（最新汇率查询）
-- 注意：不使用WHERE条件，因为CURRENT_DATE不是IMMUTABLE函数
CREATE INDEX IF NOT EXISTS idx_exchange_rates_latest_rates
ON exchange_rates(date DESC, from_currency, to_currency);

-- 添加字段注释
COMMENT ON COLUMN exchange_rates.change_24h IS '24小时汇率变化百分比 (例: 1.25 表示上涨1.25%)';
COMMENT ON COLUMN exchange_rates.change_7d IS '7天汇率变化百分比';
COMMENT ON COLUMN exchange_rates.change_30d IS '30天汇率变化百分比';
COMMENT ON COLUMN exchange_rates.price_24h_ago IS '24小时前的汇率/价格，用于计算变化';
COMMENT ON COLUMN exchange_rates.price_7d_ago IS '7天前的汇率/价格，用于计算变化';
COMMENT ON COLUMN exchange_rates.price_30d_ago IS '30天前的汇率/价格，用于计算变化';

-- 添加表级注释说明
COMMENT ON TABLE exchange_rates IS '汇率表 - 存储每日汇率及24h/7d/30d变化趋势数据';

-- 验证索引创建成功
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE indexname = 'idx_exchange_rates_date_currency'
    ) THEN
        RAISE NOTICE 'Index idx_exchange_rates_date_currency created successfully';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE indexname = 'idx_exchange_rates_current_date'
    ) THEN
        RAISE NOTICE 'Index idx_exchange_rates_current_date created successfully';
    END IF;
END $$;
