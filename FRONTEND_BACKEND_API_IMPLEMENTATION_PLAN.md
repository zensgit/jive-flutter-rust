# 前后端API对接实现计划

## 📌 说明
本文档详细列出前端需要实现的每个后端API调用，包括具体的实现代码和UI集成位置。

## 🔴 第一优先级：未实现的核心API

### 1. Family删除功能

#### 后端API已存在
```rust
DELETE /api/v1/families/:id
权限要求: DeleteFamily + Owner角色
```

#### 前端需要实现
```dart
// 1. 在 lib/services/api/family_service.dart 添加
Future<void> deleteFamily(String familyId) async {
  try {
    await _client.delete('/families/$familyId');
  } catch (e) {
    throw _handleError(e);
  }
}

// 2. 在 lib/screens/family/family_settings_screen.dart 添加删除按钮
Widget _buildDangerZone() {
  return Card(
    color: Colors.red.shade50,
    child: ListTile(
      leading: Icon(Icons.delete_forever, color: Colors.red),
      title: Text('删除家庭', style: TextStyle(color: Colors.red)),
      subtitle: Text('此操作不可恢复，将删除所有相关数据'),
      onTap: () => _showDeleteConfirmDialog(),
    ),
  );
}

// 3. 创建确认对话框
Future<void> _showDeleteConfirmDialog() async {
  final familyName = widget.ledger.name;
  final inputController = TextEditingController();
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('确认删除家庭'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('此操作将永久删除以下内容：'),
          SizedBox(height: 8),
          Text('• 所有账户记录'),
          Text('• 所有交易记录'),
          Text('• 所有预算设置'),
          Text('• 所有成员关系'),
          SizedBox(height: 16),
          Text('请输入家庭名称"$familyName"以确认：'),
          TextField(
            controller: inputController,
            decoration: InputDecoration(
              hintText: '输入家庭名称',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: inputController.text == familyName
            ? () => Navigator.pop(context, true)
            : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text('确认删除'),
        ),
      ],
    ),
  );
  
  if (confirmed == true) {
    await ref.read(familyServiceProvider).deleteFamily(widget.ledger.id!);
    // 导航回主页
    context.go('/dashboard');
  }
}
```

### 2. 邀请系统完整实现

#### 后端API已存在
```rust
// 创建邀请
POST /api/v1/invitations
Body: {
  "family_id": "uuid",
  "email": "user@example.com",
  "role": "member",
  "permissions": []
}

// 获取待处理邀请（被邀请者查看）
GET /api/v1/invitations
Response: [{
  "id": "uuid",
  "family_id": "uuid",
  "family_name": "string",
  "inviter_name": "string",
  "role": "member",
  "created_at": "datetime",
  "expires_at": "datetime"
}]

// 接受邀请
POST /api/v1/invitations/accept
Body: {
  "invitation_id": "uuid" // 或
  "invite_code": "ABC123"
}

// 取消邀请（邀请者取消）
DELETE /api/v1/invitations/:id

// 验证邀请码
GET /api/v1/invitations/validate/:code
```

#### 前端需要实现
```dart
// 1. 创建 lib/models/invitation.dart
class Invitation {
  final String id;
  final String familyId;
  final String familyName;
  final String inviterName;
  final String email;
  final String role;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status; // pending, accepted, expired, cancelled
  
  // fromJson, toJson 方法...
}

// 2. 在 lib/services/api/family_service.dart 扩展
class FamilyService {
  // 创建邀请（已有 inviteMember 方法，需要调整）
  Future<Invitation> createInvitation({
    required String familyId,
    required String email,
    required String role,
    List<String>? permissions,
  }) async {
    final response = await _client.post(
      '/invitations',
      data: {
        'family_id': familyId,
        'email': email,
        'role': role,
        'permissions': permissions ?? [],
      },
    );
    return Invitation.fromJson(response.data['data']);
  }
  
  // 获取我的待处理邀请
  Future<List<Invitation>> getMyPendingInvitations() async {
    final response = await _client.get('/invitations');
    final List<dynamic> data = response.data['data'] ?? [];
    return data.map((json) => Invitation.fromJson(json)).toList();
  }
  
  // 接受邀请
  Future<void> acceptInvitation({String? invitationId, String? inviteCode}) async {
    await _client.post(
      '/invitations/accept',
      data: {
        if (invitationId != null) 'invitation_id': invitationId,
        if (inviteCode != null) 'invite_code': inviteCode,
      },
    );
  }
  
  // 取消邀请
  Future<void> cancelInvitation(String invitationId) async {
    await _client.delete('/invitations/$invitationId');
  }
  
  // 验证邀请码
  Future<Invitation> validateInviteCode(String code) async {
    final response = await _client.get('/invitations/validate/$code');
    return Invitation.fromJson(response.data['data']);
  }
}

// 3. 创建 lib/screens/invitations/pending_invitations_screen.dart
class PendingInvitationsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('待处理的邀请')),
      body: invitationsAsync.when(
        data: (invitations) => ListView.builder(
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.family_restroom),
                ),
                title: Text(invitation.familyName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('邀请人: ${invitation.inviterName}'),
                    Text('角色: ${invitation.role}'),
                    Text('过期时间: ${_formatDate(invitation.expiresAt)}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _declineInvitation(invitation),
                      child: Text('拒绝'),
                    ),
                    ElevatedButton(
                      onPressed: () => _acceptInvitation(invitation),
                      child: Text('接受'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('加载失败')),
      ),
    );
  }
}

// 4. 在主界面添加通知标记
// 在 dashboard_screen.dart 的 AppBar 添加
IconButton(
  icon: Stack(
    children: [
      Icon(Icons.notifications_outlined),
      if (pendingInvitationsCount > 0)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              '$pendingInvitationsCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  ),
  onPressed: () => context.go('/invitations'),
),
```

