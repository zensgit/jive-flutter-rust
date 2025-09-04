# TODO 004: API层设计文档

## 设计目标

创建RESTful API端点，提供Family协作系统的HTTP接口，集成认证中间件和权限验证。

## API架构

### 基础路径
```
/api/v1/families      - Family管理
/api/v1/members       - 成员管理  
/api/v1/invitations   - 邀请管理
/api/v1/auth          - 认证相关
/api/v1/audit         - 审计日志
```

## API端点设计

### 1. Family API (handlers/family_handler.rs)

| 方法 | 路径 | 描述 | 权限 |
|------|------|------|------|
| POST | /families | 创建Family | 已认证 |
| GET | /families | 获取用户所有Family | 已认证 |
| GET | /families/:id | 获取Family详情 | ViewFamilyInfo |
| PUT | /families/:id | 更新Family | UpdateFamilyInfo |
| DELETE | /families/:id | 删除Family | DeleteFamily + Owner |
| POST | /families/:id/switch | 切换当前Family | 成员 |
| POST | /families/:id/invite-code | 重新生成邀请码 | InviteMembers |

### 2. Member API (handlers/member_handler.rs)

| 方法 | 路径 | 描述 | 权限 |
|------|------|------|------|
| GET | /families/:id/members | 获取成员列表 | ViewMembers |
| POST | /families/:id/members | 添加成员 | InviteMembers |
| DELETE | /families/:id/members/:user_id | 移除成员 | RemoveMembers |
| PUT | /families/:id/members/:user_id/role | 更新角色 | UpdateMemberRoles |
| PUT | /families/:id/members/:user_id/permissions | 更新权限 | UpdateMemberRoles |

### 3. Invitation API (handlers/invitation_handler.rs)

| 方法 | 路径 | 描述 | 权限 |
|------|------|------|------|
| POST | /invitations | 创建邀请 | InviteMembers |
| GET | /invitations | 获取待处理邀请 | ViewMembers |
| POST | /invitations/accept | 接受邀请 | 已认证 |
| DELETE | /invitations/:id | 取消邀请 | InviteMembers |
| GET | /invitations/validate/:code | 验证邀请码 | 公开 |

### 4. Auth API增强 (handlers/auth.rs)

| 方法 | 路径 | 描述 | 权限 |
|------|------|------|------|
| POST | /auth/register | 注册并创建Family | 公开 |
| POST | /auth/login | 登录 | 公开 |
| GET | /auth/me | 获取当前用户 | 已认证 |
| GET | /auth/context | 获取用户上下文 | 已认证 |
| POST | /auth/refresh | 刷新token | 已认证 |

### 5. Audit API (handlers/audit_handler.rs)

| 方法 | 路径 | 描述 | 权限 |
|------|------|------|------|
| GET | /families/:id/audit-logs | 获取审计日志 | ViewAuditLog |
| GET | /families/:id/audit-logs/export | 导出CSV | ViewAuditLog |

## 请求/响应格式

### 标准响应格式
```json
{
  "success": true,
  "data": {},
  "error": null,
  "timestamp": "2025-09-04T12:00:00Z"
}
```

### 错误响应格式
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "You don't have permission to perform this action",
    "details": {}
  },
  "timestamp": "2025-09-04T12:00:00Z"
}
```

## 中间件集成

### 1. 认证中间件
```rust
pub async fn require_auth(
    State(state): State<AppState>,
    headers: HeaderMap,
    request: Request,
    next: Next,
) -> Response
```

### 2. Family上下文中间件
```rust
pub async fn family_context(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(claims): Extension<Claims>,
    request: Request,
    next: Next,
) -> Response
```

### 3. 权限验证
```rust
pub async fn require_permission(
    permission: Permission,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<(), ApiError>
```

## 请求验证

### 输入验证
- Email格式验证
- UUID格式验证
- 字符串长度限制
- 枚举值验证

### 业务验证
- 唯一性检查
- 关系验证
- 状态验证

## 错误处理

```rust
#[derive(Debug)]
pub enum ApiError {
    BadRequest(String),
    Unauthorized,
    Forbidden,
    NotFound,
    Conflict(String),
    InternalServerError,
    ServiceError(ServiceError),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        // 转换为HTTP响应
    }
}
```

## 路由注册

```rust
pub fn family_routes() -> Router<AppState> {
    Router::new()
        .route("/families", post(create_family).get(list_families))
        .route("/families/:id", get(get_family).put(update_family).delete(delete_family))
        .route("/families/:id/switch", post(switch_family))
        .route("/families/:id/invite-code", post(regenerate_invite_code))
        .layer(middleware::from_fn(require_auth))
}

pub fn register_all_routes(app: Router<AppState>) -> Router<AppState> {
    app
        .nest("/api/v1", family_routes())
        .nest("/api/v1", member_routes())
        .nest("/api/v1", invitation_routes())
        .nest("/api/v1", auth_routes())
        .nest("/api/v1", audit_routes())
}
```

## 分页支持

```rust
#[derive(Deserialize)]
pub struct PaginationParams {
    pub page: Option<u32>,
    pub limit: Option<u32>,
}

pub struct PaginatedResponse<T> {
    pub items: Vec<T>,
    pub total: u64,
    pub page: u32,
    pub limit: u32,
}
```

## 实现优先级

1. **Phase 1**: 核心API
   - Auth增强API
   - Family基础API
   
2. **Phase 2**: 协作API
   - Member API
   - Invitation API
   
3. **Phase 3**: 增强功能
   - Audit API
   - 批量操作API

## 安全考虑

1. **认证要求**
   - 除公开端点外都需要JWT
   - Token过期处理
   
2. **权限验证**
   - 细粒度权限检查
   - Family范围隔离
   
3. **输入验证**
   - 防止SQL注入
   - XSS防护
   
4. **限流**
   - API调用频率限制
   - 防止暴力破解

---

设计人: Claude Code
日期: 2025-09-04