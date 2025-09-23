# Jive 多用户协作系统设计方案

基于 Maybe 的 Family 模型分析和实现方案

## 📋 概述

本文档详细说明如何在 Jive (Flutter+Rust) 中实现类似 Maybe 的 Family 多用户协作功能，包括数据模型设计、权限管理、协作机制等核心功能。

## 🔍 Maybe Family 模型分析

### 核心概念

在 Maybe 中，**Family** 是多用户协作的核心概念：
- **Family** = 一个共享财务数据的用户组（类似"家庭"或"团队"）
- 所有财务数据（账户、交易、分类等）都属于 Family，而非个人
- 用户通过 Family 实现数据共享和协作
- 支持多账本（Ledger）进一步隔离不同用途的财务数据

### Maybe 的权限模型

```ruby
# Maybe 用户角色
enum :role, { 
  member: "member",      # 普通成员：可以查看和编辑数据
  admin: "admin",        # 管理员：可以邀请用户、管理设置
  super_admin: "super_admin"  # 超级管理员：系统级权限
}

# 权限判断
def admin?
  super_admin? || role == "admin"
end
```

### Maybe 的数据隔离

```ruby
# 所有数据都通过 Family 关联
class Family < ApplicationRecord
  has_many :users        # 用户属于 Family
  has_many :accounts     # 账户属于 Family
  has_many :transactions # 交易属于 Family
  has_many :categories   # 分类属于 Family
  has_many :ledgers      # 账本属于 Family
  has_many :payees       # 收款人属于 Family
  has_many :tags         # 标签属于 Family
  has_many :budgets      # 预算属于 Family
end
```

## 🏗️ Jive 多用户协作架构设计

### 1. 数据模型设计

#### Rust 领域模型

```rust
// src/domain/family.rs
use chrono::{DateTime, Utc};
use serde::{Serialize, Deserialize};
use uuid::Uuid;

/// Family - 多用户协作的核心实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Family {
    pub id: String,
    pub name: String,
    pub currency: String,
    pub timezone: String,
    pub locale: String,
    pub date_format: String,
    pub settings: FamilySettings,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Family 设置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilySettings {
    pub auto_categorize_enabled: bool,
    pub smart_defaults_enabled: bool,
    pub require_approval_for_large_transactions: bool,
    pub large_transaction_threshold: Option<Decimal>,
    pub shared_categories: bool,
    pub shared_tags: bool,
    pub shared_payees: bool,
    pub notification_preferences: NotificationPreferences,
}

/// 用户与 Family 的关联（成员关系）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyMembership {
    pub id: String,
    pub family_id: String,
    pub user_id: String,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub joined_at: DateTime<Utc>,
    pub invited_by: Option<String>,
    pub is_active: bool,
}

/// Family 角色
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum FamilyRole {
    Owner,    // 创建者，拥有所有权限
    Admin,    // 管理员，可以管理成员和设置
    Member,   // 普通成员，可以查看和编辑数据
    Viewer,   // 只读成员，只能查看数据
}

/// 细粒度权限
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Permission {
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
    
    // 管理权限
    InviteMembers,
    RemoveMembers,
    ManageRoles,
    ManageSettings,
    ManageLedgers,
    
    // 高级权限
    ViewAuditLog,
    ManageIntegrations,
    ManageSubscription,
}

impl FamilyRole {
    /// 获取角色的默认权限
    pub fn default_permissions(&self) -> Vec<Permission> {
        use Permission::*;
        match self {
            FamilyRole::Owner => vec![
                // Owner 拥有所有权限
                ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts,
                ViewTransactions, CreateTransactions, EditTransactions, 
                DeleteTransactions, BulkEditTransactions,
                ViewCategories, ManageCategories,
                ViewBudgets, ManageBudgets,
                ViewReports, ExportData,
                InviteMembers, RemoveMembers, ManageRoles, ManageSettings,
                ManageLedgers, ViewAuditLog, ManageIntegrations, ManageSubscription,
            ],
            FamilyRole::Admin => vec![
                // Admin 拥有大部分权限，但不能管理订阅
                ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts,
                ViewTransactions, CreateTransactions, EditTransactions, 
                DeleteTransactions, BulkEditTransactions,
                ViewCategories, ManageCategories,
                ViewBudgets, ManageBudgets,
                ViewReports, ExportData,
                InviteMembers, RemoveMembers, ManageSettings, ManageLedgers,
                ViewAuditLog, ManageIntegrations,
            ],
            FamilyRole::Member => vec![
                // Member 可以查看和编辑数据
                ViewAccounts, CreateAccounts, EditAccounts,
                ViewTransactions, CreateTransactions, EditTransactions,
                ViewCategories,
                ViewBudgets,
                ViewReports, ExportData,
            ],
            FamilyRole::Viewer => vec![
                // Viewer 只能查看
                ViewAccounts,
                ViewTransactions,
                ViewCategories,
                ViewBudgets,
                ViewReports,
            ],
        }
    }
}
```

