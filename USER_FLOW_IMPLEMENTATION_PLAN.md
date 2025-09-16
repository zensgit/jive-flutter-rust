# 用户操作流程与前后端API对接详细计划

## 📌 文档说明
本文档详细描述每个用户操作场景，包括：
- 用户操作步骤
- 触发的前端事件
- 调用的后端API
- 数据流转过程
- UI状态变化
- 错误处理

---

## 🔴 功能模块一：Family（家庭）生命周期管理

### 场景1.1：用户创建新Family

#### 用户操作流程
```mermaid
用户点击 [创建家庭] 
    ↓
填写表单（名称、类型、货币、描述）
    ↓
点击 [确认创建]
    ↓
系统创建Family
    ↓
自动切换到新Family
    ↓
显示成功提示
```

#### 详细实现步骤

##### Step 1: 用户触发创建
**位置**: `FamilySwitcher` → "创建新家庭"
```dart
// widgets/family_switcher.dart
PopupMenuItem(
  value: 'create_new',
  onTap: () => showDialog(
    context: context,
    builder: (_) => CreateFamilyDialog(),
  ),
)
```

##### Step 2: 显示创建对话框
**组件**: `CreateFamilyDialog`
```dart
// widgets/dialogs/create_family_dialog.dart
class CreateFamilyDialog extends ConsumerStatefulWidget {
  @override
  _CreateFamilyDialogState createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends ConsumerState<CreateFamilyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedType = 'family';
  String _selectedCurrency = 'CNY';
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('创建新家庭'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 家庭名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '家庭名称',
                hintText: '例如：我的家庭',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入家庭名称';
                }
                if (value.length < 2) {
                  return '名称至少2个字符';
                }
                return null;
              },
            ),
            
            // 家庭类型
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(labelText: '类型'),
              items: [
                DropdownMenuItem(value: 'personal', child: Text('个人')),
                DropdownMenuItem(value: 'family', child: Text('家庭')),
                DropdownMenuItem(value: 'business', child: Text('商业')),
                DropdownMenuItem(value: 'project', child: Text('项目')),
              ],
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            
            // 货币选择
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: InputDecoration(labelText: '默认货币'),
              items: [
                DropdownMenuItem(value: 'CNY', child: Text('人民币 (CNY)')),
                DropdownMenuItem(value: 'USD', child: Text('美元 (USD)')),
                DropdownMenuItem(value: 'EUR', child: Text('欧元 (EUR)')),
              ],
              onChanged: (value) => setState(() => _selectedCurrency = value!),
            ),
            
            // 描述
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '描述（可选）',
                hintText: '简单描述这个家庭的用途',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading 
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('创建'),
        ),
      ],
    );
  }
  
  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Step 3: 调用API创建Family
      final result = await _createFamily();
      
      // Step 4: 自动切换到新Family
      await _switchToNewFamily(result.familyId);
      
      // Step 5: 刷新状态
      ref.invalidate(userFamiliesProvider);
      ref.invalidate(currentFamilyProvider);
      
      // Step 6: 关闭对话框并提示
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('家庭创建成功')),
        );
      }
    } catch (e) {
      // 错误处理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

##### Step 3: 前端API调用
```dart
// services/api/family_service.dart
Future<UserFamilyInfo> _createFamily() async {
  final service = ref.read(familyServiceProvider);
  
  // 构建请求
  final request = CreateFamilyRequest(
    name: _nameController.text.trim(),
    type: _selectedType,
    currency: _selectedCurrency,
    description: _descriptionController.text.trim().isEmpty 
      ? null 
      : _descriptionController.text.trim(),
    settings: FamilySettings(
      timezone: 'Asia/Shanghai',
      locale: 'zh-CN',
      dateFormat: 'YYYY-MM-DD',
    ),
  );
  
  // 调用API
  return await service.createFamily(request);
}
```

##### Step 4: 后端API处理
```rust
// Rust后端: handlers/family_handler.rs
POST /api/v1/families

请求体:
{
  "name": "我的家庭",
  "type": "family",
  "currency": "CNY",
  "description": "家庭财务管理",
  "settings": {
    "timezone": "Asia/Shanghai",
    "locale": "zh-CN",
    "date_format": "YYYY-MM-DD"
  }
}

处理流程:
1. 验证JWT token
2. 验证请求数据
3. 开启事务
4. 创建families记录
5. 创建family_members记录（Owner角色）
6. 更新users.current_family_id
7. 记录审计日志
8. 提交事务
9. 返回响应

