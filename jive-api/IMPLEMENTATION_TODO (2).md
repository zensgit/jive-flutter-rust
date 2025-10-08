# Jive Family 多用户协作 - 代码实施TODO计划

## 📋 概述

本文档详细列出了实现 Jive Family 多用户协作功能的所有代码任务，包括具体的文件创建、修改内容和实施顺序。

## 🎯 实施目标

- 实现完整的 Family 管理功能
- 支持用户多 Family 归属
- 实现智能邀请机制
- 建立细粒度权限系统
- 确保数据隔离

## 📅 时间规划

- **MVP版本**: 3天（基础功能）
- **完整版本**: 8天（全部功能）
- **优化版本**: 2周（包含测试和优化）

---

## Phase 1: 数据库层（Day 1）

### ✅ TODO 1.1: 创建数据库迁移脚本

**文件**: `migrations/007_enhance_family_system.sql`

```sql
-- 增强 Family 系统的数据库迁移

-- 1. 更新 users 表
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS current_family_id UUID REFERENCES families(id),
ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}'::jsonb;

-- 2. 更新 families 表
ALTER TABLE families 
ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'CNY',
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
ADD COLUMN IF NOT EXISTS locale VARCHAR(10) DEFAULT 'zh-CN',
ADD COLUMN IF NOT EXISTS date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD';

-- 3. 更新 family_members 表
ALTER TABLE family_members 
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE;

-- 4. 创建邀请表
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
    CONSTRAINT invitations_role_check CHECK (role IN ('owner', 'admin', 'member', 'viewer'))
);

-- 5. 创建索引
CREATE INDEX IF NOT EXISTS idx_invitations_family_id ON invitations(family_id);
CREATE INDEX IF NOT EXISTS idx_invitations_invitee_email ON invitations(invitee_email);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations(expires_at);
CREATE INDEX IF NOT EXISTS idx_family_members_is_active ON family_members(is_active);

-- 6. 创建审计日志表（可选）
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

CREATE INDEX IF NOT EXISTS idx_family_audit_logs_family_id ON family_audit_logs(family_id);
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_user_id ON family_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_family_audit_logs_created_at ON family_audit_logs(created_at);
```

### ✅ TODO 1.2: 创建数据迁移脚本（现有数据）

**文件**: `migrations/008_migrate_existing_users.sql`

```sql
-- 为现有用户创建默认 Family 和成员关系

-- 为没有 Family 的现有用户创建个人 Family
INSERT INTO family_members (family_id, user_id, role, joined_at)
SELECT 
    f.id,
    u.id,
    'owner',
    NOW()
FROM users u
JOIN families f ON f.owner_id = u.id
WHERE NOT EXISTS (
    SELECT 1 FROM family_members fm 
    WHERE fm.user_id = u.id AND fm.family_id = f.id
);

-- 更新用户的 current_family_id
UPDATE users u
SET current_family_id = (
    SELECT f.id 
    FROM families f 
    WHERE f.owner_id = u.id 
    LIMIT 1
)
WHERE u.current_family_id IS NULL;
```

---

## Phase 2: 领域模型层（Day 2）

### ✅ TODO 2.1: 创建领域模块入口

**文件**: `src/domain/mod.rs`

```rust
//! 领域模型层
//! 定义核心业务实体和值对象

pub mod family;
pub mod user;
pub mod permission;
pub mod membership;
pub mod invitation;

pub use family::*;
pub use user::*;
pub use permission::*;
pub use membership::*;
pub use invitation::*;
```

### ✅ TODO 2.2: Family 实体

