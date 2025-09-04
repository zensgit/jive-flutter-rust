# TODO 003: 服务层功能说明

## 实现概述

服务层封装了Family协作系统的核心业务逻辑，提供事务管理和业务规则实施。

## 实现的服务

### 1. FamilyService - Family管理服务

#### 功能列表
- **create_family()** - 创建新Family并设置owner
  - 自动创建owner成员关系
  - 自动创建默认账本
  - 生成唯一邀请码
  
- **get_family()** - 获取Family详情
  - 需要ViewFamilyInfo权限
  
- **update_family()** - 更新Family设置
  - 需要UpdateFamilyInfo权限
  - 支持部分更新
  
- **delete_family()** - 删除Family
  - 需要DeleteFamily权限且必须是Owner
  - 防止删除用户唯一的Family
  
- **get_user_families()** - 获取用户所有Family列表
  
- **switch_family()** - 切换当前Family
  - 验证成员关系
  
- **regenerate_invite_code()** - 重新生成邀请码
  - 需要InviteMembers权限

### 2. MemberService - 成员管理服务

#### 功能列表
- **add_member()** - 添加新成员
  - 检查重复成员
  - 分配默认权限
  
- **remove_member()** - 移除成员
  - 防止移除Owner
  - 权限层级检查
  
- **update_member_role()** - 更新成员角色
  - Owner角色不可更改
  - 自动更新权限
  
- **update_member_permissions()** - 自定义权限
  - Owner权限不可自定义
  
- **get_family_members()** - 获取成员列表
  - 包含用户信息
  
- **check_permission()** - 检查权限
  
- **get_member_context()** - 获取成员上下文

### 3. InvitationService - 邀请管理服务

#### 功能列表
- **create_invitation()** - 创建邀请
  - 防止重复邀请
  - 生成邀请码和token
  - 设置过期时间
  
- **accept_invitation()** - 接受邀请
  - 支持邀请码和token
  - 事务处理：更新邀请、创建成员、更新current_family
  - 自动过期检查
  
- **cancel_invitation()** - 取消邀请
  
- **get_pending_invitations()** - 获取待处理邀请
  
- **validate_invite_code()** - 验证邀请码
  
- **cleanup_expired()** - 清理过期邀请

### 4. AuthService - 认证服务增强

#### 功能列表
- **register_with_family()** - 注册并创建个人Family
  - 密码使用Argon2加密
  - 自动创建个人Family
  - 设置为Owner角色
  
- **login()** - 用户登录
  - 密码验证
  - 返回用户上下文和Family列表
  
- **get_user_context()** - 获取用户上下文
  - 包含所有Family信息
  
- **validate_family_access()** - 验证Family访问权限
  - 返回ServiceContext

### 5. AuditService - 审计日志服务

#### 功能列表
- **log_action()** - 记录通用操作
  - 支持IP和UserAgent记录
  
- **get_audit_logs()** - 查询审计日志
  - 支持多条件过滤
  - 分页查询
  
- **log_family_created()** - 记录Family创建
  
- **log_member_added()** - 记录成员添加
  
- **log_member_removed()** - 记录成员移除
  
- **log_role_changed()** - 记录角色变更
  
- **log_invitation_sent()** - 记录邀请发送
  
- **export_audit_report()** - 导出CSV报告

## 服务层特性

### 1. 事务管理
```rust
// 示例：接受邀请的完整事务
accept_invitation() {
    1. 开启事务
    2. 验证并更新邀请状态
    3. 创建成员关系
    4. 更新用户current_family_id
    5. 提交或回滚
}
```

### 2. 权限控制
```rust
ServiceContext {
    - can_perform() - 检查单个权限
    - require_permission() - 强制权限检查
    - require_owner() - 要求Owner角色
    - require_admin_or_owner() - 要求管理员以上
    - can_manage_role() - 角色管理权限
}
```

### 3. 业务规则
- 每个用户至少保留一个Family
- Owner角色唯一且不可降级
- 权限继承角色默认设置
- 邀请码8位唯一
- 邀请默认7天过期

### 4. 错误处理
```rust
ServiceError {
    - DatabaseError - 数据库错误
    - PermissionDenied - 权限拒绝
    - NotFound - 资源未找到
    - ValidationError - 验证错误
    - BusinessRuleViolation - 业务规则违反
    - Conflict - 冲突错误
    - 特定错误（如InvitationExpired）
}
```

## 使用示例

### 创建Family
```rust
let family_service = FamilyService::new(pool);
let request = CreateFamilyRequest {
    name: "我的家庭账本".to_string(),
    currency: Some("CNY".to_string()),
    timezone: Some("Asia/Shanghai".to_string()),
    locale: Some("zh-CN".to_string()),
};
let family = family_service.create_family(user_id, request).await?;
```

### 邀请成员
```rust
let invitation_service = InvitationService::new(pool);
let request = CreateInvitationRequest {
    invitee_email: "friend@example.com".to_string(),
    role: MemberRole::Member,
    expires_in_days: Some(7),
};
let invitation = invitation_service.create_invitation(&ctx, request).await?;
```

### 接受邀请
```rust
let family_id = invitation_service.accept_invitation(
    Some(invite_code),
    None,
    user_id
).await?;
```

## 数据流

```
用户注册
  ↓
AuthService.register_with_family()
  ↓
FamilyService.create_family()
  ↓
自动创建Owner成员关系
  ↓
返回UserContext

邀请流程
  ↓
InvitationService.create_invitation()
  ↓
发送邀请邮件/显示邀请码
  ↓
InvitationService.accept_invitation()
  ↓
MemberService添加成员
  ↓
AuditService记录日志
```

## 安全特性

1. **密码安全**
   - Argon2加密算法
   - 随机盐值生成
   
2. **权限验证**
   - 每个操作前检查权限
   - 角色层级限制
   
3. **事务一致性**
   - 关键操作使用事务
   - 失败自动回滚
   
4. **审计追踪**
   - 记录所有关键操作
   - 支持IP追踪

## 性能考虑

1. **查询优化**
   - 使用索引字段查询
   - 避免N+1查询
   
2. **事务范围**
   - 最小化事务范围
   - 避免长事务
   
3. **缓存预留**
   - ServiceContext可缓存
   - 权限列表可缓存

---

文档编写: Claude Code
日期: 2025-09-04