### 3. 重新生成邀请码

#### 后端API已存在
```rust
POST /api/v1/families/:id/invite-code
Response: {
  "invite_code": "ABC123"
}
```

#### 前端需要实现
```dart
// 1. 在 family_service.dart 添加
Future<String> regenerateInviteCode(String familyId) async {
  final response = await _client.post('/families/$familyId/invite-code');
  return response.data['data']['invite_code'];
}

// 2. 在 family_settings_screen.dart 添加邀请码卡片
Widget _buildInviteCodeCard() {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('邀请码', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _regenerateInviteCode,
                tooltip: '重新生成',
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.ledger.inviteCode ?? '暂无邀请码',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () => _copyInviteCode(),
                ),
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () => _shareInviteCode(),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '分享此邀请码，让其他人加入您的家庭',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
```

### 4. 审计日志系统

#### 后端API已存在
```rust
GET /api/v1/families/:id/audit-logs
Query: {
  page: 1,
  per_page: 20,
  start_date: "2025-01-01",
  end_date: "2025-01-31",
  user_id: "uuid",
  action: "member.add"
}

GET /api/v1/families/:id/audit-logs/export
返回CSV文件
```

#### 前端需要实现
```dart
// 1. 创建 lib/models/audit_log.dart
class AuditLog {
  final String id;
  final String familyId;
  final String userId;
  final String userName;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? changes;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;
  
  // fromJson, toJson...
}

// 2. 创建 lib/services/api/audit_service.dart
class AuditService {
  final _client = HttpClient.instance;
  
  Future<PaginatedResult<AuditLog>> getAuditLogs({
    required String familyId,
    int page = 1,
    int perPage = 20,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? action,
  }) async {
    final response = await _client.get(
      '/families/$familyId/audit-logs',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (userId != null) 'user_id': userId,
        if (action != null) 'action': action,
      },
    );
    
    return PaginatedResult<AuditLog>.fromJson(
      response.data,
      (json) => AuditLog.fromJson(json),
    );
  }
  
  Future<void> exportAuditLogs({
    required String familyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // 下载CSV文件
    final response = await _client.get(
      '/families/$familyId/audit-logs/export',
      queryParameters: {
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      },
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    
    // 保存文件
    final fileName = 'audit_logs_${DateTime.now().millisecondsSinceEpoch}.csv';
    // 使用 file_saver 包保存文件
  }
}

// 3. 创建 lib/screens/audit/audit_logs_screen.dart
class AuditLogsScreen extends ConsumerStatefulWidget {
  final String familyId;
  
  @override
  _AuditLogsScreenState createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  DateTime? startDate;
  DateTime? endDate;
  String? selectedUserId;
  String? selectedAction;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('审计日志'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选条件展示
          if (_hasActiveFilters())
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: Wrap(
                spacing: 8,
                children: [
                  if (startDate != null)
                    Chip(
                      label: Text('从: ${_formatDate(startDate!)}'),
                      onDeleted: () => setState(() => startDate = null),
                    ),
                  if (endDate != null)
                    Chip(
                      label: Text('到: ${_formatDate(endDate!)}'),
                      onDeleted: () => setState(() => endDate = null),
                    ),
                  // 其他筛选条件...
                ],
              ),
            ),
          
          // 日志列表
          Expanded(
            child: _buildLogsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogsList() {
    final logsAsync = ref.watch(auditLogsProvider(
      familyId: widget.familyId,
      startDate: startDate,
      endDate: endDate,
      userId: selectedUserId,
      action: selectedAction,
    ));
    
    return logsAsync.when(
      data: (logs) => ListView.builder(
        itemCount: logs.items.length,
        itemBuilder: (context, index) {
          final log = logs.items[index];
          return _buildLogItem(log);
        },
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('加载失败')),
    );
  }
  
  Widget _buildLogItem(AuditLog log) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_getActionIcon(log.action)),
        ),
        title: Text(_getActionDescription(log)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('操作人: ${log.userName}'),
            Text('时间: ${_formatDateTime(log.createdAt)}'),
            if (log.ipAddress != null)
              Text('IP: ${log.ipAddress}'),
          ],
        ),
        onTap: () => _showLogDetails(log),
      ),
    );
  }
}
```

