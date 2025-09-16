# TODO 005: 权限中间件设计文档

## 设计目标

实现细粒度的权限控制中间件，支持在路由级别进行权限验证，确保API端点的访问控制。

## 中间件架构

### 1. 权限验证层级

```
请求流程:
Request → 认证中间件 → Family上下文中间件 → 权限中间件 → Handler
```

### 2. 权限中间件类型

#### 基础权限中间件
- `require_permission` - 检查单个权限
- `require_any_permission` - 检查任一权限
- `require_all_permissions` - 检查所有权限

#### 角色中间件
- `require_owner` - 要求Owner角色
- `require_admin` - 要求Admin及以上
- `require_member` - 要求Member及以上

#### 组合中间件
- `permission_guard` - 灵活的权限守卫

## 实现方案

### 1. 权限中间件 (middleware/permission.rs)

```rust
pub struct PermissionMiddleware {
    required_permission: Permission,
}

pub struct MultiPermissionMiddleware {
    required_permissions: Vec<Permission>,
    require_all: bool,
}

pub struct RoleMiddleware {
    minimum_role: MemberRole,
}
```

### 2. 使用方式

#### 路由配置
```rust
Router::new()
    .route("/accounts", post(create_account))
    .layer(permission_layer(Permission::CreateAccounts))
    
    .route("/family/settings", put(update_settings))
    .layer(role_layer(MemberRole::Admin))
    
    .route("/audit-logs", get(view_logs))
    .layer(any_permission_layer(vec![
        Permission::ViewAuditLog,
        Permission::ManageSettings,
    ]))
```

#### Handler级别
```rust
#[require_permission(Permission::DeleteAccounts)]
async fn delete_account(/* ... */) -> Result<(), ApiError> {
    // 处理逻辑
}
```

### 3. 权限检查逻辑

```rust
// 基础权限检查
if !context.can_perform(permission) {
    return Err(StatusCode::FORBIDDEN);
}

// 角色检查
if context.role < minimum_role {
    return Err(StatusCode::FORBIDDEN);
}

// 复合权限检查
let has_permission = if require_all {
    permissions.iter().all(|p| context.can_perform(*p))
} else {
    permissions.iter().any(|p| context.can_perform(*p))
};
```

## 错误处理

### 错误响应格式
```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_PERMISSIONS",
    "message": "You need 'CreateAccounts' permission to perform this action",
    "required_permission": "CreateAccounts",
    "user_permissions": ["ViewAccounts", "ViewTransactions"]
  }
}
```

### 错误码
- `INSUFFICIENT_PERMISSIONS` - 权限不足
- `ROLE_TOO_LOW` - 角色级别不够
- `FAMILY_ACCESS_DENIED` - Family访问被拒

## 审计集成

### 权限拒绝记录
```rust
// 记录权限拒绝事件
audit_service.log_permission_denied(
    family_id,
    user_id,
    required_permission,
    endpoint,
);
```

## 缓存策略

### 权限缓存
```rust
// 缓存用户权限，减少数据库查询
pub struct PermissionCache {
    cache: HashMap<(Uuid, Uuid), (Vec<Permission>, Instant)>,
    ttl: Duration,
}
```

## 动态权限

### 条件权限
```rust
// 基于条件的权限检查
pub async fn check_conditional_permission(
    context: &ServiceContext,
    resource: &Resource,
) -> bool {
    match resource {
        Resource::Account(account) => {
            // 只能编辑自己创建的账户
            account.created_by == context.user_id
                || context.can_perform(Permission::EditAllAccounts)
        },
        _ => false,
    }
}
```

## 权限继承

### 权限组
```rust
pub enum PermissionGroup {
    AccountManagement,  // 包含所有账户相关权限
    TransactionManagement,  // 包含所有交易相关权限
    FamilyAdministration,  // 包含所有管理权限
}

impl PermissionGroup {
    pub fn permissions(&self) -> Vec<Permission> {
        match self {
            PermissionGroup::AccountManagement => vec![
                Permission::ViewAccounts,
                Permission::CreateAccounts,
                Permission::EditAccounts,
                Permission::DeleteAccounts,
            ],
            // ...
        }
    }
}
```

## 测试策略

### 单元测试
```rust
#[test]
fn test_permission_check() {
    let context = create_test_context(MemberRole::Member);
    assert!(context.can_perform(Permission::ViewAccounts));
    assert!(!context.can_perform(Permission::DeleteFamily));
}
```

### 集成测试
```rust
#[tokio::test]
async fn test_permission_middleware() {
    let app = create_test_app();
    let response = request_with_permission(
        "/api/v1/accounts",
        Method::DELETE,
        Permission::ViewAccounts, // 错误的权限
    ).await;
    
    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}
```

## 性能考虑

1. **权限预加载**
   - 在认证时加载所有权限
   - 避免每次请求查询数据库

2. **缓存优化**
   - 缓存用户权限5分钟
   - 权限变更时清除缓存

3. **批量检查**
   - 一次性检查多个权限
   - 减少重复计算

## 扩展性

### 插件式权限
```rust
pub trait PermissionPlugin {
    fn check(&self, context: &ServiceContext) -> Result<(), PermissionError>;
}

// 自定义权限插件
struct CustomPermissionPlugin;
impl PermissionPlugin for CustomPermissionPlugin {
    fn check(&self, context: &ServiceContext) -> Result<(), PermissionError> {
        // 自定义逻辑
    }
}
```

---

设计人: Claude Code
日期: 2025-09-04