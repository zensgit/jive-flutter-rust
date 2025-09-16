-- 更新payees表结构（添加缺失的字段）
ALTER TABLE payees ADD COLUMN IF NOT EXISTS default_category_id UUID;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS is_vendor BOOLEAN DEFAULT false;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS is_customer BOOLEAN DEFAULT false;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS contact_info JSONB;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE payees ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_payees_deleted_at ON payees(deleted_at);
CREATE INDEX IF NOT EXISTS idx_payees_default_category_id ON payees(default_category_id);
CREATE INDEX IF NOT EXISTS idx_payees_is_active ON payees(is_active);

-- 添加外键约束
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS payee_id UUID REFERENCES payees(id);