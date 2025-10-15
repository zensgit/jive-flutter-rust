# Migration 019 修复说明

## 问题描述

原始的 `019_add_manual_rate_columns.sql` 脚本存在语法问题，导致通过 `psql` 执行时失败。

### 原始问题

```sql
DO $$
BEGIN
    IF NOT EXISTS (...) THEN
        CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
        RETURNS TRIGGER AS $$  -- ❌ 嵌套的 $$ 分隔符冲突
        BEGIN
            ...
        END;
        $$ LANGUAGE plpgsql;  -- ❌ 与外层 $$ 冲突
        ...
    END IF;
END$$;
```

**错误原因**:
- DO块使用 `$$` 作为分隔符
- 内部CREATE FUNCTION也使用 `$$` 作为分隔符
- PostgreSQL解析器无法区分这两个层级的分隔符，导致语法错误和事务回滚

**实际错误**:
```
ERROR:  syntax error at or near "BEGIN"
ERROR:  syntax error at or near "RETURN"
ROLLBACK
```

## 修复方案

### 方案1: 使用不同的分隔符 (已采用)

```sql
-- 2) 创建函数（使用 $$ 分隔符）
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) 创建触发器（DO块使用 $do$ 分隔符）
DO $do$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tr_exchange_rates_set_updated_at'
        AND tgrelid = 'exchange_rates'::regclass
    ) THEN
        CREATE TRIGGER tr_exchange_rates_set_updated_at
        BEFORE UPDATE ON exchange_rates
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_timestamp();
    END IF;
END
$do$;
```

**关键改进**:
1. ✅ 将CREATE FUNCTION移出DO块
2. ✅ DO块使用不同的分隔符 `$do$` 而非 `$$`
3. ✅ 使用 `CREATE OR REPLACE FUNCTION` 确保幂等性
4. ✅ 在触发器检查中添加 `tgrelid` 条件，更精确
5. ✅ 移除不必要的 `BEGIN;` 和 `COMMIT;`

### 方案2: 完全避免DO块 (备选)

```sql
-- 创建函数（幂等）
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 删除可能存在的旧触发器
DROP TRIGGER IF EXISTS tr_exchange_rates_set_updated_at ON exchange_rates;

-- 重新创建触发器
CREATE TRIGGER tr_exchange_rates_set_updated_at
BEFORE UPDATE ON exchange_rates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at_timestamp();
```

**优点**: 更简单，避免复杂的条件逻辑
**缺点**: 每次都会重建触发器（性能影响可忽略）

## 验证测试

### 1. 首次运行验证

```bash
psql -h localhost -p 5433 -U postgres -d test_db \
     -f migrations/019_add_manual_rate_columns.sql
```

**期望输出**:
```
ALTER TABLE
CREATE FUNCTION
DO
```

**验证结果**:
```sql
\d exchange_rates
-- 应看到:
-- is_manual          | boolean                  | not null | false
-- manual_rate_expiry | timestamp with time zone |          |

SELECT tgname FROM pg_trigger WHERE tgname = 'tr_exchange_rates_set_updated_at';
-- 应返回 1 行
```

### 2. 幂等性测试

```bash
# 再次运行相同的脚本
psql -h localhost -p 5433 -U postgres -d test_db \
     -f migrations/019_add_manual_rate_columns.sql
```

**期望输出**:
```
NOTICE:  column "is_manual" of relation "exchange_rates" already exists, skipping
NOTICE:  column "manual_rate_expiry" of relation "exchange_rates" already exists, skipping
ALTER TABLE
CREATE FUNCTION
DO
```

✅ 无错误，脚本可安全重复执行

### 3. 触发器功能测试

```sql
-- 插入测试数据
INSERT INTO exchange_rates (from_currency, to_currency, rate, date, effective_date)
VALUES ('USD', 'CNY', 7.2345, CURRENT_DATE, CURRENT_DATE);

-- 记录初始时间戳
SELECT created_at, updated_at FROM exchange_rates WHERE from_currency = 'USD';
-- created_at = updated_at (初始相同)

-- 等待1秒后更新
SELECT pg_sleep(1);
UPDATE exchange_rates SET rate = 7.2500 WHERE from_currency = 'USD';

-- 验证 updated_at 已更新
SELECT created_at, updated_at FROM exchange_rates WHERE from_currency = 'USD';
-- created_at != updated_at ✅
```

## 修复影响

### 已修改的文件
- `migrations/019_add_manual_rate_columns.sql` - 修复语法问题

### 已验证的功能
- ✅ 列添加（is_manual, manual_rate_expiry）
- ✅ 触发器创建和功能
- ✅ 脚本幂等性
- ✅ 函数创建
- ✅ updated_at 自动更新

### 兼容性
- ✅ PostgreSQL 12+
- ✅ PostgreSQL 13+
- ✅ PostgreSQL 14+
- ✅ PostgreSQL 15+
- ✅ PostgreSQL 16+ (已测试)

## 后续操作

对于已经部署的环境：

### 如果迁移尚未运行
直接使用修复后的脚本即可。

### 如果迁移已失败
需要手动补救：

```sql
-- 检查列是否存在
SELECT column_name FROM information_schema.columns
WHERE table_name = 'exchange_rates'
AND column_name IN ('is_manual', 'manual_rate_expiry');

-- 如果不存在，手动添加
ALTER TABLE exchange_rates
    ADD COLUMN IF NOT EXISTS is_manual BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS manual_rate_expiry TIMESTAMPTZ NULL;

-- 创建函数和触发器
CREATE OR REPLACE FUNCTION set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $do$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'tr_exchange_rates_set_updated_at'
        AND tgrelid = 'exchange_rates'::regclass
    ) THEN
        CREATE TRIGGER tr_exchange_rates_set_updated_at
        BEFORE UPDATE ON exchange_rates
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at_timestamp();
    END IF;
END
$do$;
```

## 学习要点

1. **DO块分隔符冲突**: 当在DO块内部需要创建包含代码块的对象（如函数、触发器）时，必须使用不同的分隔符
2. **幂等性设计**: 使用 `IF NOT EXISTS`、`CREATE OR REPLACE` 等确保脚本可安全重复执行
3. **函数独立性**: 将函数创建移到DO块外部，使其成为独立的、可替换的对象
4. **触发器检查**: 在检查触发器是否存在时，同时检查 `tgname` 和 `tgrelid`，避免跨表冲突

## 修复日期
2025-10-11

## 修复验证
✅ 已在PostgreSQL 16测试环境中完整验证
✅ 已通过集成测试验证