**文件**: `src/domain/family.rs`

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Family - 多用户协作的核心实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Family {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub owner_id: Uuid,
    pub currency: String,
    pub timezone: String,
    pub locale: String,
    pub date_format: String,
    pub invite_code: Option<String>,
    pub settings: FamilySettings,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Family 设置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilySettings {
    pub auto_categorize: bool,
    pub require_approval: bool,
    pub approval_threshold: Option<f64>,
    pub shared_categories: bool,
    pub shared_tags: bool,
    pub shared_payees: bool,
}

impl Default for FamilySettings {
    fn default() -> Self {
        Self {
            auto_categorize: true,
            require_approval: false,
            approval_threshold: None,
            shared_categories: true,
            shared_tags: true,
            shared_payees: true,
        }
    }
}

impl Family {
    /// 创建新的 Family
    pub fn new(name: String, owner_id: Uuid) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            description: None,
            owner_id,
            currency: "CNY".to_string(),
            timezone: "Asia/Shanghai".to_string(),
            locale: "zh-CN".to_string(),
            date_format: "YYYY-MM-DD".to_string(),
            invite_code: Some(Self::generate_invite_code()),
            settings: FamilySettings::default(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    /// 生成邀请码
    fn generate_invite_code() -> String {
        use rand::Rng;
        const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let mut rng = rand::thread_rng();
        (0..8)
            .map(|_| {
                let idx = rng.gen_range(0..CHARSET.len());
                CHARSET[idx] as char
            })
            .collect()
    }
}
```

### ✅ TODO 2.3: 权限定义

**文件**: `src/domain/permission.rs`

```rust
use serde::{Deserialize, Serialize};

/// Family 角色
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FamilyRole {
    Viewer,
    Member,
    Admin,
    Owner,
}

/// 细粒度权限
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Permission {
    // Family 管理
    ViewFamilyInfo,
    UpdateFamilyInfo,
    DeleteFamily,
    
    // 成员管理
    ViewMembers,
    InviteMembers,
    RemoveMembers,
    UpdateMemberRoles,
    
    // 账户权限
    ViewAccounts,
    CreateAccounts,
    EditAccounts,
    DeleteAccounts,
    
    // 交易权限
    ViewTransactions,
    CreateTransactions,
    EditTransactions,
    DeleteTransactions,
    BulkEditTransactions,
    
    // 分类权限
    ViewCategories,
    ManageCategories,
    
    // 预算权限
    ViewBudgets,
    ManageBudgets,
    
    // 报表权限
    ViewReports,
    ExportData,
    
    // 高级权限
    ViewAuditLog,
    ManageIntegrations,
    ManageSettings,
}

impl FamilyRole {
    /// 获取角色的默认权限
    pub fn default_permissions(&self) -> Vec<Permission> {
        use Permission::*;
        
        match self {
            FamilyRole::Owner => vec![
                // 拥有所有权限
                ViewFamilyInfo, UpdateFamilyInfo, DeleteFamily,
                ViewMembers, InviteMembers, RemoveMembers, UpdateMemberRoles,
                ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts,
                ViewTransactions, CreateTransactions, EditTransactions, 
                DeleteTransactions, BulkEditTransactions,
                ViewCategories, ManageCategories,
                ViewBudgets, ManageBudgets,
                ViewReports, ExportData,
                ViewAuditLog, ManageIntegrations, ManageSettings,
            ],
            
            FamilyRole::Admin => vec![
                // 除了删除 Family 外的所有权限
                ViewFamilyInfo, UpdateFamilyInfo,
                ViewMembers, InviteMembers, RemoveMembers, UpdateMemberRoles,
                ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts,
                ViewTransactions, CreateTransactions, EditTransactions, 
                DeleteTransactions, BulkEditTransactions,
                ViewCategories, ManageCategories,
                ViewBudgets, ManageBudgets,
                ViewReports, ExportData,
                ViewAuditLog, ManageIntegrations, ManageSettings,
            ],
            
            FamilyRole::Member => vec![
                // 可以查看和编辑数据
                ViewFamilyInfo, ViewMembers,
                ViewAccounts, CreateAccounts, EditAccounts,
                ViewTransactions, CreateTransactions, EditTransactions,
                ViewCategories,
                ViewBudgets,
                ViewReports, ExportData,
            ],
            
            FamilyRole::Viewer => vec![
                // 只能查看
                ViewFamilyInfo, ViewMembers,
                ViewAccounts,
                ViewTransactions,
                ViewCategories,
                ViewBudgets,
                ViewReports,
            ],
        }
    }

    /// 检查是否可以邀请指定角色
    pub fn can_invite(&self, target_role: &FamilyRole) -> bool {
        match self {
            FamilyRole::Owner => true, // Owner 可以邀请任何角色
            FamilyRole::Admin => target_role <= &FamilyRole::Admin, // Admin 不能邀请 Owner
            _ => false, // Member 和 Viewer 不能邀请
        }
    }

    /// 检查是否可以操作指定角色
    pub fn can_manage(&self, target_role: &FamilyRole) -> bool {
        self > target_role // 只能管理比自己低的角色
    }
}
```

### ✅ TODO 2.4: 成员关系

**文件**: `src/domain/membership.rs`

```rust
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use super::permission::{FamilyRole, Permission};

/// Family 成员关系
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyMembership {
    pub id: Uuid,
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub nickname: Option<String>,
    pub invited_by: Option<Uuid>,
    pub is_active: bool,
    pub joined_at: DateTime<Utc>,
    pub last_active_at: Option<DateTime<Utc>>,
}

impl FamilyMembership {
    /// 创建新的成员关系
    pub fn new(family_id: Uuid, user_id: Uuid, role: FamilyRole) -> Self {
        Self {
            id: Uuid::new_v4(),
            family_id,
            user_id,
            role: role.clone(),
            permissions: role.default_permissions(),
            nickname: None,
            invited_by: None,
            is_active: true,
            joined_at: Utc::now(),
            last_active_at: None,
        }
    }

    /// 检查是否有指定权限
    pub fn has_permission(&self, permission: &Permission) -> bool {
        self.is_active && self.permissions.contains(permission)
    }
}
```

---

## Phase 3: 服务层（Day 3-4）

### ✅ TODO 3.1: 服务层入口

**文件**: `src/services/mod.rs`

```rust
//! 服务层
//! 包含业务逻辑实现

pub mod family_service;
pub mod member_service;
pub mod auth_service;
pub mod invitation_service;
pub mod context;

pub use family_service::*;
pub use member_service::*;
pub use auth_service::*;
pub use invitation_service::*;
pub use context::*;
```

### ✅ TODO 3.2: ServiceContext

**文件**: `src/services/context.rs`

```rust
use uuid::Uuid;
use crate::domain::{FamilyRole, Permission};
use crate::error::{ApiError, ApiResult};

/// 服务上下文，包含当前请求的用户和权限信息
#[derive(Debug, Clone)]
pub struct ServiceContext {
    pub user_id: Uuid,
    pub family_id: Uuid,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub request_id: String,
}

impl ServiceContext {
    /// 检查是否有指定权限
    pub fn has_permission(&self, permission: &Permission) -> bool {
        self.permissions.contains(permission)
    }

    /// 要求指定权限，无权限时返回错误
    pub fn require_permission(&self, permission: Permission) -> ApiResult<()> {
        if !self.has_permission(&permission) {
            return Err(ApiError::Forbidden(
                format!("Missing required permission: {:?}", permission)
            ));
        }
        Ok(())
    }

    /// 检查是否可以操作目标角色
    pub fn can_manage_role(&self, target_role: &FamilyRole) -> bool {
        self.role.can_manage(target_role)
    }
}
```

### ✅ TODO 3.3: Family 服务

**文件**: `src/services/family_service.rs`

```rust
use sqlx::PgPool;
use uuid::Uuid;
use crate::domain::{Family, FamilyMembership, FamilyRole};
use crate::error::{ApiError, ApiResult};
use super::ServiceContext;

pub struct FamilyService {
    pool: PgPool,
}

impl FamilyService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// 创建新的 Family
    pub async fn create_family(
        &self,
        user_id: Uuid,
        name: String,
        description: Option<String>,
    ) -> ApiResult<Family> {
        let family = Family::new(name, user_id);
        
        // 开始事务
        let mut tx = self.pool.begin().await?;
        
        // 插入 Family
        sqlx::query!(
            r#"
            INSERT INTO families (id, name, description, owner_id, currency, timezone, locale, invite_code, settings, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
            "#,
            family.id,
            family.name,
            description,
            user_id,
            family.currency,
            family.timezone,
            family.locale,
            family.invite_code,
            serde_json::to_value(&family.settings)?
        )
        .execute(&mut *tx)
        .await?;
        
        // 创建 Owner 成员关系
        let membership = FamilyMembership::new(family.id, user_id, FamilyRole::Owner);
        sqlx::query!(
            r#"
            INSERT INTO family_members (id, family_id, user_id, role, permissions, is_active, joined_at)
            VALUES ($1, $2, $3, $4, $5, $6, NOW())
            "#,
            membership.id,
            family.id,
            user_id,
            "owner",
            serde_json::to_value(&membership.permissions)?,
            true
        )
        .execute(&mut *tx)
        .await?;
        
        // 创建默认 Ledger
        sqlx::query!(
            r#"
            INSERT INTO ledgers (id, family_id, name, currency, created_by, created_at, updated_at)
            VALUES (gen_random_uuid(), $1, '默认账本', $2, $3, NOW(), NOW())
            "#,
            family.id,
            family.currency,
            user_id
        )
        .execute(&mut *tx)
        .await?;
        
        // 提交事务
        tx.commit().await?;
        
        Ok(family)
    }

    /// 获取用户的所有 Family
    pub async fn get_user_families(&self, user_id: Uuid) -> ApiResult<Vec<Family>> {
        let families = sqlx::query_as!(
            Family,
            r#"
            SELECT f.* FROM families f
            JOIN family_members fm ON f.id = fm.family_id
            WHERE fm.user_id = $1 AND fm.is_active = true
            ORDER BY fm.joined_at DESC
            "#,
            user_id
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(families)
    }

    /// 切换当前 Family
    pub async fn switch_family(
        &self,
        user_id: Uuid,
        family_id: Uuid,
    ) -> ApiResult<ServiceContext> {
        // 验证用户是该 Family 的成员
        let membership = self.get_membership(user_id, family_id).await?;
        if !membership.is_active {
            return Err(ApiError::Forbidden("Membership is not active".into()));
        }
        
        // 更新用户的 current_family_id
        sqlx::query!(
            "UPDATE users SET current_family_id = $1 WHERE id = $2",
            family_id,
            user_id
        )
        .execute(&self.pool)
        .await?;
        
        // 构建新的上下文
        Ok(ServiceContext {
            user_id,
            family_id,
            role: membership.role,
            permissions: membership.permissions,
            request_id: Uuid::new_v4().to_string(),
        })
    }

    async fn get_membership(&self, user_id: Uuid, family_id: Uuid) -> ApiResult<FamilyMembership> {
        // 实现获取成员关系逻辑
        todo!()
    }
}
```

---

## Phase 4: API 处理器层（Day 5）

### ✅ TODO 4.1: Family API 处理器

**文件**: `src/handlers/family.rs`

```rust
use axum::{
    extract::{Path, State, Query},
    response::Json,
    Extension,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use crate::services::{FamilyService, ServiceContext};
use crate::error::ApiResult;

#[derive(Debug, Deserialize)]
pub struct CreateFamilyRequest {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct FamilyResponse {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub role: String,
    pub member_count: i32,
    pub created_at: String,
}

/// 获取用户的 Family 列表
pub async fn list_families(
    Extension(context): Extension<ServiceContext>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<FamilyResponse>>> {
    let service = FamilyService::new(pool);
    let families = service.get_user_families(context.user_id).await?;
    
    // 转换为响应格式
    let response = families.into_iter().map(|f| FamilyResponse {
        id: f.id,
        name: f.name,
        description: f.description,
        role: "owner".to_string(), // TODO: 从 membership 获取
        member_count: 1, // TODO: 查询实际成员数
        created_at: f.created_at.to_rfc3339(),
    }).collect();
    
    Ok(Json(response))
}

/// 创建新的 Family
pub async fn create_family(
    Extension(context): Extension<ServiceContext>,
    State(pool): State<PgPool>,
    Json(req): Json<CreateFamilyRequest>,
) -> ApiResult<Json<FamilyResponse>> {
    let service = FamilyService::new(pool);
    let family = service.create_family(
        context.user_id,
        req.name,
        req.description,
    ).await?;
    
    Ok(Json(FamilyResponse {
        id: family.id,
        name: family.name,
        description: family.description,
        role: "owner".to_string(),
        member_count: 1,
        created_at: family.created_at.to_rfc3339(),
    }))
}

/// 切换当前 Family
pub async fn switch_family(
    Extension(context): Extension<ServiceContext>,
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
) -> ApiResult<Json<serde_json::Value>> {
    let service = FamilyService::new(pool);
    let new_context = service.switch_family(context.user_id, family_id).await?;
    
    // TODO: 生成新的 JWT Token
    
    Ok(Json(serde_json::json!({
        "success": true,
        "family_id": new_context.family_id,
        "role": format!("{:?}", new_context.role),
    })))
}
```

### ✅ TODO 4.2: 更新 main.rs 路由

**文件**: `src/main.rs`（添加新路由）

```rust
// 在现有路由后添加

// Family 管理 API
.route("/api/v1/families", get(family::list_families))
.route("/api/v1/families", post(family::create_family))
.route("/api/v1/families/:id", get(family::get_family))
.route("/api/v1/families/:id", put(family::update_family))
.route("/api/v1/families/:id/switch", post(family::switch_family))

// 成员管理 API
.route("/api/v1/families/:id/members", get(members::list_members))
.route("/api/v1/families/:id/members/invite", post(members::invite_member))
.route("/api/v1/families/:id/members/:member_id", put(members::update_member_role))
.route("/api/v1/families/:id/members/:member_id", delete(members::remove_member))

// 邀请 API
.route("/api/v1/invitations/:code", get(invitations::get_invitation))
.route("/api/v1/invitations/:code/accept", post(invitations::accept_invitation))
```

---

## Phase 5: 中间件和权限（Day 6）

### ✅ TODO 5.1: 权限中间件

**文件**: `src/middleware/permission.rs`

```rust
use axum::{
    extract::{Request, State},
    middleware::Next,
    response::Response,
};
use crate::domain::Permission;
use crate::services::ServiceContext;
use crate::error::ApiError;

/// 权限检查中间件
pub async fn require_permission(
    permission: Permission,
    Extension(context): Extension<ServiceContext>,
    request: Request,
    next: Next,
) -> Result<Response, ApiError> {
    // 检查权限
    context.require_permission(permission)?;
    
    // 继续处理请求
    Ok(next.run(request).await)
}
```

---

## Phase 6: 测试（Day 7-8）

### ✅ TODO 6.1: 单元测试

**文件**: `tests/unit/family_service_test.rs`

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_family() {
        // 测试创建 Family
    }

    #[tokio::test]
    async fn test_invite_existing_user() {
        // 测试邀请已存在用户
    }

    #[tokio::test]
    async fn test_role_permissions() {
        // 测试角色权限
    }
}
```

### ✅ TODO 6.2: 集成测试

**文件**: `tests/integration/family_flow_test.rs`

```rust
#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn test_complete_family_flow() {
        // 1. 用户注册
        // 2. 创建 Family
        // 3. 邀请成员
        // 4. 接受邀请
        // 5. 切换 Family
        // 6. 权限验证
    }
}
```

---

## 🚀 快速启动指南

### Step 1: 运行数据库迁移
```bash
psql postgresql://postgres:postgres@localhost:5433/jive_money < migrations/007_enhance_family_system.sql
psql postgresql://postgres:postgres@localhost:5433/jive_money < migrations/008_migrate_existing_users.sql
```

### Step 2: 创建新文件结构
```bash
mkdir -p src/domain src/services src/repositories
touch src/domain/mod.rs src/domain/family.rs src/domain/permission.rs
touch src/services/mod.rs src/services/family_service.rs
touch src/handlers/family.rs src/handlers/members.rs
```

### Step 3: 编译测试
```bash
cargo build
cargo test
```

### Step 4: 运行服务
```bash
cargo run --bin jive-api
```

---

## ✅ 完成标准

每个 TODO 项完成后需要验证：

1. **编译通过** - 无编译错误
2. **测试通过** - 相关单元测试通过
3. **API 可用** - 通过 curl/Postman 测试
4. **数据正确** - 数据库数据符合预期

## 📝 注意事项

1. **保持向后兼容** - 不破坏现有 API
2. **增量开发** - 每个阶段都可独立部署
3. **代码审查** - 重要功能需要 review
4. **文档同步** - 及时更新 API 文档

---

**文档版本**: 1.0.0  
**更新日期**: 2025-09-03  
**作者**: Jive 开发团队