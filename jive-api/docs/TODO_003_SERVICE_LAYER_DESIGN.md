# TODO 003: 服务层设计文档

## 设计目标

创建业务服务层，封装Family系统的核心业务逻辑，提供事务管理和业务规则实施。

## 服务架构

### 1. Family服务 (services/family_service.rs)

#### 核心功能
```rust
pub struct FamilyService {
    pool: PgPool,
}
```

#### 主要方法
- `create_family()` - 创建Family并设置owner
- `get_family()` - 获取Family信息
- `update_family()` - 更新Family设置
- `delete_family()` - 删除Family（含级联）
- `get_user_families()` - 获取用户所有Family
- `switch_family()` - 切换当前Family

### 2. 成员服务 (services/member_service.rs)

#### 核心功能
```rust
pub struct MemberService {
    pool: PgPool,
}
```

#### 主要方法
- `add_member()` - 添加成员
- `remove_member()` - 移除成员
- `update_member_role()` - 更新角色
- `update_member_permissions()` - 更新权限
- `get_family_members()` - 获取所有成员
- `check_permission()` - 检查权限

### 3. 邀请服务 (services/invitation_service.rs)

#### 核心功能
```rust
pub struct InvitationService {
    pool: PgPool,
}
```

#### 主要方法
- `create_invitation()` - 创建邀请
- `accept_invitation()` - 接受邀请
- `cancel_invitation()` - 取消邀请
- `get_pending_invitations()` - 获取待处理邀请
- `validate_invite_code()` - 验证邀请码
- `cleanup_expired()` - 清理过期邀请

### 4. 认证服务增强 (services/auth_service.rs)

#### 扩展功能
- `register_with_family()` - 注册并创建个人Family
- `get_user_context()` - 获取用户上下文（含Family）
- `validate_family_access()` - 验证Family访问权限

### 5. 审计服务 (services/audit_service.rs)

#### 核心功能
```rust
pub struct AuditService {
    pool: PgPool,
}
```

#### 主要方法
- `log_action()` - 记录操作
- `get_audit_logs()` - 查询审计日志
- `export_audit_report()` - 导出审计报告

## 事务管理

### 复杂事务示例

```rust
// 接受邀请的事务流程
pub async fn accept_invitation_transaction(
    pool: &PgPool,
    invite_code: &str,
    user_id: Uuid,
) -> Result<(), ServiceError> {
    let mut tx = pool.begin().await?;
    
    // 1. 验证并更新邀请
    let invitation = validate_and_update_invitation(&mut tx, invite_code).await?;
    
    // 2. 创建成员关系
    create_family_member(&mut tx, invitation.family_id, user_id, invitation.role).await?;
    
    // 3. 更新用户current_family_id
    update_user_current_family(&mut tx, user_id, invitation.family_id).await?;
    
    // 4. 记录审计日志
    log_invitation_accepted(&mut tx, &invitation, user_id).await?;
    
    tx.commit().await?;
    Ok(())
}
```

## 服务上下文

```rust
#[derive(Clone)]
pub struct ServiceContext {
    pub user_id: Uuid,
    pub family_id: Uuid,
    pub role: MemberRole,
    pub permissions: Vec<Permission>,
}

impl ServiceContext {
    pub fn can_perform(&self, permission: Permission) -> bool {
        self.permissions.contains(&permission)
    }
    
    pub fn require_permission(&self, permission: Permission) -> Result<(), ServiceError> {
        if !self.can_perform(permission) {
            return Err(ServiceError::PermissionDenied);
        }
        Ok(())
    }
}
```

## 错误处理

```rust
#[derive(Debug, thiserror::Error)]
pub enum ServiceError {
    #[error("Database error: {0}")]
    DatabaseError(#[from] sqlx::Error),
    
    #[error("Permission denied")]
    PermissionDenied,
    
    #[error("Resource not found: {0}")]
    NotFound(String),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
    
    #[error("Business rule violation: {0}")]
    BusinessRuleViolation(String),
    
    #[error("Conflict: {0}")]
    Conflict(String),
}
```

## 业务规则实施

### 1. Family规则
- 每个用户至少属于一个Family
- Family必须有且只有一个Owner
- 删除Family需要Owner权限

### 2. 成员规则
- Owner不能被移除
- Owner角色不能被修改
- 成员权限不能超过其角色默认权限

### 3. 邀请规则
- 邀请码8位，唯一
- 默认7天过期
- 只有活跃成员可以发送邀请

## 缓存策略

```rust
// 使用Redis缓存权限
pub async fn get_user_permissions_cached(
    redis: &RedisClient,
    pool: &PgPool,
    user_id: Uuid,
    family_id: Uuid,
) -> Result<Vec<Permission>, ServiceError> {
    let cache_key = format!("permissions:{}:{}", user_id, family_id);
    
    // 尝试从缓存获取
    if let Some(cached) = redis.get(&cache_key).await? {
        return Ok(cached);
    }
    
    // 从数据库获取
    let permissions = fetch_permissions_from_db(pool, user_id, family_id).await?;
    
    // 写入缓存，5分钟过期
    redis.setex(&cache_key, 300, &permissions).await?;
    
    Ok(permissions)
}
```

## 实现优先级

1. **Phase 1**: 核心服务
   - FamilyService基础方法
   - MemberService权限检查

2. **Phase 2**: 邀请流程
   - InvitationService完整实现
   - 事务管理

3. **Phase 3**: 增强功能
   - AuditService
   - 缓存集成

## 测试策略

1. 单元测试服务方法
2. 集成测试事务流程
3. 测试权限检查逻辑
4. 测试并发场景
5. 测试错误恢复

---

设计人: Claude Code
日期: 2025-09-04