响应:
{
  "success": true,
  "data": {
    "family_id": "uuid",
    "name": "我的家庭",
    "role": "owner",
    "permissions": ["all"],
    "joined_at": "2025-01-06T12:00:00Z"
  }
}
```

##### Step 5: 切换到新Family
```dart
Future<void> _switchToNewFamily(String familyId) async {
  final service = ref.read(familyServiceProvider);
  await service.switchFamily(familyId);
}

// 触发的API
POST /api/v1/families/switch
{
  "family_id": "uuid"
}

// 后端处理
1. 验证用户是否为该Family成员
2. 更新users.current_family_id
3. 返回成功
```

##### Step 6: UI状态更新
```dart
// providers/family_provider.dart
// 通过 ref.invalidate 触发重新获取
- userFamiliesProvider 重新加载
- currentFamilyProvider 更新为新Family
- Dashboard 自动刷新显示新Family数据
```

---

### 场景1.2：用户删除Family

#### 用户操作流程
```mermaid
用户进入 [家庭设置]
    ↓
滚动到危险区域
    ↓
点击 [删除家庭]
    ↓
显示警告对话框
    ↓
输入家庭名称确认
    ↓
点击 [确认删除]
    ↓
系统删除所有数据
    ↓
自动切换到其他Family
    ↓
