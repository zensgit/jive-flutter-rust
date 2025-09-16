# TODO 005: 权限中间件功能说明

## 实现概述

实现了细粒度的权限控制中间件系统，支持在路由级别进行权限验证，确保API端点的访问控制。

## 实现的中间件功能

### 1. 基础权限中间件

#### require_permission
```rust
pub async fn require_permission(required: Permission)
```
- **功能**: 检查单个权限
- **使用场景**: 需要特定权限的端点
- **示例**: 创建账户需要CreateAccounts权限

#### require_any_permission
```rust
pub async fn require_any_permission(permissions: Vec<Permission>)
```
- **功能**: 检查多个权限中的任意一个
- **使用场景**: 多个权限都可以访问的端点
- **示例**: 查看审计日志需要ViewAuditLog或ManageSettings权限

#### require_all_permissions
```rust
pub async fn require_all_permissions(permissions: Vec<Permission>)
```
- **功能**: 检查必须拥有所有指定权限
- **使用场景**: 需要多个权限组合的高级操作
- **示例**: 批量删除需要DeleteAccounts和BulkOperations权限

### 2. 角色中间件

#### require_minimum_role
```rust
pub async fn require_minimum_role(minimum_role: MemberRole)
```
- **功能**: 检查最低角色要求
- **角色级别**: Owner(4) > Admin(3) > Member(2) > Viewer(1)
- **示例**: 管理设置需要Admin及以上角色

#### require_owner
```rust
pub async fn require_owner()
```
- **功能**: 仅允许Owner访问
- **使用场景**: 删除Family、转移所有权等敏感操作

#### require_admin_or_owner
```rust
pub async fn require_admin_or_owner()
```
- **功能**: 允许Admin和Owner访问
- **使用场景**: 管理成员、更新设置等管理操作

### 3. 权限缓存系统

#### PermissionCache
```rust
pub struct PermissionCache {
    cache: Arc<RwLock<HashMap<(Uuid, Uuid), (Vec<Permission>, Instant)>>>,
    ttl: Duration,
}
```

**功能特性**:
- **缓存键**: (user_id, family_id)
- **TTL**: 可配置的过期时间
- **操作**: get, set, invalidate, clear
- **线程安全**: 使用RwLock实现并发访问

**性能优势**:
- 减少数据库查询
- 5分钟缓存时间
- 权限变更时自动失效

### 4. 条件权限检查

#### check_resource_permission
```rust
pub async fn check_resource_permission(
    context: &ServiceContext,
    resource: ResourceOwnership,
    permission: Permission,
) -> bool
```

**资源所有权类型**:
- **OwnedBy(Uuid)**: 个人拥有的资源
- **SharedInFamily(Uuid)**: Family共享资源
- **Public**: 公开资源

**使用场景**:
- 编辑自己创建的账户
- 查看Family共享的交易
- 访问公开的模板

### 5. 权限组

#### PermissionGroup
```rust
pub enum PermissionGroup {
    AccountManagement,     // 账户管理权限组
    TransactionManagement, // 交易管理权限组
    FamilyAdministration, // Family管理权限组
    DataViewing,          // 数据查看权限组
}
```

**功能方法**:
- `permissions()`: 获取组内所有权限
- `check_any()`: 检查是否有任意权限
- `check_all()`: 检查是否有全部权限

### 6. 错误处理

#### PermissionError
```rust
pub struct PermissionError {
    pub code: String,
    pub message: String,
    pub required_permission: Option<String>,
    pub required_role: Option<String>,
}
```

**错误类型**:
- `INSUFFICIENT_PERMISSIONS`: 权限不足
- `INSUFFICIENT_ROLE`: 角色级别不够
- `FAMILY_ACCESS_DENIED`: Family访问被拒

## 路由集成示例

### 1. 简单权限检查
```rust
.route("/accounts", post(create_account))
.layer(middleware::from_fn(move |req, next| {
    Box::pin(require_permission(Permission::CreateAccounts)(req, next))
}))
```

### 2. 多权限检查
```rust
.route("/audit-logs", get(view_logs))
.layer(middleware::from_fn(move |req, next| {
    Box::pin(require_any_permission(vec![
        Permission::ViewAuditLog,
        Permission::ManageSettings,
    ])(req, next))
}))
```

### 3. 角色检查
```rust
.route("/family/delete", delete(delete_family))
.layer(middleware::from_fn(require_owner))
```

### 4. 中间件链
```rust
.route("/members/:id", put(update_member))
.layer(middleware::from_fn(require_permission(Permission::UpdateMemberRoles)))
.layer(middleware::from_fn(family_context))
.layer(middleware::from_fn(require_auth))
```

## 使用宏简化

```rust
#[macro_export]
macro_rules! with_permission {
    ($router:expr, $path:expr, $method:ident($handler:expr), $permission:expr) => {
        $router.route(
            $path,
            $method($handler)
                .layer(/* 权限中间件 */)
                .layer(/* 上下文中间件 */)
                .layer(/* 认证中间件 */)
        )
    };
}
```

## 权限矩阵示例

| 端点 | Owner | Admin | Member | Viewer |
|-----|-------|-------|--------|--------|
| GET /families | ✅ | ✅ | ✅ | ✅ |
| PUT /families/:id | ✅ | ✅ | ❌ | ❌ |
| DELETE /families/:id | ✅ | ❌ | ❌ | ❌ |
| POST /members | ✅ | ✅ | ❌ | ❌ |
| DELETE /members/:id | ✅ | ✅ | ❌ | ❌ |
| GET /transactions | ✅ | ✅ | ✅ | ✅ |
| POST /transactions | ✅ | ✅ | ✅ | ❌ |
| GET /audit-logs | ✅ | ✅ | ❌ | ❌ |

## 性能优化

### 1. 缓存策略
- 权限缓存5分钟
- LRU淘汰策略预留
- 批量失效机制

### 2. 预加载
- 认证时加载权限
- 减少重复查询
- 上下文复用

### 3. 异步处理
- 非阻塞权限检查
- 并行权限验证
- 快速失败机制

## 安全特性

### 1. 最小权限原则
- 默认拒绝访问
- 明确授权才允许
- 权限不可提升

### 2. 角色层级
- 严格的角色等级
- 不可越级操作
- Owner权限保护

### 3. 审计集成
- 权限拒绝记录
- 敏感操作日志
- 可追溯性保证

## 扩展点

### 1. 动态权限
- 基于资源的权限
- 条件权限规则
- 时间限制权限

### 2. 权限委托
- 临时权限授予
- 权限代理机制
- 审批工作流

### 3. 插件系统
- 自定义权限检查器
- 第三方权限集成
- 权限策略引擎

---

文档编写: Claude Code
日期: 2025-09-04