#### 更新 User 模型

```rust
// src/domain/user.rs 更新
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub email: String,
    pub name: String,
    pub status: UserStatus,
    // 移除单一 role，改为通过 FamilyMembership 管理
    pub family_memberships: Vec<FamilyMembership>,
    pub current_family_id: Option<String>,  // 当前选中的 Family
    pub current_ledger_id: Option<String>,  // 当前选中的 Ledger
    pub preferences: UserPreferences,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl User {
    /// 获取用户在指定 Family 中的角色
    pub fn role_in_family(&self, family_id: &str) -> Option<FamilyRole> {
        self.family_memberships
            .iter()
            .find(|m| m.family_id == family_id && m.is_active)
            .map(|m| m.role.clone())
    }
    
    /// 检查用户在指定 Family 中是否有某个权限
    pub fn has_permission_in_family(&self, family_id: &str, permission: Permission) -> bool {
        self.family_memberships
            .iter()
            .find(|m| m.family_id == family_id && m.is_active)
            .map(|m| m.permissions.contains(&permission))
            .unwrap_or(false)
    }
    
    /// 是否是 Family 的管理员
    pub fn is_family_admin(&self, family_id: &str) -> bool {
        matches!(
            self.role_in_family(family_id),
            Some(FamilyRole::Owner) | Some(FamilyRole::Admin)
        )
    }
}
```

### 2. 服务层实现

#### Family 服务

