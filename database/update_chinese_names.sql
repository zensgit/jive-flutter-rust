-- Update system_category_templates with proper Chinese names

-- First, let's see what templates exist
SELECT id, name_en, name_zh FROM system_category_templates LIMIT 5;

-- Update with proper Chinese translations based on common categories
UPDATE system_category_templates SET name_zh = 
  CASE 
    -- Income categories
    WHEN name_en ILIKE '%salary%' OR name_en ILIKE '%wage%' THEN '工资收入'
    WHEN name_en ILIKE '%bonus%' THEN '奖金收入'
    WHEN name_en ILIKE '%investment%' THEN '投资收益'
    WHEN name_en ILIKE '%gift%' AND name_en ILIKE '%income%' THEN '礼金收入'
    WHEN name_en ILIKE '%refund%' THEN '退款返现'
    WHEN name_en ILIKE '%side%' AND name_en ILIKE '%income%' THEN '副业收入'
    WHEN name_en ILIKE '%freelance%' THEN '自由职业'
    WHEN name_en ILIKE '%dividend%' THEN '股息收入'
    WHEN name_en ILIKE '%rental%' THEN '租金收入'
    
    -- Expense categories  
    WHEN name_en ILIKE '%food%' OR name_en ILIKE '%dining%' OR name_en ILIKE '%meal%' THEN '餐饮美食'
    WHEN name_en ILIKE '%transport%' OR name_en ILIKE '%commute%' THEN '交通出行'
    WHEN name_en ILIKE '%shopping%' OR name_en ILIKE '%retail%' THEN '购物消费'
    WHEN name_en ILIKE '%entertainment%' OR name_en ILIKE '%recreation%' THEN '娱乐休闲'
    WHEN name_en ILIKE '%home%' OR name_en ILIKE '%housing%' OR name_en ILIKE '%rent%' THEN '居家生活'
    WHEN name_en ILIKE '%health%' OR name_en ILIKE '%medical%' THEN '医疗健康'
    WHEN name_en ILIKE '%education%' OR name_en ILIKE '%learning%' THEN '教育学习'
    WHEN name_en ILIKE '%communication%' OR name_en ILIKE '%phone%' THEN '通讯费用'
    WHEN name_en ILIKE '%finance%' OR name_en ILIKE '%insurance%' THEN '金融保险'
    WHEN name_en ILIKE '%travel%' OR name_en ILIKE '%vacation%' THEN '旅行度假'
    WHEN name_en ILIKE '%pet%' THEN '宠物相关'
    WHEN name_en ILIKE '%gift%' AND name_en NOT ILIKE '%income%' THEN '礼品礼物'
    WHEN name_en ILIKE '%utilities%' THEN '水电燃气'
    WHEN name_en ILIKE '%clothing%' OR name_en ILIKE '%apparel%' THEN '服饰装扮'
    WHEN name_en ILIKE '%beauty%' OR name_en ILIKE '%personal%care%' THEN '美容护理'
    WHEN name_en ILIKE '%sport%' OR name_en ILIKE '%fitness%' THEN '运动健身'
    WHEN name_en ILIKE '%book%' THEN '图书文具'
    WHEN name_en ILIKE '%electronic%' OR name_en ILIKE '%gadget%' THEN '数码电器'
    WHEN name_en ILIKE '%car%' OR name_en ILIKE '%vehicle%' THEN '汽车相关'
    WHEN name_en ILIKE '%child%' OR name_en ILIKE '%baby%' THEN '育儿相关'
    
    -- Default
    WHEN name_en ILIKE '%other%' AND name_en ILIKE '%income%' THEN '其他收入'
    WHEN name_en ILIKE '%other%' AND name_en ILIKE '%expense%' THEN '其他支出'
    ELSE COALESCE(name_zh, name_en) -- Keep existing or use English as fallback
  END
WHERE name_zh IS NULL OR name_zh = name_en;

-- Update users table to ensure full_name is populated
UPDATE users 
SET full_name = COALESCE(full_name, name, SPLIT_PART(email, '@', 1))
WHERE full_name IS NULL OR full_name = '';

-- Update name column from full_name if it's null
UPDATE users 
SET name = COALESCE(name, full_name, SPLIT_PART(email, '@', 1))
WHERE name IS NULL OR name = '';

-- Verify the updates
SELECT COUNT(*) as users_with_name FROM users WHERE name IS NOT NULL;
SELECT COUNT(*) as users_with_full_name FROM users WHERE full_name IS NOT NULL;
SELECT COUNT(*) as templates_with_chinese FROM system_category_templates WHERE name_zh IS NOT NULL AND name_zh != name_en;

-- Show some sample data
SELECT name_en, name_zh FROM system_category_templates LIMIT 10;