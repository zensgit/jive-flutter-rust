-- =====================================================
-- Migration: 008_migrate_existing_data
-- Purpose: 迁移现有数据以适配新的Family系统
-- Date: 2025-09-03
-- =====================================================

-- 1. 为现有的Family设置owner_id（如果缺失）
-- -----------------------------------------------------
UPDATE families f
SET owner_id = (
    SELECT fm.user_id 
    FROM family_members fm 
    WHERE fm.family_id = f.id 
    AND fm.role = 'owner'
    LIMIT 1
)
WHERE f.owner_id IS NULL
AND EXISTS (
    SELECT 1 FROM family_members fm 
    WHERE fm.family_id = f.id 
    AND fm.role = 'owner'
);

-- 2. 为Family的owner创建family_members记录（如果缺失）
-- -----------------------------------------------------
INSERT INTO family_members (family_id, user_id, role, joined_at, is_active)
SELECT 
    f.id as family_id,
    f.owner_id as user_id,
    'owner' as role,
    f.created_at as joined_at,
    true as is_active
FROM families f
WHERE f.owner_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 
    FROM family_members fm 
    WHERE fm.family_id = f.id 
    AND fm.user_id = f.owner_id
);

-- 3. 设置现有成员的默认权限
-- -----------------------------------------------------
UPDATE family_members
SET permissions = CASE
    WHEN role = 'owner' THEN 
        '["ViewFamilyInfo", "UpdateFamilyInfo", "DeleteFamily", "ViewMembers", "InviteMembers", "RemoveMembers", "UpdateMemberRoles", "ViewAccounts", "CreateAccounts", "EditAccounts", "DeleteAccounts", "ViewTransactions", "CreateTransactions", "EditTransactions", "DeleteTransactions", "BulkEditTransactions", "ViewCategories", "ManageCategories", "ViewBudgets", "ManageBudgets", "ViewReports", "ExportData", "ViewAuditLog", "ManageIntegrations", "ManageSettings"]'::jsonb
    WHEN role = 'admin' THEN 
        '["ViewFamilyInfo", "UpdateFamilyInfo", "ViewMembers", "InviteMembers", "RemoveMembers", "UpdateMemberRoles", "ViewAccounts", "CreateAccounts", "EditAccounts", "DeleteAccounts", "ViewTransactions", "CreateTransactions", "EditTransactions", "DeleteTransactions", "BulkEditTransactions", "ViewCategories", "ManageCategories", "ViewBudgets", "ManageBudgets", "ViewReports", "ExportData", "ViewAuditLog", "ManageIntegrations", "ManageSettings"]'::jsonb
    WHEN role = 'member' THEN 
        '["ViewFamilyInfo", "ViewMembers", "ViewAccounts", "CreateAccounts", "EditAccounts", "ViewTransactions", "CreateTransactions", "EditTransactions", "ViewCategories", "ViewBudgets", "ViewReports", "ExportData"]'::jsonb
    WHEN role = 'viewer' THEN 
        '["ViewFamilyInfo", "ViewMembers", "ViewAccounts", "ViewTransactions", "ViewCategories", "ViewBudgets", "ViewReports"]'::jsonb
    ELSE '[]'::jsonb
END
WHERE permissions = '[]'::jsonb OR permissions IS NULL;

-- 4. 设置用户的current_family_id（选择用户作为owner的Family）
-- -----------------------------------------------------
UPDATE users u
SET current_family_id = (
    SELECT f.id 
    FROM families f 
    JOIN family_members fm ON f.id = fm.family_id
    WHERE fm.user_id = u.id 
    AND fm.role = 'owner'
    AND fm.is_active = true
    ORDER BY fm.joined_at DESC
    LIMIT 1
)
WHERE u.current_family_id IS NULL;

-- 如果用户不是任何Family的owner，选择其第一个加入的Family
UPDATE users u
SET current_family_id = (
    SELECT fm.family_id
    FROM family_members fm
    WHERE fm.user_id = u.id
    AND fm.is_active = true
    ORDER BY fm.joined_at ASC
    LIMIT 1
)
WHERE u.current_family_id IS NULL;

-- 5. 为没有Family的用户创建个人Family
-- -----------------------------------------------------
DO $$
DECLARE
    user_record RECORD;
    new_family_id UUID;
    new_ledger_id UUID;
