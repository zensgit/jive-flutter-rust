# TODO 002: 领域模型设计文档

## 设计目标

创建清晰的领域模型层，封装Family协作系统的核心业务逻辑和规则。

## 模型架构

### 1. Family领域模型 (models/family.rs)

#### 核心结构
```rust
pub struct Family {
    pub id: Uuid,
    pub name: String,
    pub owner_id: Uuid,
    pub invite_code: Option<String>,
    pub settings: FamilySettings,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub struct FamilySettings {
    pub currency: String,
    pub timezone: String,
    pub locale: String,
    pub date_format: String,
}
```

#### 业务方法
- `create()` - 创建新Family
- `update_settings()` - 更新设置
- `generate_invite_code()` - 生成邀请码
- `transfer_ownership()` - 转移所有权
- `can_be_deleted_by()` - 检查删除权限

### 2. 成员关系模型 (models/membership.rs)

#### 核心结构
```rust
pub struct FamilyMember {
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub role: MemberRole,
    pub permissions: Vec<Permission>,
    pub invited_by: Option<Uuid>,
    pub is_active: bool,
    pub joined_at: DateTime<Utc>,
    pub last_active_at: Option<DateTime<Utc>>,
}

#[derive(Clone, Copy)]
pub enum MemberRole {
    Owner,
    Admin,
    Member,
    Viewer,
}
```

#### 业务方法
- `new()` - 创建成员关系
- `change_role()` - 更改角色
- `grant_permission()` - 授予权限
- `revoke_permission()` - 撤销权限
- `deactivate()` - 停用成员
- `can_perform()` - 权限检查

### 3. 权限模型 (models/permission.rs)

#### 核心结构
```rust
#[derive(Clone, Copy, Debug)]
pub enum Permission {
    // Family管理
    ViewFamilyInfo,
    UpdateFamilyInfo,
    DeleteFamily,
    
    // 成员管理
    ViewMembers,
    InviteMembers,
    RemoveMembers,
    UpdateMemberRoles,
    
    // 账户管理
    ViewAccounts,
    CreateAccounts,
    EditAccounts,
    DeleteAccounts,
    
    // 交易管理
    ViewTransactions,
    CreateTransactions,
    EditTransactions,
    DeleteTransactions,
    BulkEditTransactions,
    
    // 其他权限
    ViewCategories,
    ManageCategories,
    ViewBudgets,
    ManageBudgets,
    ViewReports,
    ExportData,
    ViewAuditLog,
    ManageIntegrations,
    ManageSettings,
}
```

#### 角色默认权限
```rust
impl MemberRole {
    pub fn default_permissions(&self) -> Vec<Permission> {
        match self {
            MemberRole::Owner => vec![/* 所有权限 */],
            MemberRole::Admin => vec![/* 管理权限 */],
            MemberRole::Member => vec![/* 基本权限 */],
            MemberRole::Viewer => vec![/* 只读权限 */],
        }
    }
}
```

### 4. 邀请模型 (models/invitation.rs)

#### 核心结构
```rust
pub struct Invitation {
    pub id: Uuid,
    pub family_id: Uuid,
    pub inviter_id: Uuid,
    pub invitee_email: String,
    pub role: MemberRole,
    pub invite_code: String,
    pub invite_token: Uuid,
    pub expires_at: DateTime<Utc>,
    pub status: InvitationStatus,
}

pub enum InvitationStatus {
    Pending,
    Accepted,
    Expired,
    Cancelled,
}
```

#### 业务方法
- `create()` - 创建邀请
- `accept()` - 接受邀请
- `cancel()` - 取消邀请
- `is_valid()` - 检查有效性
- `is_expired()` - 检查过期

### 5. 审计日志模型 (models/audit.rs)

#### 核心结构
```rust
pub struct AuditLog {
    pub id: Uuid,
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub action: AuditAction,
    pub entity_type: String,
    pub entity_id: Option<Uuid>,
    pub old_values: Option<serde_json::Value>,
    pub new_values: Option<serde_json::Value>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: DateTime<Utc>,
}

pub enum AuditAction {
    Create,
    Update,
    Delete,
    View,
    Export,
}
```

## 设计原则

### 1. 领域驱动设计
- 模型封装业务逻辑
- 保持模型独立于框架
- 明确的聚合边界

### 2. 不变量保护
- Owner角色唯一性
- 权限一致性
- 成员状态完整性

### 3. 类型安全
- 使用强类型枚举
- 避免字符串魔法值
- 编译时类型检查

### 4. 测试友好
- 模型可独立测试
- Mock友好接口
- 清晰的错误类型

## 模型交互

```
User
  ↓
Family ← FamilyMember → Permission
  ↓         ↓
Invitation  AuditLog
```

## 错误处理

```rust
#[derive(Debug, thiserror::Error)]
pub enum DomainError {
    #[error("Permission denied")]
    PermissionDenied,
    
    #[error("Invalid role")]
    InvalidRole,
    
    #[error("Family not found")]
    FamilyNotFound,
    
    #[error("Member already exists")]
    MemberAlreadyExists,
    
    #[error("Invitation expired")]
    InvitationExpired,
}
```

## 实现优先级

1. **Phase 1**: 基础模型
   - Permission枚举和辅助方法
   - MemberRole及默认权限

2. **Phase 2**: 核心实体
   - Family模型和方法
   - FamilyMember模型

3. **Phase 3**: 流程支持
   - Invitation模型
   - AuditLog模型

## 测试策略

1. 单元测试每个模型方法
2. 测试权限计算逻辑
3. 测试状态转换
4. 测试业务规则验证

---

设计人: Claude Code
日期: 2025-09-03