```rust
// src/application/family_service.rs
use crate::domain::{Family, FamilyMembership, FamilyRole, Permission};
use crate::error::{JiveError, Result};

#[derive(Debug, Clone)]
pub struct FamilyService {
    // 服务依赖
}

impl FamilyService {
    /// 创建新的 Family
    pub async fn create_family(
        &self,
        request: CreateFamilyRequest,
        creator_id: String,
    ) -> Result<Family> {
        // 1. 创建 Family
        let family = Family {
            id: Uuid::new_v4().to_string(),
            name: request.name,
            currency: request.currency,
            timezone: request.timezone,
            locale: request.locale,
            date_format: request.date_format,
            settings: FamilySettings::default(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        
        // 2. 创建创建者的成员关系（Owner）
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: family.id.clone(),
            user_id: creator_id,
            role: FamilyRole::Owner,
            permissions: FamilyRole::Owner.default_permissions(),
            joined_at: Utc::now(),
            invited_by: None,
            is_active: true,
        };
        
        // 3. 保存到数据库
        self.save_family(&family).await?;
        self.save_membership(&membership).await?;
        
        // 4. 创建默认数据（分类、标签等）
        self.create_default_data(&family).await?;
        
        Ok(family)
    }
    
    /// 邀请用户加入 Family
    pub async fn invite_member(
        &self,
        family_id: String,
        inviter_id: String,
        request: InviteMemberRequest,
    ) -> Result<Invitation> {
        // 1. 检查邀请者权限
        if !self.has_permission(&inviter_id, &family_id, Permission::InviteMembers).await? {
            return Err(JiveError::Unauthorized("No permission to invite members".into()));
        }
        
        // 2. 检查被邀请者是否已经是成员
        if self.is_member(&request.email, &family_id).await? {
            return Err(JiveError::Conflict("User is already a member".into()));
        }
        
        // 3. 创建邀请
        let invitation = Invitation {
            id: Uuid::new_v4().to_string(),
            family_id,
            inviter_id,
            invitee_email: request.email,
            role: request.role.unwrap_or(FamilyRole::Member),
            token: generate_invitation_token(),
            expires_at: Utc::now() + Duration::days(7),
            status: InvitationStatus::Pending,
            created_at: Utc::now(),
        };
        
        // 4. 保存邀请
        self.save_invitation(&invitation).await?;
        
        // 5. 发送邀请邮件
        self.send_invitation_email(&invitation).await?;
        
        Ok(invitation)
    }
    
    /// 接受邀请
    pub async fn accept_invitation(
        &self,
        token: String,
        user_id: String,
    ) -> Result<FamilyMembership> {
        // 1. 验证邀请
        let invitation = self.find_invitation_by_token(&token).await?;
        
        if invitation.status != InvitationStatus::Pending {
            return Err(JiveError::BadRequest("Invitation already used".into()));
        }
        
        if invitation.expires_at < Utc::now() {
            return Err(JiveError::BadRequest("Invitation expired".into()));
        }
        
        // 2. 创建成员关系
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: invitation.family_id,
            user_id,
            role: invitation.role,
            permissions: invitation.role.default_permissions(),
            joined_at: Utc::now(),
            invited_by: Some(invitation.inviter_id),
            is_active: true,
        };
        
        // 3. 保存成员关系
        self.save_membership(&membership).await?;
        
        // 4. 更新邀请状态
        self.mark_invitation_accepted(&invitation.id).await?;
        
        Ok(membership)
    }
    
    /// 更新成员角色
    pub async fn update_member_role(
        &self,
        family_id: String,
        admin_id: String,
        member_id: String,
        new_role: FamilyRole,
    ) -> Result<FamilyMembership> {
        // 1. 检查管理员权限
        if !self.has_permission(&admin_id, &family_id, Permission::ManageRoles).await? {
            return Err(JiveError::Unauthorized("No permission to manage roles".into()));
        }
        
        // 2. 不能修改 Owner 的角色
        let member_role = self.get_member_role(&member_id, &family_id).await?;
        if member_role == FamilyRole::Owner {
            return Err(JiveError::BadRequest("Cannot change owner role".into()));
        }
        
        // 3. 更新角色
        let mut membership = self.get_membership(&member_id, &family_id).await?;
        membership.role = new_role.clone();
        membership.permissions = new_role.default_permissions();
        
        // 4. 保存更新
        self.update_membership(&membership).await?;
        
        Ok(membership)
    }
    
    /// 切换当前 Family
    pub async fn switch_family(
        &self,
        user_id: String,
        family_id: String,
    ) -> Result<()> {
        // 1. 检查用户是否是该 Family 的成员
        if !self.is_member_by_id(&user_id, &family_id).await? {
            return Err(JiveError::Unauthorized("Not a member of this family".into()));
        }
        
        // 2. 更新用户的当前 Family
        self.update_current_family(&user_id, &family_id).await?;
        
        Ok(())
    }
}
```

### 3. 数据隔离机制

#### 服务上下文增强