BEGIN
    FOR user_record IN 
        SELECT id, name, email 
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1 FROM family_members fm 
            WHERE fm.user_id = u.id
        )
    LOOP
        -- 创建新的Family
        new_family_id := gen_random_uuid();
        INSERT INTO families (
            id, 
            name, 
            owner_id,
            invite_code,
            currency,
            timezone,
            locale,
            created_at, 
            updated_at
        ) VALUES (
            new_family_id,
            COALESCE(user_record.name, split_part(user_record.email, '@', 1)) || '的个人账本',
            user_record.id,
            generate_invite_code(),
            'CNY',
            'Asia/Shanghai',
            'zh-CN',
            NOW(),
            NOW()
        );
        
        -- 创建成员关系
        INSERT INTO family_members (
            family_id,
            user_id,
            role,
            permissions,
            is_active,
            joined_at
        ) VALUES (
            new_family_id,
            user_record.id,
            'owner',
            '["ViewFamilyInfo", "UpdateFamilyInfo", "DeleteFamily", "ViewMembers", "InviteMembers", "RemoveMembers", "UpdateMemberRoles", "ViewAccounts", "CreateAccounts", "EditAccounts", "DeleteAccounts", "ViewTransactions", "CreateTransactions", "EditTransactions", "DeleteTransactions", "BulkEditTransactions", "ViewCategories", "ManageCategories", "ViewBudgets", "ManageBudgets", "ViewReports", "ExportData", "ViewAuditLog", "ManageIntegrations", "ManageSettings"]'::jsonb,
            true,
            NOW()
        );
        
        -- 创建默认账本
        new_ledger_id := gen_random_uuid();
        INSERT INTO ledgers (
            id,
            family_id,
            name,
            currency,
            created_by,
            created_at,
            updated_at
        ) VALUES (
            new_ledger_id,
            new_family_id,
            '默认账本',
            'CNY',
            user_record.id,
            NOW(),
            NOW()
        );
        
        -- 更新用户的current_family_id
        UPDATE users 
        SET current_family_id = new_family_id
        WHERE id = user_record.id;
        
        RAISE NOTICE '为用户 % 创建了个人Family', user_record.email;
    END LOOP;
END $$;

-- 6. 生成所有Family的邀请码（如果缺失）
-- -----------------------------------------------------
UPDATE families
SET invite_code = generate_invite_code()
WHERE invite_code IS NULL;

-- 确保邀请码唯一性（处理可能的冲突）
DO $$
DECLARE
    duplicate_record RECORD;
    new_code VARCHAR(8);
BEGIN
    LOOP
        -- 查找重复的邀请码
        SELECT invite_code, COUNT(*) as cnt
        INTO duplicate_record
        FROM families
        WHERE invite_code IS NOT NULL
        GROUP BY invite_code
        HAVING COUNT(*) > 1
        LIMIT 1;
        
        EXIT WHEN duplicate_record IS NULL;
        
        -- 为重复的邀请码生成新码
        FOR i IN 1..duplicate_record.cnt - 1 LOOP
            LOOP
                new_code := generate_invite_code();
                EXIT WHEN NOT EXISTS (
                    SELECT 1 FROM families WHERE invite_code = new_code
                );
            END LOOP;
            
            UPDATE families
            SET invite_code = new_code
            WHERE invite_code = duplicate_record.invite_code
            AND id IN (
                SELECT id FROM families 
                WHERE invite_code = duplicate_record.invite_code
                OFFSET 1
                LIMIT 1
            );
        END LOOP;
    END LOOP;
END $$;

-- 7. 记录迁移完成
-- -----------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '数据迁移完成统计:';
    RAISE NOTICE '- 用户总数: %', (SELECT COUNT(*) FROM users);
    RAISE NOTICE '- Family总数: %', (SELECT COUNT(*) FROM families);
    RAISE NOTICE '- 成员关系总数: %', (SELECT COUNT(*) FROM family_members);
    RAISE NOTICE '- 设置了current_family_id的用户: %', (SELECT COUNT(*) FROM users WHERE current_family_id IS NOT NULL);
    RAISE NOTICE '- 有邀请码的Family: %', (SELECT COUNT(*) FROM families WHERE invite_code IS NOT NULL);
    RAISE NOTICE '===========================================';
END $$;

-- =====================================================
-- 数据迁移完成
-- =====================================================