### 5. 自定义权限设置

#### 后端API已存在
```rust
PUT /api/v1/families/:family_id/members/:user_id/permissions
Body: {
  "permissions": ["view_accounts", "create_transactions", ...]
}
```

#### 前端需要实现
```dart
// 1. 在 family_service.dart 添加
Future<void> updateMemberPermissions({
  required String familyId,
  required String userId,
  required List<String> permissions,
}) async {
  await _client.put(
    '/families/$familyId/members/$userId/permissions',
    data: {
      'permissions': permissions,
    },
  );
}

// 2. 创建 lib/screens/family/member_permissions_screen.dart
class MemberPermissionsScreen extends ConsumerStatefulWidget {
  final String familyId;
  final LedgerMember member;
  
  @override
  _MemberPermissionsScreenState createState() => _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState extends ConsumerState<MemberPermissionsScreen> {
  late Map<String, bool> selectedPermissions;
  
  @override
  void initState() {
    super.initState();
    selectedPermissions = Map.from(widget.member.permissions);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('编辑权限 - ${widget.member.name}'),
        actions: [
          TextButton(
            onPressed: _savePermissions,
            child: Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 权限分组展示
          _buildPermissionGroup(
            '家庭管理',
            [
              PermissionItem('view_family_info', '查看家庭信息'),
              PermissionItem('update_family_info', '更新家庭设置'),
              PermissionItem('delete_family', '删除家庭'),
            ],
          ),
          _buildPermissionGroup(
            '成员管理',
            [
              PermissionItem('view_members', '查看成员'),
              PermissionItem('invite_members', '邀请成员'),
              PermissionItem('remove_members', '移除成员'),
              PermissionItem('update_member_roles', '更新成员角色'),
            ],
          ),
          _buildPermissionGroup(
            '账户管理',
            [
              PermissionItem('view_accounts', '查看账户'),
              PermissionItem('create_accounts', '创建账户'),
              PermissionItem('edit_accounts', '编辑账户'),
              PermissionItem('delete_accounts', '删除账户'),
            ],
          ),
          _buildPermissionGroup(
            '交易管理',
            [
              PermissionItem('view_transactions', '查看交易'),
              PermissionItem('create_transactions', '创建交易'),
              PermissionItem('edit_transactions', '编辑交易'),
              PermissionItem('delete_transactions', '删除交易'),
              PermissionItem('bulk_edit_transactions', '批量编辑交易'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionGroup(String title, List<PermissionItem> permissions) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...permissions.map((permission) => CheckboxListTile(
            title: Text(permission.label),
            subtitle: Text(permission.description ?? ''),
            value: selectedPermissions[permission.key] ?? false,
            onChanged: (value) {
              setState(() {
                selectedPermissions[permission.key] = value ?? false;
              });
            },
          )),
        ],
      ),
    );
  }
}
```

## 🟡 第二优先级：增强功能

### 6. 用户上下文API

#### 后端API已存在
```rust
GET /api/v1/auth/context
Response: {
  "user": {...},
  "families": [{
    "family": {...},
    "role": "owner",
    "permissions": [...]
  }],
  "current_family": {...}
}
```

#### 前端需要实现
```dart
// 在 auth_service.dart 添加
Future<UserContext> getUserContext() async {
  final response = await _client.get('/auth/context');
  return UserContext.fromJson(response.data['data']);
}

// 使用场景：应用启动时获取完整上下文
// 在 app_initialization_service.dart
Future<void> initializeApp() async {
  final context = await authService.getUserContext();
  // 设置当前用户
  // 设置所有families
  // 设置当前family
}
```

## 📊 实现优先级总结

### 立即实现（本周）
1. ✅ 删除Family功能 - 1天
2. ✅ 邀请系统完整实现 - 2天
3. ✅ 重新生成邀请码 - 0.5天

### 下周实现
4. ✅ 审计日志系统 - 2天
5. ✅ 自定义权限设置 - 2天

### 后续实现
6. ✅ 用户上下文优化
7. ✅ 批量操作API
8. ✅ 通知系统

## 🔧 测试验证清单

每个API实现后需要验证：
- [ ] API调用成功返回数据
- [ ] 错误处理正确（401, 403, 404, 500）
- [ ] UI正确显示数据
- [ ] 权限控制生效
- [ ] 状态管理更新
- [ ] 用户反馈友好

---

**文档创建**: 2025-01-06  
**预计完成**: 2-3周  
**当前状态**: 待开始实现