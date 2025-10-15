-- NOTE: 当前实现以 jive-api/migrations 下的 `invitations`/`family_audit_logs` 为准；
-- 本脚本包含历史命名（如 `family_invitations`）仅用于修复/回溯场景。
-- 版本: 1.0.0
-- 日期: 2025-09-06
-- 描述: 修复数据库以完全支持多Family架构
-- =====================================================

-- 1. 为users表添加current_family_id字段
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS current_family_id UUID REFERENCES families(id);

COMMENT ON COLUMN users.current_family_id IS '用户当前选中的Family ID';

-- 2. 为ledgers表添加family_id字段
ALTER TABLE ledgers 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

-- 为现有的ledgers设置默认family（如果有的话）
UPDATE ledgers 
SET family_id = (SELECT id FROM families LIMIT 1)
WHERE family_id IS NULL;

-- 将family_id设为非空（在设置默认值后）
-- ALTER TABLE ledgers ALTER COLUMN family_id SET NOT NULL;

COMMENT ON COLUMN ledgers.family_id IS '账本所属的Family ID';

-- 3. 为accounts表添加family_id字段（如果需要）
ALTER TABLE accounts 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

COMMENT ON COLUMN accounts.family_id IS '账户所属的Family ID';

-- 4. 为categories表添加family_id字段
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

COMMENT ON COLUMN categories.family_id IS '分类所属的Family ID';

-- 5. 为transactions表添加family_id字段
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

-- 从关联的ledger获取family_id
UPDATE transactions t
SET family_id = l.family_id
FROM ledgers l
WHERE t.ledger_id = l.id AND t.family_id IS NULL;

COMMENT ON COLUMN transactions.family_id IS '交易所属的Family ID';

-- 6. 修复transactions表的date字段问题
-- 检查是否需要重命名transaction_date为date
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'transactions' 
               AND column_name = 'transaction_date'
               AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                              WHERE table_name = 'transactions' 
                              AND column_name = 'date')) THEN
        ALTER TABLE transactions RENAME COLUMN transaction_date TO date;
    END IF;
END $$;

-- 7. 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_ledgers_family_id ON ledgers(family_id);
CREATE INDEX IF NOT EXISTS idx_accounts_family_id ON accounts(family_id);
CREATE INDEX IF NOT EXISTS idx_categories_family_id ON categories(family_id);
CREATE INDEX IF NOT EXISTS idx_transactions_family_id ON transactions(family_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);
CREATE INDEX IF NOT EXISTS idx_users_current_family_id ON users(current_family_id);

-- 8. 为payees表添加family_id字段
ALTER TABLE payees 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

COMMENT ON COLUMN payees.family_id IS '收款人所属的Family ID';
CREATE INDEX IF NOT EXISTS idx_payees_family_id ON payees(family_id);

-- 9. 为tags表添加family_id字段（如果tags表还没有的话）
ALTER TABLE tags 
ADD COLUMN IF NOT EXISTS family_id UUID REFERENCES families(id);

COMMENT ON COLUMN tags.family_id IS '标签所属的Family ID';
CREATE INDEX IF NOT EXISTS idx_tags_family_id ON tags(family_id);

-- 10. 创建默认Family（如果没有的话）
INSERT INTO families (id, name, currency, timezone, locale, fiscal_year_start)
SELECT 
    '00000000-0000-0000-0000-000000000000'::uuid,
    '默认家庭',
    'CNY',
    'Asia/Shanghai',
    'zh-CN',
    1
WHERE NOT EXISTS (SELECT 1 FROM families WHERE id = '00000000-0000-0000-0000-000000000000'::uuid);

-- 11. 将superadmin用户添加到默认Family
INSERT INTO family_members (family_id, user_id, role, joined_at)
SELECT 
    '00000000-0000-0000-0000-000000000000'::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid,
    'owner',
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM family_members 
    WHERE family_id = '00000000-0000-0000-0000-000000000000'::uuid 
    AND user_id = '00000000-0000-0000-0000-000000000001'::uuid
);

-- 12. 更新superadmin的current_family_id
UPDATE users 
SET current_family_id = '00000000-0000-0000-0000-000000000000'::uuid
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

-- 13. 添加family_members表的权限字段（如果需要更细粒度的权限控制）
ALTER TABLE family_members 
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN family_members.permissions IS '用户在Family中的具体权限配置';

-- 14. 添加Family邀请表（用于邀请新成员）
CREATE TABLE IF NOT EXISTS family_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    invited_by UUID NOT NULL REFERENCES users(id),
    invited_email VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(family_id, invited_email)
);

CREATE INDEX IF NOT EXISTS idx_family_invitations_token ON family_invitations(token);
CREATE INDEX IF NOT EXISTS idx_family_invitations_family_id ON family_invitations(family_id);

COMMENT ON TABLE family_invitations IS 'Family成员邀请记录';

-- 输出完成信息
DO $$ 
BEGIN
    RAISE NOTICE '======================================';
    RAISE NOTICE 'Multi-Family架构修复完成！';
    RAISE NOTICE '======================================';
    RAISE NOTICE '1. 已为所有相关表添加family_id字段';
    RAISE NOTICE '2. 已修复transactions表的date字段';
    RAISE NOTICE '3. 已创建必要的索引';
    RAISE NOTICE '4. 已创建默认Family并关联superadmin';
    RAISE NOTICE '======================================';
END $$;