```rust
// src/application/mod.rs
#[derive(Debug, Clone)]
pub struct ServiceContext {
    pub user_id: String,
    pub family_id: String,  // 新增：当前 Family
    pub ledger_id: Option<String>,
    pub permissions: Vec<Permission>,  // 新增：用户权限
    pub request_id: String,
    pub timestamp: DateTime<Utc>,
}

impl ServiceContext {
    /// 检查权限
    pub fn has_permission(&self, permission: Permission) -> bool {
        self.permissions.contains(&permission)
    }
    
    /// 要求权限（无权限时抛出错误）
    pub fn require_permission(&self, permission: Permission) -> Result<()> {
        if !self.has_permission(permission) {
            return Err(JiveError::Unauthorized(
                format!("Missing permission: {:?}", permission)
            ));
        }
        Ok(())
    }
}
```

#### 数据访问层改造

```rust
// src/infrastructure/repositories/transaction_repository.rs
impl TransactionRepository {
    /// 获取 Family 的交易列表
    pub async fn find_by_family(
        &self,
        family_id: &str,
        filters: TransactionFilters,
    ) -> Result<Vec<Transaction>> {
        // SQL 查询自动加入 family_id 过滤
        let query = "
            SELECT * FROM transactions 
            WHERE family_id = $1
            AND deleted_at IS NULL
            ORDER BY date DESC
        ";
        
        // 执行查询...
    }
    
    /// 创建交易时自动关联 Family
    pub async fn create(
        &self,
        transaction: &Transaction,
        family_id: &str,
    ) -> Result<Transaction> {
        let mut tx = transaction.clone();
        tx.family_id = family_id.to_string();
        
        // 保存到数据库...
    }
}
```

### 4. Flutter 前端实现

#### 状态管理

```dart
// lib/providers/family_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

@freezed
class FamilyState with _$FamilyState {
  const factory FamilyState({
    Family? currentFamily,
    List<Family>? families,
    List<FamilyMember>? members,
    FamilyRole? currentRole,
    List<Permission>? permissions,
    @Default(false) bool isLoading,
    String? error,
  }) = _FamilyState;
}

class FamilyNotifier extends StateNotifier<FamilyState> {
  final JiveCore _core;
  
  FamilyNotifier(this._core) : super(const FamilyState());
  
  /// 加载用户的所有 Family
  Future<void> loadFamilies() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final families = await _core.getFamilies();
      final currentFamilyId = await _core.getCurrentFamilyId();
      final currentFamily = families.firstWhere(
        (f) => f.id == currentFamilyId,
        orElse: () => families.first,
      );
      
      state = state.copyWith(
        families: families,
        currentFamily: currentFamily,
        isLoading: false,
      );
      
      // 加载当前 Family 的成员
      await loadMembers(currentFamily.id);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
  
  /// 切换 Family
  Future<void> switchFamily(String familyId) async {
    try {
      await _core.switchFamily(familyId);
      await loadFamilies();
      
      // 刷新相关数据
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  /// 邀请成员
  Future<void> inviteMember(String email, FamilyRole role) async {
    try {
      await _core.inviteMember(
        state.currentFamily!.id,
        email,
        role,
      );
      
      // 刷新成员列表
      await loadMembers(state.currentFamily!.id);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  /// 更新成员角色
  Future<void> updateMemberRole(String memberId, FamilyRole newRole) async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _core.updateMemberRole(
        state.currentFamily!.id,
        memberId,
        newRole,
      );
      
      await loadMembers(state.currentFamily!.id);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}

final familyProvider = StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  return FamilyNotifier(ref.watch(jiveCoreProvider));
});
```

#### UI 组件