返回主页
```

#### 详细实现步骤

##### Step 1: 显示删除按钮
**位置**: `FamilySettingsScreen` → 危险区域
```dart
// screens/family/family_settings_screen.dart
Widget _buildDangerZone() {
  // 只有Owner可以看到删除按钮
  if (currentMember.role != LedgerRole.owner) {
    return SizedBox.shrink();
  }
  
  return Card(
    color: Colors.red.shade50,
    child: Column(
      children: [
        ListTile(
          leading: Icon(Icons.warning, color: Colors.orange),
          title: Text('危险操作区域'),
          subtitle: Text('以下操作不可恢复，请谨慎操作'),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.delete_forever, color: Colors.red),
          title: Text('删除家庭', style: TextStyle(color: Colors.red)),
          subtitle: Text('永久删除家庭及所有相关数据'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showDeleteConfirmDialog,
        ),
      ],
    ),
  );
}
```

##### Step 2: 删除确认对话框
```dart
Future<void> _showDeleteConfirmDialog() async {
  final familyName = widget.ledger.name;
  final inputController = TextEditingController();
  String? errorText;
  
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // 防止误触关闭
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('确认删除家庭'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '⚠️ 警告：此操作不可恢复！',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text('删除此家庭将永久删除以下所有数据：'),
              SizedBox(height: 8),
              _buildDeleteWarningItem('${widget.accountCount} 个账户'),
              _buildDeleteWarningItem('${widget.transactionCount} 条交易记录'),
              _buildDeleteWarningItem('${widget.budgetCount} 个预算设置'),
              _buildDeleteWarningItem('${widget.memberCount} 个成员关系'),
              _buildDeleteWarningItem('所有分类和标签'),
              _buildDeleteWarningItem('所有附件和图片'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('请输入家庭名称 "$familyName" 以确认删除：'),
                    SizedBox(height: 8),
                    TextField(
                      controller: inputController,
                      decoration: InputDecoration(
                        hintText: '输入家庭名称',
                        errorText: errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          errorText = value != familyName 
                            ? '名称不匹配' 
                            : null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    ),
  );
  
  if (confirmed == true) {
    await _performDelete();
  }
}

Widget _buildDeleteWarningItem(String text) {
  return Padding(
    padding: EdgeInsets.only(left: 16, top: 4),
    child: Row(
      children: [
        Icon(Icons.close, size: 16, color: Colors.red),
        SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}
```

##### Step 3: 执行删除操作
```dart
Future<void> _performDelete() async {
  // 显示加载对话框
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('正在删除，请稍候...'),
        ],
      ),
    ),
  );
  
  try {
    // 调用删除API
    await ref.read(familyServiceProvider).deleteFamily(widget.ledger.id!);
    
    // 后端处理流程
    /*
    DELETE /api/v1/families/:id
    
    后端处理:
    1. 验证用户是Owner
    2. 开启事务
    3. 删除所有交易记录 (transactions)
    4. 删除所有账户 (accounts)
    5. 删除所有预算 (budgets)
    6. 删除所有分类 (categories)
    7. 删除所有成员关系 (family_members)
    8. 删除所有邀请 (invitations)
    9. 删除所有审计日志 (family_audit_logs)
    10. 删除家庭 (families)
    11. 如果是用户的current_family，更新为其他family
    12. 提交事务
    13. 返回成功
    */
    
    // 刷新Family列表
    ref.invalidate(userFamiliesProvider);
    
    // 获取用户的其他Family
    final families = await ref.read(userFamiliesProvider.future);
    
    if (families.isNotEmpty) {
      // 切换到第一个可用的Family
      await ref.read(familyServiceProvider).switchFamily(families.first.familyId);
    }
    
    // 关闭加载对话框
    Navigator.pop(context);
    
    // 返回主页
    context.go('/dashboard');
    
    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('家庭已删除'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // 关闭加载对话框
    Navigator.pop(context);
    
    // 显示错误
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('删除失败: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## 🟡 功能模块二：成员邀请与管理

### 场景2.1：Owner邀请新成员加入Family

#### 用户操作流程
```mermaid
Owner进入 [家庭成员]
    ↓
点击 [邀请成员]
    ↓
输入邮箱和选择角色
    ↓
点击 [发送邀请]
    ↓
系统生成邀请
    ↓
发送邮件通知
    ↓
显示邀请码
```

#### 详细实现步骤

##### Step 1: 打开邀请对话框
```dart
// screens/family/family_members_screen.dart
FloatingActionButton(
  onPressed: () => showDialog(
    context: context,
    builder: (_) => InviteMemberDialog(
      familyId: widget.ledger.id!,
      familyName: widget.ledger.name,
    ),
  ),
  child: Icon(Icons.person_add),
)
```

##### Step 2: 邀请成员对话框
```dart
// widgets/dialogs/invite_member_dialog.dart
class InviteMemberDialog extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;
  
  @override
  _InviteMemberDialogState createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _emailController = TextEditingController();
  LedgerRole _selectedRole = LedgerRole.viewer;
  bool _isLoading = false;
  String? _inviteCode;
  
  @override
  Widget build(BuildContext context) {
    if (_inviteCode != null) {
      // 显示邀请成功界面
      return AlertDialog(
        title: Text('邀请已发送'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text('邀请已发送到 ${_emailController.text}'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('邀请码', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text(
                    _inviteCode!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _inviteCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('邀请码已复制')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.share),
                        onPressed: _shareInvite,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('完成'),
          ),
        ],
      );
    }
    
    // 显示邀请表单
    return AlertDialog(
      title: Text('邀请成员'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: '邮箱地址',
              hintText: 'user@example.com',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<LedgerRole>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: '角色权限',
              prefixIcon: Icon(Icons.security),
            ),
            items: [
              DropdownMenuItem(
                value: LedgerRole.viewer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看者'),
                    Text('只能查看，不能修改', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: LedgerRole.editor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('编辑者'),
                    Text('可以添加和修改交易', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: LedgerRole.admin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('管理员'),
                    Text('可以管理成员和设置', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedRole = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendInvitation,
          child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('发送邀请'),
        ),
      ],
    );
  }
  
  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim();
    
    // 验证邮箱
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入有效的邮箱地址')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 调用API创建邀请
      final invitation = await ref.read(familyServiceProvider).createInvitation(
        familyId: widget.familyId,
        email: email,
        role: _selectedRole.value,
        permissions: _getDefaultPermissions(_selectedRole),
      );
      
      /*
      POST /api/v1/invitations
      {
        "family_id": "uuid",
        "email": "user@example.com",
        "role": "viewer",
        "permissions": ["view_accounts", "view_transactions"]
      }
      
      后端处理:
      1. 验证发起者权限 (需要InviteMembers权限)
      2. 检查被邀请者是否已是成员
      3. 检查是否有未过期的邀请
      4. 生成6位邀请码
      5. 创建invitations记录
      6. 发送邮件通知（包含邀请码和链接）
      7. 记录审计日志
      8. 返回邀请信息
      
      响应:
      {
        "id": "uuid",
        "invite_code": "ABC123",
        "expires_at": "2025-01-13T12:00:00Z"
      }
      */
      
      setState(() {
        _inviteCode = invitation.inviteCode;
        _isLoading = false;
      });
      
      // 刷新成员列表
      ref.invalidate(familyMembersProvider(widget.familyId));
      
    } catch (e) {
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('邀请失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  List<String> _getDefaultPermissions(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return []; // Owner拥有所有权限
      case LedgerRole.admin:
        return [
          'view_family_info',
          'update_family_info',
          'view_members',
          'invite_members',
          'remove_members',
          'view_accounts',
          'create_accounts',
          'edit_accounts',
          'delete_accounts',
          'view_transactions',
          'create_transactions',
          'edit_transactions',
          'delete_transactions',
        ];
      case LedgerRole.editor:
        return [
          'view_family_info',
          'view_members',
          'view_accounts',
          'create_accounts',
          'edit_accounts',
          'view_transactions',
          'create_transactions',
          'edit_transactions',
        ];
      case LedgerRole.viewer:
        return [
          'view_family_info',
          'view_members',
          'view_accounts',
          'view_transactions',
        ];
    }
  }
}
```

### 场景2.2：被邀请者接受邀请

#### 用户操作流程
```mermaid
用户收到邮件通知
    ↓
点击邮件中的链接/输入邀请码
    ↓
系统验证邀请
    ↓
显示Family信息
    ↓
点击 [接受邀请]
    ↓
加入Family
    ↓
自动切换到新Family
```

#### 详细实现步骤

##### Step 1: 通知入口
```dart
// screens/dashboard/dashboard_screen.dart
// 在AppBar添加通知图标
IconButton(
  icon: Stack(
    children: [
      Icon(Icons.notifications_outlined),
      Consumer(
        builder: (context, ref, _) {
          final pendingCount = ref.watch(pendingInvitationsCountProvider);
          if (pendingCount > 0) {
            return Positioned(
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
                  '$pendingCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SizedBox.shrink();
        },
      ),
    ],
  ),
  onPressed: () => context.go('/invitations'),
)

// providers/invitation_provider.dart
final pendingInvitationsProvider = FutureProvider<List<Invitation>>((ref) async {
  final service = ref.watch(familyServiceProvider);
  return await service.getMyPendingInvitations();
});

final pendingInvitationsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingInvitationsProvider).maybeWhen(
    data: (invitations) => invitations.length,
    orElse: () => 0,
  );
});
```

##### Step 2: 待处理邀请页面
```dart
// screens/invitations/pending_invitations_screen.dart
class PendingInvitationsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('待处理的邀请'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showEnterCodeDialog(context, ref),
            tooltip: '输入邀请码',
          ),
        ],
      ),
      body: invitationsAsync.when(
        data: (invitations) {
          if (invitations.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              return _buildInvitationCard(context, ref, invitation);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(pendingInvitationsProvider),
                child: Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInvitationCard(BuildContext context, WidgetRef ref, Invitation invitation) {
    final remainingTime = invitation.expiresAt.difference(DateTime.now());
    final isExpiringSoon = remainingTime.inHours < 24;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(Icons.family_restroom, color: Colors.white),
            ),
            title: Text(
              invitation.familyName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 16),
                    SizedBox(width: 4),
                    Text('邀请人: ${invitation.inviterName}'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.security, size: 16),
                    SizedBox(width: 4),
                    Text('角色: ${_getRoleLabel(invitation.role)}'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer, size: 16, 
                      color: isExpiringSoon ? Colors.orange : null),
                    SizedBox(width: 4),
                    Text(
                      '过期时间: ${_formatRemainingTime(remainingTime)}',
                      style: TextStyle(
                        color: isExpiringSoon ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _declineInvitation(context, ref, invitation),
                  child: Text('拒绝'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _acceptInvitation(context, ref, invitation),
                  child: Text('接受邀请'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _acceptInvitation(
    BuildContext context, 
    WidgetRef ref, 
    Invitation invitation,
  ) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认加入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您即将加入家庭: ${invitation.familyName}'),
            SizedBox(height: 8),
            Text('角色: ${_getRoleLabel(invitation.role)}'),
            SizedBox(height: 16),
            Text(
              '加入后，您将可以访问该家庭的财务数据。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认加入'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在处理...'),
          ],
        ),
      ),
    );
    
    try {
      // 调用接受邀请API
      await ref.read(familyServiceProvider).acceptInvitation(
        invitationId: invitation.id,
      );
      
      /*
      POST /api/v1/invitations/accept
      {
        "invitation_id": "uuid"
      }
      
      后端处理:
      1. 验证邀请是否存在且未过期
      2. 开启事务
      3. 创建family_members记录
      4. 更新invitation状态为accepted
      5. 更新用户current_family_id
      6. 记录审计日志
      7. 提交事务
      8. 返回成功
      */
      
      // 刷新数据
      ref.invalidate(pendingInvitationsProvider);
      ref.invalidate(userFamiliesProvider);
      
      // 切换到新Family
      await ref.read(familyServiceProvider).switchFamily(invitation.familyId);
      
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 返回主页
      context.go('/dashboard');
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功加入 ${invitation.familyName}'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 显示错误
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## 🟢 功能模块三：权限管理

### 场景3.1：Admin修改成员权限

#### 用户操作流程
```mermaid
Admin进入 [家庭成员]
    ↓
找到目标成员
    ↓
点击 [编辑权限]
    ↓
修改角色或自定义权限
    ↓
点击 [保存]
    ↓
系统更新权限
    ↓
通知被修改成员
```

#### 详细实现步骤

##### Step 1: 权限编辑入口
```dart
// screens/family/family_members_screen.dart
Widget _buildMemberCard(LedgerMember member) {
  final currentUserRole = ref.watch(currentMemberRoleProvider);
  final canEdit = _canEditMember(currentUserRole, member.role);
  
  return Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: member.avatar != null 
          ? NetworkImage(member.avatar!)
          : null,
        child: member.avatar == null
          ? Text(member.name[0].toUpperCase())
          : null,
      ),
      title: Text(member.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.email),
          Chip(
            label: Text(_getRoleLabel(member.role)),
            backgroundColor: _getRoleColor(member.role),
          ),
        ],
      ),
      trailing: canEdit
        ? PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit_role':
                  _showEditRoleDialog(member);
                  break;
                case 'edit_permissions':
                  _navigateToPermissionsScreen(member);
                  break;
                case 'remove':
                  _confirmRemoveMember(member);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit_role',
                child: ListTile(
                  leading: Icon(Icons.swap_vert),
                  title: Text('更改角色'),
                ),
              ),
              PopupMenuItem(
                value: 'edit_permissions',
                child: ListTile(
                  leading: Icon(Icons.security),
                  title: Text('自定义权限'),
                ),
              ),
              if (member.role != LedgerRole.owner)
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.remove_circle, color: Colors.red),
                    title: Text('移除成员', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          )
        : null,
    ),
  );
}

