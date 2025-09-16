-- 修复缺失的列

-- 1. 为system_category_templates表添加缺失的列
ALTER TABLE system_category_templates 
ADD COLUMN IF NOT EXISTS name_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS name_zh_tw VARCHAR(100),
ADD COLUMN IF NOT EXISTS name_ja VARCHAR(100),
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS keywords TEXT[],
ADD COLUMN IF NOT EXISTS usage_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_system BOOLEAN DEFAULT true;

-- 2. 为accounts表添加缺失的列
ALTER TABLE accounts 
ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sync_error TEXT;

-- 3. 为transactions表添加缺失的列
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS reference_number VARCHAR(100),
ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS import_id VARCHAR(100);

-- 4. 更新现有模板数据的英文名称
UPDATE system_category_templates SET 
    name_en = CASE 
        WHEN name = '餐饮' THEN 'Dining'
        WHEN name = '交通' THEN 'Transport'
        WHEN name = '购物' THEN 'Shopping'
        WHEN name = '娱乐' THEN 'Entertainment'
        WHEN name = '医疗' THEN 'Medical'
        WHEN name = '教育' THEN 'Education'
        WHEN name = '居家' THEN 'Home'
        WHEN name = '工资' THEN 'Salary'
        WHEN name = '奖金' THEN 'Bonus'
        WHEN name = '投资' THEN 'Investment'
        ELSE name
    END,
    name_zh_tw = name,
    name_ja = CASE 
        WHEN name = '餐饮' THEN '飲食'
        WHEN name = '交通' THEN '交通'
        WHEN name = '购物' THEN 'ショッピング'
        WHEN name = '娱乐' THEN '娯楽'
        WHEN name = '医疗' THEN '医療'
        WHEN name = '教育' THEN '教育'
        WHEN name = '居家' THEN '家庭'
        WHEN name = '工资' THEN '給料'
        WHEN name = '奖金' THEN 'ボーナス'
        WHEN name = '投资' THEN '投資'
        ELSE name
    END
WHERE name_en IS NULL;