```dart
// lib/ui/components/family/family_switcher.dart
class FamilySwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    
    return PopupMenuButton<String>(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.group),
              const SizedBox(width: 8),
              Text(familyState.currentFamily?.name ?? 'Personal'),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
      itemBuilder: (context) {
        return [
          // Family 列表
          ...?familyState.families?.map((family) {
            return PopupMenuItem(
              value: family.id,
              child: ListTile(
                leading: Icon(
                  family.id == familyState.currentFamily?.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: Text(family.name),
                subtitle: Text('${family.memberCount} members'),
              ),
            );
          }),
          
          const PopupMenuDivider(),
          
          // 创建新 Family
          PopupMenuItem(
            value: 'create',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('Create New Family'),
            ),
          ),
          
          // 管理当前 Family
          if (familyState.currentRole == FamilyRole.owner ||
              familyState.currentRole == FamilyRole.admin)
            PopupMenuItem(
              value: 'manage',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Manage Family'),
              ),
            ),
        ];
      },
      onSelected: (value) async {
        if (value == 'create') {
          // 显示创建 Family 对话框
          await showCreateFamilyDialog(context);
        } else if (value == 'manage') {
          // 导航到 Family 管理页面
          context.push('/family/manage');
        } else {
          // 切换 Family
          await ref.read(familyProvider.notifier).switchFamily(value);
        }
      },
    );
  }
}

// lib/ui/screens/family/members_screen.dart
class FamilyMembersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    final members = familyState.members ?? [];
    final canInvite = familyState.permissions?.contains(Permission.inviteMembers) ?? false;
    final canManageRoles = familyState.permissions?.contains(Permission.manageRoles) ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Family Members'),
        actions: [
          if (canInvite)
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () => _showInviteDialog(context, ref),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final isCurrentUser = member.userId == ref.read(authProvider).user?.id;
          
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(member.name.substring(0, 1).toUpperCase())
                  : null,
            ),
            title: Text(member.name),
            subtitle: Text(member.email),
            trailing: canManageRoles && !isCurrentUser
                ? _buildRoleSelector(member, ref)
                : Chip(
                    label: Text(_getRoleLabel(member.role)),
                    backgroundColor: _getRoleColor(member.role),
                  ),
          );
        },
      ),
    );
  }
  
  Widget _buildRoleSelector(FamilyMember member, WidgetRef ref) {
    // Owner 角色不能被修改
    if (member.role == FamilyRole.owner) {
      return Chip(
        label: Text('Owner'),
        backgroundColor: Colors.purple,
      );
    }
    
    return PopupMenuButton<FamilyRole>(
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getRoleLabel(member.role)),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
        backgroundColor: _getRoleColor(member.role),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: FamilyRole.admin,
          child: Text('Admin'),
        ),
        PopupMenuItem(
          value: FamilyRole.member,
          child: Text('Member'),
        ),
        PopupMenuItem(
          value: FamilyRole.viewer,
          child: Text('Viewer'),
        ),
      ],
      onSelected: (newRole) async {
        await ref.read(familyProvider.notifier).updateMemberRole(
          member.id,
          newRole,
        );
      },
    );
  }
}
```

### 5. 数据同步策略

#### 实时同步（WebSocket）

```rust
// src/infrastructure/websocket/family_sync.rs
pub struct FamilySyncService {
    connections: Arc<RwLock<HashMap<String, Vec<WebSocketConnection>>>>,
}

impl FamilySyncService {
    /// 广播事件到 Family 的所有在线成员
    pub async fn broadcast_to_family(
        &self,
        family_id: &str,
        event: SyncEvent,
        exclude_user_id: Option<&str>,
    ) -> Result<()> {
        let connections = self.connections.read().await;
        
        if let Some(family_connections) = connections.get(family_id) {
            for conn in family_connections {
                // 排除发起者
                if let Some(exclude_id) = exclude_user_id {
                    if conn.user_id == exclude_id {
                        continue;
                    }
                }
                
                // 发送事件
                conn.send(event.clone()).await?;
            }
        }
        
        Ok(())
    }
}

/// 同步事件类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SyncEvent {
    TransactionCreated { transaction: Transaction },
    TransactionUpdated { transaction: Transaction },
    TransactionDeleted { id: String },
    AccountUpdated { account: Account },
    CategoryCreated { category: Category },
    MemberJoined { member: FamilyMember },
    MemberLeft { member_id: String },
    MemberRoleChanged { member_id: String, new_role: FamilyRole },
}
```

