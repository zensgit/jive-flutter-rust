# TODO 004: API层功能说明

## 实现概述

API层提供RESTful HTTP接口，实现了Family协作系统的所有Web API端点。

## 实现的API端点

### 1. Family API (/api/v1/families)

| 端点 | 方法 | 功能 | 权限要求 |
|-----|------|------|----------|
| `/families` | POST | 创建新Family | 已认证 |
| `/families` | GET | 获取用户所有Family | 已认证 |
| `/families/:id` | GET | 获取Family详情 | ViewFamilyInfo |
| `/families/:id` | PUT | 更新Family设置 | UpdateFamilyInfo |
| `/families/:id` | DELETE | 删除Family | DeleteFamily + Owner |
| `/families/switch` | POST | 切换当前Family | 已认证 |
| `/families/:id/invite-code` | POST | 重新生成邀请码 | InviteMembers |

**实现特性**:
- 标准化响应格式
- 权限验证
- 错误处理
- 事务支持

### 2. Member API (/api/v1/families/:id/members)

| 端点 | 方法 | 功能 | 权限要求 |
|-----|------|------|----------|
| `/members` | GET | 获取成员列表 | ViewMembers |
| `/members` | POST | 添加成员 | InviteMembers |
| `/members/:user_id` | DELETE | 移除成员 | RemoveMembers |
| `/members/:user_id/role` | PUT | 更新角色 | UpdateMemberRoles |
| `/members/:user_id/permissions` | PUT | 自定义权限 | UpdateMemberRoles |

**业务规则**:
- Owner不能被移除
- Owner角色不能修改
- 权限层级检查

### 3. Invitation API (/api/v1/invitations)

| 端点 | 方法 | 功能 | 权限要求 |
|-----|------|------|----------|
| `/invitations` | POST | 创建邀请 | InviteMembers |
| `/invitations` | GET | 获取待处理邀请 | ViewMembers |
| `/invitations/accept` | POST | 接受邀请 | 已认证 |
| `/invitations/:id` | DELETE | 取消邀请 | InviteMembers |
| `/invitations/validate/:code` | GET | 验证邀请码 | 公开 |

**特殊功能**:
- 支持邀请码和token两种方式
- 自动过期处理
- 事务性接受流程

### 4. Auth API增强 (/api/v1/auth)

| 端点 | 方法 | 功能 | 权限要求 |
|-----|------|------|----------|
| `/auth/register` | POST | 注册并创建个人Family | 公开 |
| `/auth/login` | POST | 登录 | 公开 |
| `/auth/me` | GET | 获取当前用户 | 已认证 |
| `/auth/context` | GET | 获取用户上下文（含所有Family） | 已认证 |
| `/auth/refresh` | POST | 刷新token | 已认证 |

**增强特性**:
- 注册时自动创建个人Family
- 返回完整的用户上下文
- 多Family支持

### 5. Audit API (/api/v1/families/:id/audit-logs)

| 端点 | 方法 | 功能 | 权限要求 |
|-----|------|------|----------|
| `/audit-logs` | GET | 查询审计日志 | ViewAuditLog |
| `/audit-logs/export` | GET | 导出CSV报告 | ViewAuditLog |

**查询支持**:
- 时间范围过滤
- 用户过滤
- 操作类型过滤
- 分页支持

## 中间件实现

### 1. 认证中间件 (require_auth)
```rust
- 从Authorization header提取JWT
- 验证token有效性
- 注入用户ID到请求上下文
- 返回401 Unauthorized错误
```

### 2. Family上下文中间件 (family_context)
```rust
- 提取路径中的family_id
- 验证用户是否为成员
- 加载用户权限
- 注入ServiceContext
- 返回403 Forbidden错误
```

## 响应格式

### 成功响应
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "name": "Family Name",
    // ... 其他数据
  },
  "error": null,
  "timestamp": "2025-09-04T12:00:00Z"
}
```

### 错误响应
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "You don't have permission",
    "details": null
  },
  "timestamp": "2025-09-04T12:00:00Z"
}
```

## HTTP状态码使用

| 状态码 | 使用场景 |
|-------|---------|
| 200 OK | 成功的GET/PUT请求 |
| 201 Created | 成功的POST创建 |
| 204 No Content | 成功的DELETE |
| 400 Bad Request | 请求参数错误 |
| 401 Unauthorized | 未认证 |
| 403 Forbidden | 无权限 |
| 404 Not Found | 资源不存在 |
| 409 Conflict | 资源冲突（如重复） |
| 410 Gone | 资源过期（如邀请） |
| 500 Internal Server Error | 服务器错误 |

## 安全特性

### 1. 认证安全
- JWT Bearer Token认证
- Token过期验证
- 用户状态检查

### 2. 授权安全
- 细粒度权限验证
- Family范围隔离
- 角色层级限制

### 3. 输入验证
- UUID格式验证
- Email格式验证
- 枚举值验证
- 字符串长度限制

### 4. 防护措施
- SQL注入防护（参数化查询）
- XSS防护（输入转义）
- CORS配置
- 速率限制预留

## 路由组织

```rust
/api/v1
├── /families          // Family管理
├── /members           // 成员管理
├── /invitations       // 邀请管理
├── /auth              // 认证相关
└── /audit-logs        // 审计日志
```

## 扩展性设计

### 1. 版本控制
- API版本前缀 `/api/v1`
- 便于未来升级

### 2. 中间件链
- 可组合的中间件
- 灵活的权限配置

### 3. 错误处理
- 统一的错误类型
- 可扩展的错误码

### 4. 响应格式
- 标准化的响应结构
- 元数据支持

## 性能考虑

### 1. 查询优化
- 使用索引字段
- 避免N+1查询
- 批量操作支持

### 2. 缓存预留
- ServiceContext可缓存
- 权限列表可缓存
- Token验证缓存

### 3. 并发处理
- 异步处理器
- 连接池管理
- 请求限流预留

---

文档编写: Claude Code
日期: 2025-09-04