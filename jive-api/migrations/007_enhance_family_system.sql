-- =====================================================
-- Migration: 007_enhance_family_system
-- Purpose: 增强Family系统以支持多用户协作
-- Date: 2025-09-03
-- =====================================================

-- 1. 更新 users 表
-- -----------------------------------------------------
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS current_family_id UUID REFERENCES families(id),
ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN users.current_family_id IS '用户当前选择的Family';
COMMENT ON COLUMN users.preferences IS '用户偏好设置';

-- 2. 更新 families 表
-- -----------------------------------------------------
ALTER TABLE families 
ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'CNY',
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
ADD COLUMN IF NOT EXISTS locale VARCHAR(10) DEFAULT 'zh-CN',
ADD COLUMN IF NOT EXISTS date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD';

COMMENT ON COLUMN families.currency IS '默认货币';
COMMENT ON COLUMN families.timezone IS '时区设置';
COMMENT ON COLUMN families.locale IS '语言地区';
COMMENT ON COLUMN families.date_format IS '日期格式';

-- 3. 更新 family_members 表
-- -----------------------------------------------------
ALTER TABLE family_members 
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN family_members.permissions IS '细粒度权限列表';
COMMENT ON COLUMN family_members.invited_by IS '邀请人ID';
COMMENT ON COLUMN family_members.is_active IS '成员是否激活';
COMMENT ON COLUMN family_members.last_active_at IS '最后活跃时间';

-- 4. 创建邀请表
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id),
    invitee_email VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'member',
    invite_code VARCHAR(50) UNIQUE NOT NULL,
    invite_token UUID UNIQUE DEFAULT gen_random_uuid(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    accepted_by UUID REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT invitations_role_check CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
    CONSTRAINT invitations_status_check CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled'))
);

COMMENT ON TABLE invitations IS 'Family邀请记录';
COMMENT ON COLUMN invitations.invite_code IS '短邀请码，用于手动输入';
COMMENT ON COLUMN invitations.invite_token IS '长令牌，用于邀请链接';

-- 5. 创建索引
-- -----------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_invitations_family_id ON invitations(family_id);
CREATE INDEX IF NOT EXISTS idx_invitations_invitee_email ON invitations(invitee_email);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations(expires_at);
CREATE INDEX IF NOT EXISTS idx_family_members_is_active ON family_members(is_active);
CREATE INDEX IF NOT EXISTS idx_users_current_family_id ON users(current_family_id);

-- 6. 创建审计日志表
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS family_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE family_audit_logs IS 'Family操作审计日志';
COMMENT ON COLUMN family_audit_logs.action IS '操作类型：CREATE, UPDATE, DELETE等';
COMMENT ON COLUMN family_audit_logs.entity_type IS '实体类型：member, transaction, account等';

-- 创建审计日志索引
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_family_id ON family_audit_logs(family_id);
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_user_id ON family_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_created_at ON family_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_action ON family_audit_logs(action);

-- 7. 创建函数：生成邀请码
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION generate_invite_code() 
RETURNS VARCHAR(8) AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result VARCHAR(8) := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_invite_code() IS '生成8位随机邀请码';

-- 8. 创建触发器：自动设置邀请过期时间
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION set_invitation_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.expires_at IS NULL THEN
        NEW.expires_at := CURRENT_TIMESTAMP + INTERVAL '7 days';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_invitation_expiry
    BEFORE INSERT ON invitations
    FOR EACH ROW
    EXECUTE FUNCTION set_invitation_expiry();

-- 9. 创建视图：活跃Family成员
-- -----------------------------------------------------
CREATE OR REPLACE VIEW active_family_members AS
SELECT 
    fm.*,
    u.name as user_name,
    u.email as user_email,
    f.name as family_name
FROM family_members fm
JOIN users u ON fm.user_id = u.id
JOIN families f ON fm.family_id = f.id
WHERE fm.is_active = true;

COMMENT ON VIEW active_family_members IS '活跃的Family成员视图';

-- 10. 授权
-- -----------------------------------------------------
-- 如果有特定的数据库用户，在这里授权
-- GRANT ALL ON invitations TO your_app_user;
-- GRANT ALL ON family_audit_logs TO your_app_user;
-- GRANT EXECUTE ON FUNCTION generate_invite_code() TO your_app_user;

-- =====================================================
-- 迁移完成
-- =====================================================