### 6. 权限检查中间件

```rust
// src/application/middleware/permission_middleware.rs
pub struct PermissionMiddleware;

impl PermissionMiddleware {
    /// 包装服务方法，自动进行权限检查
    pub fn require_permission<F, T>(
        permission: Permission,
        context: &ServiceContext,
        f: F,
    ) -> Result<T>
    where
        F: FnOnce() -> Result<T>,
    {
        // 检查权限
        context.require_permission(permission)?;
        
        // 执行实际操作
        f()
    }
    
    /// 批量操作的权限检查
    pub fn require_bulk_permission(
        context: &ServiceContext,
    ) -> Result<()> {
        context.require_permission(Permission::BulkEditTransactions)
    }
}

// 使用示例
impl TransactionService {
    pub async fn delete_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> Result<()> {
        PermissionMiddleware::require_permission(
            Permission::DeleteTransactions,
            &context,
            || async {
                // 实际删除逻辑
                self.repository.delete(&id, &context.family_id).await
            },
        ).await
    }
}
```

## 📊 实施计划

### 第一阶段：基础架构（1-2周）
1. ✅ 设计 Family 和 FamilyMembership 数据模型
2. ✅ 实现 FamilyService 核心功能
3. ✅ 更新 ServiceContext 支持 Family
4. ⏳ 修改所有 Repository 支持 family_id 过滤

### 第二阶段：用户管理（1周）
1. ⏳ 实现邀请系统
2. ⏳ 实现角色和权限管理
3. ⏳ 实现 Family 切换功能
4. ⏳ 添加权限检查中间件

### 第三阶段：前端集成（1-2周）
1. ⏳ 实现 Family 状态管理
2. ⏳ 创建 Family 切换器组件
3. ⏳ 创建成员管理界面
4. ⏳ 更新所有数据请求包含 family_id

### 第四阶段：数据同步（1周）
1. ⏳ 实现 WebSocket 连接管理
2. ⏳ 实现实时事件广播
3. ⏳ 实现冲突解决机制
4. ⏳ 添加离线同步队列

### 第五阶段：测试和优化（1周）
1. ⏳ 编写单元测试
2. ⏳ 编写集成测试
3. ⏳ 性能优化
4. ⏳ 文档完善

## 🔑 关键技术点

### 1. 数据隔离保证
- 所有数据表增加 `family_id` 字段
- Repository 层自动注入 family_id 过滤
- 防止跨 Family 数据访问

### 2. 权限检查
- 细粒度权限控制
- 中间件自动权限验证
- 前端根据权限显示/隐藏功能

### 3. 实时协作
- WebSocket 实时推送
- 乐观锁处理并发修改
- 冲突解决策略

### 4. 性能优化
- Family 数据缓存
- 权限缓存
- 批量操作优化

## 🎯 预期成果

实现此方案后，Jive 将拥有：

1. **完整的多用户协作功能**
   - 用户可以创建和加入多个 Family
   - 支持邀请其他用户加入
   - 灵活的角色和权限管理

2. **数据安全隔离**
   - Family 之间数据完全隔离
   - 细粒度的权限控制
   - 审计日志记录

3. **实时协作体验**
   - 多用户同时编辑
   - 实时数据同步
   - 冲突自动解决

4. **向后兼容**
   - 现有单用户模式继续支持
   - 平滑升级路径
   - 数据迁移工具

## 📚 参考资源

- [Maybe Family 模型源码](https://github.com/maybe-finance/maybe/blob/main/app/models/family.rb)
- [Maybe 用户权限实现](https://github.com/maybe-finance/maybe/blob/main/app/models/user.rb)
- [Rails 多租户最佳实践](https://www.apartment.com/)
- [Rust 权限管理库](https://github.com/casbin/casbin-rs)

---

**文档版本**: 1.0.0  
**更新日期**: 2025-08-25  
**作者**: Jive 开发团队