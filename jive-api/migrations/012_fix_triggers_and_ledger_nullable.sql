-- =============================================================
-- 012_fix_triggers_and_ledger_nullable.sql
-- 修复：
--   1. 创建/替换 set_updated_at() 函数（011 中因嵌套 $$ 导致失败）
--   2. 为相关表创建 updated_at 触发器（若不存在）
--   3. 放宽 ledgers.family_id 为空的可能（代码存在 family_id IS NULL 场景）
--      允许个人/独立账本；保持外键但可 NULL。
-- =============================================================

-- 1. 函数（幂等）
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $func$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP; 
    RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

-- 2. 放宽 ledgers.family_id 可为空（若尚未修改）
DO $$
BEGIN
    -- 仅当列目前是 NOT NULL 时才修改
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='ledgers' AND column_name='family_id' AND is_nullable='NO'
    ) THEN
        ALTER TABLE ledgers ALTER COLUMN family_id DROP NOT NULL;
    END IF;
END$$;

-- 3. 为需要的表添加触发器（如果不存在）
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'currencies',
        'exchange_rates',
        'user_currency_settings',
        'family_currency_settings',
        'ledgers',
        'accounts'
    ] LOOP
        BEGIN
            EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                            FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t, t);
        EXCEPTION WHEN duplicate_object THEN
            -- 已存在则忽略
            NULL;
        END;
    END LOOP;
END$$;

-- =============================================================
-- 结束
-- =============================================================
