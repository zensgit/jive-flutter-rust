-- 添加 Ledger 类型和描述字段以支持 Family 架构
-- 执行时间: 2024-01-06

-- 1. 为 ledgers 表添加 type 字段（如果不存在）
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS type VARCHAR(20) DEFAULT 'family';

-- 2. 添加描述字段
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS description TEXT;

-- 3. 添加设置字段（JSON格式）
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS settings JSONB;

-- 4. 添加成员相关字段
ALTER TABLE ledgers
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id);

-- 5. 更新现有数据的默认类型
UPDATE ledgers 
SET type = 'family' 
WHERE type IS NULL;

-- 6. 为类型字段添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_ledgers_type ON ledgers(type);

-- 7. 为 family_id 添加索引（如果还没有）
CREATE INDEX IF NOT EXISTS idx_ledgers_family_id ON ledgers(family_id);

-- 8. 添加注释说明
COMMENT ON COLUMN ledgers.type IS '账本类型: personal(个人), family(家庭), business(商业), project(项目), travel(旅行), investment(投资)';
COMMENT ON COLUMN ledgers.description IS '账本描述信息';
COMMENT ON COLUMN ledgers.settings IS '账本个性化设置（JSON格式）';
COMMENT ON COLUMN ledgers.owner_id IS '账本所有者ID';

-- 9. 创建默认家庭账本（为没有账本的用户）
INSERT INTO ledgers (id, name, type, currency, is_default, description, created_at, updated_at)
SELECT 
    gen_random_uuid(),
    '默认家庭',
    'family',
    'CNY',
    true,
    '默认的家庭账本',
    NOW(),
    NOW()
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM ledgers l 
    WHERE l.owner_id = u.id OR l.family_id IN (
        SELECT family_id FROM family_members WHERE user_id = u.id
    )
)
ON CONFLICT DO NOTHING;

-- 10. 验证修改
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'ledgers' 
AND column_name IN ('type', 'description', 'settings', 'owner_id')
ORDER BY ordinal_position;