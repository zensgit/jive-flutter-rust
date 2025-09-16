-- Fix missing columns in database tables

-- 1. Add full_name column to users table if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);

-- Update full_name from name if name exists
UPDATE users 
SET full_name = name 
WHERE full_name IS NULL AND name IS NOT NULL;

-- If both are null, create from email
UPDATE users 
SET full_name = SPLIT_PART(email, '@', 1) 
WHERE full_name IS NULL;

-- 2. Add name_zh column to system_category_templates if it doesn't exist
ALTER TABLE system_category_templates 
ADD COLUMN IF NOT EXISTS name_zh VARCHAR(255);

-- Copy from name_en as default
UPDATE system_category_templates 
SET name_zh = name_en 
WHERE name_zh IS NULL;

-- 3. Add name column to users if it doesn't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS name VARCHAR(255);

-- Copy from full_name
UPDATE users 
SET name = full_name 
WHERE name IS NULL AND full_name IS NOT NULL;

-- 4. Add name_zh to categories table if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'categories') THEN
        ALTER TABLE categories ADD COLUMN IF NOT EXISTS name_zh VARCHAR(255);
        UPDATE categories SET name_zh = name WHERE name_zh IS NULL;
    END IF;
END $$;

-- 5. Update system_category_templates with Chinese names
UPDATE system_category_templates SET name_zh = '工资收入' WHERE name_en = 'Salary' AND name_zh = 'Salary';
UPDATE system_category_templates SET name_zh = '餐饮美食' WHERE name_en = 'Food & Dining' AND name_zh = 'Food & Dining';
UPDATE system_category_templates SET name_zh = '交通出行' WHERE name_en = 'Transportation' AND name_zh = 'Transportation';
UPDATE system_category_templates SET name_zh = '购物消费' WHERE name_en = 'Shopping' AND name_zh = 'Shopping';
UPDATE system_category_templates SET name_zh = '娱乐休闲' WHERE name_en = 'Entertainment' AND name_zh = 'Entertainment';
UPDATE system_category_templates SET name_zh = '居家生活' WHERE name_en = 'Home & Living' AND name_zh = 'Home & Living';
UPDATE system_category_templates SET name_zh = '医疗健康' WHERE name_en = 'Healthcare' AND name_zh = 'Healthcare';
UPDATE system_category_templates SET name_zh = '教育学习' WHERE name_en = 'Education' AND name_zh = 'Education';
UPDATE system_category_templates SET name_zh = '通讯费用' WHERE name_en = 'Communication' AND name_zh = 'Communication';
UPDATE system_category_templates SET name_zh = '金融保险' WHERE name_en = 'Finance & Insurance' AND name_zh = 'Finance & Insurance';
UPDATE system_category_templates SET name_zh = '投资收益' WHERE name_en = 'Investment Income' AND name_zh = 'Investment Income';
UPDATE system_category_templates SET name_zh = '副业收入' WHERE name_en = 'Side Income' AND name_zh = 'Side Income';
UPDATE system_category_templates SET name_zh = '奖金收入' WHERE name_en = 'Bonus' AND name_zh = 'Bonus';
UPDATE system_category_templates SET name_zh = '礼金收入' WHERE name_en = 'Gift Income' AND name_zh = 'Gift Income';
UPDATE system_category_templates SET name_zh = '退款返现' WHERE name_en = 'Refund' AND name_zh = 'Refund';
UPDATE system_category_templates SET name_zh = '其他收入' WHERE name_en = 'Other Income' AND name_zh = 'Other Income';
UPDATE system_category_templates SET name_zh = '其他支出' WHERE name_en = 'Other Expense' AND name_zh = 'Other Expense';
UPDATE system_category_templates SET name_zh = '旅行度假' WHERE name_en = 'Travel' AND name_zh = 'Travel';
UPDATE system_category_templates SET name_zh = '宠物相关' WHERE name_en = 'Pets' AND name_zh = 'Pets';
UPDATE system_category_templates SET name_zh = '礼品礼物' WHERE name_en = 'Gifts' AND name_zh = 'Gifts';

-- 6. Ensure all required columns have NOT NULL constraint where needed
-- But first fill any NULL values
UPDATE users SET email = 'user_' || id || '@example.com' WHERE email IS NULL;
UPDATE users SET name = 'User' WHERE name IS NULL;
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- 7. Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_full_name ON users(full_name);
CREATE INDEX IF NOT EXISTS idx_users_name ON users(name);
CREATE INDEX IF NOT EXISTS idx_system_category_templates_name_zh ON system_category_templates(name_zh);

-- 8. Add a status message
DO $$ 
BEGIN
    RAISE NOTICE 'Database columns fixed successfully!';
    RAISE NOTICE 'Added columns: users.full_name, users.name, system_category_templates.name_zh';
END $$;