bool _canEditMember(LedgerRole currentRole, LedgerRole targetRole) {
  // Owner可以编辑所有人（除了自己）
  if (currentRole == LedgerRole.owner) {
    return true;
  }
  
  // Admin可以编辑Member和Viewer
  if (currentRole == LedgerRole.admin) {
    return targetRole == LedgerRole.editor || targetRole == LedgerRole.viewer;
  }
  
  return false;
}
```

##### Step 2: 角色修改对话框
```dart
Future<void> _showEditRoleDialog(LedgerMember member) async {
  LedgerRole? selectedRole = member.role;
  
  final newRole = await showDialog<LedgerRole>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('更改角色 - ${member.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前角色: ${_getRoleLabel(member.role)}'),
          SizedBox(height: 16),
          ...LedgerRole.values
            .where((role) => role != LedgerRole.owner) // 不能设置为Owner
            .map((role) => RadioListTile<LedgerRole>(
              title: Text(_getRoleLabel(role)),
              subtitle: Text(_getRoleDescription(role)),
              value: role,
              groupValue: selectedRole,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
      ],
    ),
  );
  
  if (newRole != null && newRole != member.role) {
    await _updateMemberRole(member, newRole);
  }
}

Future<void> _updateMemberRole(LedgerMember member, LedgerRole newRole) async {
  // 显示加载
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('正在更新...'),
        ],
      ),
    ),
  );
  
  try {
    await ref.read(familyServiceProvider).updateMemberRole(
      familyId: widget.ledger.id!,
      userId: member.userId,
      role: newRole.value,
    );
    
    /*
    PUT /api/v1/families/:family_id/members/:user_id/role
    {
      "role": "admin"
    }
    
    后端处理:
    1. 验证操作者权限
    2. 验证目标用户不是Owner
    3. 更新family_members.role
    4. 更新权限（根据新角色设置默认权限）
    5. 记录审计日志
    6. 发送通知给被修改者
    7. 返回成功
    */
    
    // 刷新成员列表
    ref.invalidate(familyMembersProvider(widget.ledger.id!));
    
    // 关闭加载对话框
    Navigator.pop(context);
    
    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('角色已更新'),
        backgroundColor: Colors.green,
      ),
    );
    
  } catch (e) {
    // 关闭加载对话框
    Navigator.pop(context);
    
    // 显示错误
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('更新失败: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

##### Step 3: 自定义权限页面
```dart
// screens/family/member_permissions_screen.dart
class MemberPermissionsScreen extends ConsumerStatefulWidget {
  final String familyId;
  final LedgerMember member;
  
  @override
  _MemberPermissionsScreenState createState() => _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState extends ConsumerState<MemberPermissionsScreen> {
  late Map<String, bool> selectedPermissions;
  bool hasChanges = false;
  
  // 权限定义
  static const permissionGroups = {
    '家庭管理': [
      Permission('view_family_info', '查看家庭信息', '可以查看家庭基本信息和设置'),
      Permission('update_family_info', '更新家庭设置', '可以修改家庭名称、货币等设置'),
      Permission('delete_family', '删除家庭', '可以删除整个家庭（危险操作）'),
    ],
    '成员管理': [
      Permission('view_members', '查看成员', '可以查看家庭成员列表'),
      Permission('invite_members', '邀请成员', '可以邀请新成员加入'),
      Permission('remove_members', '移除成员', '可以移除其他成员'),
      Permission('update_member_roles', '管理权限', '可以修改成员角色和权限'),
    ],
    '账户管理': [
      Permission('view_accounts', '查看账户', '可以查看所有账户信息'),
      Permission('create_accounts', '创建账户', '可以创建新账户'),
      Permission('edit_accounts', '编辑账户', '可以修改账户信息'),
      Permission('delete_accounts', '删除账户', '可以删除账户'),
    ],
    '交易管理': [
      Permission('view_transactions', '查看交易', '可以查看所有交易记录'),
      Permission('create_transactions', '创建交易', '可以添加新交易'),
      Permission('edit_transactions', '编辑交易', '可以修改交易信息'),
      Permission('delete_transactions', '删除交易', '可以删除交易'),
      Permission('bulk_edit_transactions', '批量操作', '可以批量编辑或删除交易'),
    ],
    '预算管理': [
      Permission('view_budgets', '查看预算', '可以查看预算设置'),
      Permission('create_budgets', '创建预算', '可以创建新预算'),
      Permission('edit_budgets', '编辑预算', '可以修改预算'),
      Permission('delete_budgets', '删除预算', '可以删除预算'),
    ],
    '报表查看': [
      Permission('view_reports', '查看报表', '可以查看统计报表'),
      Permission('export_reports', '导出报表', '可以导出报表数据'),
    ],
    '系统管理': [
      Permission('manage_settings', '管理设置', '可以修改系统设置'),
      Permission('view_audit_log', '查看审计日志', '可以查看操作记录'),
    ],
  };
  
  @override
  void initState() {
    super.initState();
    selectedPermissions = Map.from(widget.member.permissions);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自定义权限'),
            Text(
              widget.member.name,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          if (hasChanges)
            TextButton(
              onPressed: _savePermissions,
              child: Text('保存', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // 角色提示
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前角色: ${_getRoleLabel(widget.member.role)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '您可以为该成员自定义权限，这将覆盖角色的默认权限。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          
          // 快速操作
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAll,
                    child: Text('全选'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deselectAll,
                    child: Text('取消全选'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetToDefault,
                    child: Text('恢复默认'),
                  ),
                ),
              ],
            ),
          ),
          
          // 权限列表
          Expanded(
            child: ListView(
              children: permissionGroups.entries.map((group) {
                return _buildPermissionGroup(
                  group.key,
                  group.value,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionGroup(String groupName, List<Permission> permissions) {
    final allSelected = permissions.every(
      (p) => selectedPermissions[p.key] ?? false,
    );
    final someSelected = permissions.any(
      (p) => selectedPermissions[p.key] ?? false,
    );
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Checkbox(
                value: allSelected,
                tristate: true,
                onChanged: someSelected && !allSelected ? null : (value) {
                  setState(() {
                    for (final permission in permissions) {
                      selectedPermissions[permission.key] = value ?? false;
                    }
                    hasChanges = true;
                  });
                },
              ),
              Text(groupName),
              SizedBox(width: 8),
              Text(
                '(${permissions.where((p) => selectedPermissions[p.key] ?? false).length}/${permissions.length})',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          children: permissions.map((permission) {
            return CheckboxListTile(
              title: Text(permission.label),
              subtitle: Text(
                permission.description,
                style: TextStyle(fontSize: 12),
              ),
              value: selectedPermissions[permission.key] ?? false,
              onChanged: (value) {
                setState(() {
                  selectedPermissions[permission.key] = value ?? false;
                  hasChanges = true;
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }
  
  Future<void> _savePermissions() async {
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在保存...'),
          ],
        ),
      ),
    );
    
    try {
      // 只发送选中的权限
      final permissions = selectedPermissions.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
      
      await ref.read(familyServiceProvider).updateMemberPermissions(
        familyId: widget.familyId,
        userId: widget.member.userId,
        permissions: permissions,
      );
      
      /*
      PUT /api/v1/families/:family_id/members/:user_id/permissions
      {
        "permissions": [
          "view_accounts",
          "create_transactions",
          ...
        ]
      }
      
      后端处理:
      1. 验证操作者权限（需要UpdateMemberRoles）
      2. 验证目标不是Owner
      3. 更新family_members.permissions
      4. 记录审计日志
      5. 发送通知
      6. 返回成功
      */
      
      // 刷新成员信息
      ref.invalidate(familyMembersProvider(widget.familyId));
      
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 返回上一页
      Navigator.pop(context);
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('权限已更新'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 显示错误
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

## 🔵 功能模块四：审计日志

### 场景4.1：查看家庭操作记录

#### 用户操作流程
```mermaid
Admin进入 [家庭设置]
    ↓
点击 [审计日志]
    ↓
查看操作记录
    ↓
筛选时间/用户/操作类型
    ↓
导出日志
```

#### 详细实现步骤

##### Step 1: 审计日志入口
```dart
// screens/family/family_settings_screen.dart
ListTile(
  leading: Icon(Icons.history),
  title: Text('审计日志'),
  subtitle: Text('查看家庭操作记录'),
  trailing: Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    // 检查权限
    if (!_hasPermission('view_audit_log')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('您没有查看审计日志的权限')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuditLogsScreen(
          familyId: widget.ledger.id!,
          familyName: widget.ledger.name,
        ),
      ),
    );
  },
)
```

##### Step 2: 审计日志页面
```dart
// screens/audit/audit_logs_screen.dart
class AuditLogsScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;
  
  @override
  _AuditLogsScreenState createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  // 筛选条件
  DateTime? startDate;
  DateTime? endDate;
  String? selectedUserId;
  String? selectedAction;
  int currentPage = 1;
  
  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider(
      AuditLogQuery(
        familyId: widget.familyId,
        page: currentPage,
        startDate: startDate,
        endDate: endDate,
        userId: selectedUserId,
        action: selectedAction,
      ),
    ));
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('审计日志'),
            Text(
              widget.familyName,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: '筛选',
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: '导出',
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (startDate != null)
                      Chip(
                        label: Text('从: ${_formatDate(startDate!)}'),
                        onDeleted: () => setState(() => startDate = null),
                      ),
                    if (endDate != null)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text('到: ${_formatDate(endDate!)}'),
                          onDeleted: () => setState(() => endDate = null),
                        ),
                      ),
                    if (selectedUserId != null)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text('用户: ${_getUserName(selectedUserId!)}'),
                          onDeleted: () => setState(() => selectedUserId = null),
                        ),
                      ),
                    if (selectedAction != null)
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Chip(
                          label: Text('操作: ${_getActionLabel(selectedAction!)}'),
                          onDeleted: () => setState(() => selectedAction = null),
                        ),
                      ),
                    if (_hasActiveFilters())
                      Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: TextButton(
                          onPressed: _clearFilters,
                          child: Text('清除筛选'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // 日志列表
          Expanded(
            child: logsAsync.when(
              data: (result) {
                if (result.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无操作记录'),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: result.items.length + 1, // +1 for pagination
                  itemBuilder: (context, index) {
                    if (index == result.items.length) {
                      // 分页控件
                      return _buildPagination(result);
                    }
                    
                    final log = result.items[index];
                    return _buildLogItem(log);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('加载失败'),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.refresh(auditLogsProvider(
                        AuditLogQuery(
                          familyId: widget.familyId,
                          page: currentPage,
                        ),
                      )),
                      child: Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogItem(AuditLog log) {
    final icon = _getActionIcon(log.action);
    final color = _getActionColor(log.action);
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getActionDescription(log),
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          log.userName,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.access_time, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          _formatDateTime(log.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (log.ipAddress != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.computer, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'IP: ${log.ipAddress}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getActionDescription(AuditLog log) {
    // 根据action和changes生成描述
    switch (log.action) {
      case 'family.create':
        return '创建了家庭';
      case 'family.update':
        return '更新了家庭设置';
      case 'family.delete':
        return '删除了家庭';
      case 'member.add':
        return '添加了成员 ${log.changes?['member_name'] ?? ''}';
      case 'member.remove':
        return '移除了成员 ${log.changes?['member_name'] ?? ''}';
      case 'member.role_change':
        return '修改了 ${log.changes?['member_name'] ?? ''} 的角色';
      case 'member.permission_change':
        return '修改了 ${log.changes?['member_name'] ?? ''} 的权限';
      case 'account.create':
        return '创建了账户 ${log.changes?['account_name'] ?? ''}';
      case 'account.update':
        return '更新了账户 ${log.changes?['account_name'] ?? ''}';
      case 'account.delete':
        return '删除了账户 ${log.changes?['account_name'] ?? ''}';
      case 'transaction.create':
        return '创建了交易';
      case 'transaction.update':
        return '更新了交易';
      case 'transaction.delete':
        return '删除了交易';
      case 'transaction.bulk_edit':
        return '批量编辑了 ${log.changes?['count'] ?? 0} 条交易';
      case 'invitation.create':
        return '发送了邀请给 ${log.changes?['email'] ?? ''}';
      case 'invitation.accept':
        return '接受了邀请';
      case 'invitation.cancel':
        return '取消了邀请';
      default:
        return log.action;
    }
  }
  
  Future<void> _exportLogs() async {
    // 显示导出选项
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出审计日志'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.table_chart),
              title: Text('CSV格式'),
              subtitle: Text('适合在Excel中打开'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading: Icon(Icons.code),
              title: Text('JSON格式'),
              subtitle: Text('适合程序处理'),
              onTap: () => Navigator.pop(context, 'json'),
            ),
          ],
        ),
      ),
    );
    
    if (format == null) return;
    
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导出...'),
          ],
        ),
      ),
    );
    
    try {
      await ref.read(auditServiceProvider).exportAuditLogs(
        familyId: widget.familyId,
        format: format,
        startDate: startDate,
        endDate: endDate,
        userId: selectedUserId,
        action: selectedAction,
      );
      
      /*
      GET /api/v1/families/:id/audit-logs/export?format=csv
      
      后端处理:
      1. 验证权限
      2. 查询审计日志
      3. 生成CSV/JSON文件
      4. 返回文件流
      */
      
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出成功'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      // 关闭加载对话框
      Navigator.pop(context);
      
      // 显示错误
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// providers/audit_provider.dart
final auditLogsProvider = FutureProvider.family<PaginatedResult<AuditLog>, AuditLogQuery>((ref, query) async {
  final service = ref.watch(auditServiceProvider);
  return await service.getAuditLogs(
    familyId: query.familyId,
    page: query.page,
    perPage: query.perPage,
    startDate: query.startDate,
    endDate: query.endDate,
    userId: query.userId,
    action: query.action,
  );
});
```

---

## 📊 数据流总结

### 前端状态管理流程
```
用户操作
    ↓
UI组件触发事件
    ↓
调用Service层方法
    ↓
Service发送HTTP请求到后端API
    ↓
后端处理并返回响应
    ↓
Service处理响应/错误
    ↓
更新Provider状态
    ↓
UI自动刷新
    ↓
显示反馈（成功/错误提示）
```

### 权限验证流程
```
前端:
1. UI层 - 根据权限显示/隐藏按钮
2. 操作前 - 检查本地权限缓存
3. 请求时 - 携带JWT token

后端:
1. 中间件 - 验证JWT token
2. 中间件 - 加载用户权限
3. Handler - 验证具体权限
4. 执行操作或返回403
```

### 错误处理策略
```dart
try {
  // 显示加载状态
  setState(() => isLoading = true);
  
  // 调用API
  final result = await service.someMethod();
  
  // 更新状态
  ref.invalidate(someProvider);
  
  // 显示成功提示
  showSuccessMessage();
  
} catch (e) {
  // 分析错误类型
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 401:
        // 未认证，跳转登录
        context.go('/login');
        break;
      case 403:
        // 无权限
        showErrorMessage('您没有权限执行此操作');
        break;
      case 404:
        // 资源不存在
        showErrorMessage('数据不存在');
        break;
      case 409:
        // 冲突（如重复）
        showErrorMessage('操作冲突: ${e.response?.data['error']['message']}');
        break;
      default:
        // 其他错误
        showErrorMessage('操作失败: ${e.toString()}');
    }
  } else {
    // 网络或其他错误
    showErrorMessage('网络错误，请稍后重试');
  }
} finally {
  // 恢复UI状态
  setState(() => isLoading = false);
}
```

---

## 📝 实施计划

### 第一周：核心功能
- Day 1: 实现删除Family功能
- Day 2: 实现邀请创建和发送
- Day 3: 实现邀请接受流程
- Day 4: 实现邀请码验证和管理
- Day 5: 测试和修复

### 第二周：权限和审计
- Day 1-2: 实现权限管理系统
- Day 3-4: 实现审计日志系统
- Day 5: 集成测试

### 第三周：优化和完善
- Day 1-2: UI优化和动画
- Day 3: 错误处理增强
- Day 4: 性能优化
- Day 5: 最终测试

---

**文档创建**: 2025-01-06  
**预计完成**: 3周  
**涵盖功能**: 20+ 个用户场景，50+ 个API调用