import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/family.dart' as family_model;
import '../../services/api/family_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_overlay.dart';

/// 权限编辑界面
class FamilyPermissionsEditorScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const FamilyPermissionsEditorScreen({
    Key? key,
    required this.familyId,
    required this.familyName,
  }) : super(key: key);

  @override
  ConsumerState<FamilyPermissionsEditorScreen> createState() =>
      _FamilyPermissionsEditorScreenState();
}

class _FamilyPermissionsEditorScreenState
    extends ConsumerState<FamilyPermissionsEditorScreen> {
  final FamilyService _familyService = FamilyService();

  bool _isLoading = false;
  late List<RolePermissions> _rolePermissions;
  late List<CustomRole> _customRoles;
  String? _selectedRole;
  final Map<String, bool> _pendingChanges = {};

  // 权限分类
  final Map<String, List<Permission>> _permissionCategories = {
    '交易管理': [
      Permission('transaction.create', '创建交易', '允许创建新的收支记录'),
      Permission('transaction.edit', '编辑交易', '允许编辑已有的交易记录'),
      Permission('transaction.delete', '删除交易', '允许删除交易记录'),
      Permission('transaction.view', '查看交易', '允许查看所有交易记录'),
      Permission('transaction.export', '导出交易', '允许导出交易数据'),
    ],
    '预算管理': [
      Permission('budget.create', '创建预算', '允许创建新的预算计划'),
      Permission('budget.edit', '编辑预算', '允许修改预算设置'),
      Permission('budget.delete', '删除预算', '允许删除预算'),
      Permission('budget.view', '查看预算', '允许查看预算信息'),
    ],
    '成员管理': [
      Permission('member.invite', '邀请成员', '允许邀请新成员加入'),
      Permission('member.remove', '移除成员', '允许移除家庭成员'),
      Permission('member.edit_role', '修改角色', '允许修改成员角色'),
      Permission('member.view', '查看成员', '允许查看成员列表'),
    ],
    '分类管理': [
      Permission('category.create', '创建分类', '允许创建新的分类'),
      Permission('category.edit', '编辑分类', '允许修改分类信息'),
      Permission('category.delete', '删除分类', '允许删除分类'),
      Permission('category.view', '查看分类', '允许查看分类列表'),
    ],
    '报表统计': [
      Permission('report.view', '查看报表', '允许查看统计报表'),
      Permission('report.export', '导出报表', '允许导出报表数据'),
      Permission('report.share', '分享报表', '允许分享报表给他人'),
    ],
    '系统设置': [
      Permission('settings.edit', '修改设置', '允许修改家庭设置'),
      Permission('settings.view', '查看设置', '允许查看家庭设置'),
      Permission('permissions.edit', '权限管理', '允许管理权限设置'),
      Permission('audit.view', '查看审计', '允许查看操作日志'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _initializePermissions();
    _loadPermissions();
  }

  void _initializePermissions() {
    // 初始化默认角色权限
    _rolePermissions = [
      RolePermissions(
        role: family_model.FamilyRole.owner,
        permissions: _getAllPermissionIds(),
        isSystem: true,
      ),
      RolePermissions(
        role: family_model.FamilyRole.admin,
        permissions: _getAdminPermissions(),
        isSystem: true,
      ),
      RolePermissions(
        role: family_model.FamilyRole.member,
        permissions: _getMemberPermissions(),
        isSystem: true,
      ),
      RolePermissions(
        role: family_model.FamilyRole.viewer,
        permissions: _getViewerPermissions(),
        isSystem: true,
      ),
    ];

    _customRoles = [];
  }

  List<String> _getAllPermissionIds() {
    final permissions = <String>[];
    _permissionCategories.forEach((_, perms) {
      permissions.addAll(perms.map((p) => p.id));
    });
    return permissions;
  }

  List<String> _getAdminPermissions() {
    final excludedPermissions = ['permissions.edit', 'member.remove'];
    return _getAllPermissionIds()
        .where((id) => !excludedPermissions.contains(id))
        .toList();
  }

  List<String> _getMemberPermissions() {
    return [
      'transaction.create',
      'transaction.edit',
      'transaction.view',
      'budget.view',
      'member.view',
      'category.view',
      'report.view',
      'settings.view',
    ];
  }

  List<String> _getViewerPermissions() {
    return [
      'transaction.view',
      'budget.view',
      'member.view',
      'category.view',
      'report.view',
      'settings.view',
    ];
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);

    try {
      // 从服务器加载权限配置
      final permissions =
          await _familyService.getFamilyPermissions(widget.familyId);
      final customRoles = await _familyService.getCustomRoles(widget.familyId);

      setState(() {
        if (permissions != null) {
          _rolePermissions = permissions;
        }
        if (customRoles != null) {
          _customRoles = customRoles;
        }
      });
    } catch (e) {
      _showError('加载权限配置失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    if (_pendingChanges.isEmpty) {
      _showMessage('没有需要保存的更改');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 应用待处理的更改
      if (_selectedRole != null) {
        final roleIndex = _rolePermissions.indexWhere(
          (rp) => rp.roleKey == _selectedRole,
        );

        if (roleIndex >= 0) {
          final updatedPermissions = List<String>.from(
            _rolePermissions[roleIndex].permissions,
          );

          _pendingChanges.forEach((permissionId, enabled) {
            if (enabled) {
              if (!updatedPermissions.contains(permissionId)) {
                updatedPermissions.add(permissionId);
              }
            } else {
              updatedPermissions.remove(permissionId);
            }
          });

          // 保存到服务器
          final success = await _familyService.updateRolePermissions(
            widget.familyId,
            _selectedRole!,
            updatedPermissions,
          );

          if (success) {
            setState(() {
              _rolePermissions[roleIndex] =
                  _rolePermissions[roleIndex].copyWith(
                permissions: updatedPermissions,
              );
              _pendingChanges.clear();
            });
            _showMessage('权限已更新');
          } else {
            _showError('保存权限失败');
          }
        }
      }
    } catch (e) {
      _showError('保存权限失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createCustomRole() {
    showDialog(
      context: context,
      builder: (context) => _CreateCustomRoleDialog(
        onCreateRole: (name, description, baseRole) async {
          setState(() => _isLoading = true);

          try {
            // 获取基础角色的权限
            final basePermissions = _rolePermissions
                .firstWhere((rp) => rp.roleKey == baseRole)
                .permissions;

            final customRole = CustomRole(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              description: description,
              permissions: basePermissions,
              createdAt: DateTime.now(),
            );

            final success = await _familyService.createCustomRole(
              widget.familyId,
              customRole,
            );

            if (success) {
              setState(() {
                _customRoles.add(customRole);
                _rolePermissions.add(RolePermissions(
                  roleKey: customRole.id,
                  roleName: customRole.name,
                  permissions: customRole.permissions,
                  isSystem: false,
                ));
              });
              _showMessage('自定义角色已创建');
            } else {
              _showError('创建角色失败');
            }
          } catch (e) {
            _showError('创建角色失败: $e');
          } finally {
            setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  void _deleteCustomRole(String roleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: const Text('确定要删除这个自定义角色吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                final success = await _familyService.deleteCustomRole(
                  widget.familyId,
                  roleId,
                );

                if (success) {
                  setState(() {
                    _customRoles.removeWhere((r) => r.id == roleId);
                    _rolePermissions.removeWhere((rp) => rp.roleKey == roleId);
                    if (_selectedRole == roleId) {
                      _selectedRole = null;
                    }
                  });
                  _showMessage('角色已删除');
                } else {
                  _showError('删除角色失败');
                }
              } catch (e) {
                _showError('删除角色失败: $e');
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showPermissionTemplate() {
    showDialog(
      context: context,
      builder: (context) => _PermissionTemplateDialog(
        onApplyTemplate: (template) {
          setState(() {
            _pendingChanges.clear();

            // 应用模板
            final templatePermissions = _getTemplatePermissions(template);
            final currentPermissions = _selectedRole != null
                ? _rolePermissions
                    .firstWhere((rp) => rp.roleKey == _selectedRole)
                    .permissions
                : [];

            // 计算差异
            for (final permissionId in _getAllPermissionIds()) {
              final shouldHave = templatePermissions.contains(permissionId);
              final currentlyHas = currentPermissions.contains(permissionId);

              if (shouldHave != currentlyHas) {
                _pendingChanges[permissionId] = shouldHave;
              }
            }
          });
          _showMessage('已应用权限模板');
        },
      ),
    );
  }

  List<String> _getTemplatePermissions(PermissionTemplate template) {
    switch (template) {
      case PermissionTemplate.fullAccess:
        return _getAllPermissionIds();
      case PermissionTemplate.readOnly:
        return _getViewerPermissions();
      case PermissionTemplate.contributor:
        return _getMemberPermissions();
      case PermissionTemplate.moderator:
        return _getAdminPermissions();
      case PermissionTemplate.financial:
        return [
          'transaction.create',
          'transaction.edit',
          'transaction.view',
          'budget.create',
          'budget.edit',
          'budget.view',
          'report.view',
          'report.export',
        ];
      case PermissionTemplate.minimal:
        return ['transaction.view', 'report.view'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('权限管理'),
              const Text(
                widget.familyName,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (_pendingChanges.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() => _pendingChanges.clear());
                },
                icon: const Icon(Icons.clear),
                label: const Text('重置'),
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _pendingChanges.isNotEmpty ? _savePermissions : null,
              tooltip: '保存更改',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'create_role':
                    _createCustomRole();
                    break;
                  case 'apply_template':
                    _showPermissionTemplate();
                    break;
                  case 'export':
                    _exportPermissions();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create_role',
                  child: ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('创建自定义角色'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'apply_template',
                  child: ListTile(
                    leading: const Icon(Icons.dashboard_customize),
                    title: const Text('应用权限模板'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('导出权限配置'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Row(
          children: [
            // 左侧：角色列表
            Container(
              width: 250,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    child: const Text(
                      '角色列表',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        // 系统角色
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: const Text(
                            '系统角色',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        ..._rolePermissions
                            .where((rp) => rp.isSystem)
                            .map((rp) => _buildRoleItem(rp)),

                        // 自定义角色
                        if (_customRoles.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: const Text(
                              '自定义角色',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          ..._customRoles
                              .map((role) => _buildCustomRoleItem(role)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 右侧：权限矩阵
            Expanded(
              child: _selectedRole == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.security,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '请选择一个角色查看权限',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildPermissionMatrix(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleItem(RolePermissions rolePermissions) {
    final isSelected = _selectedRole == rolePermissions.roleKey;
    final theme = Theme.of(context);

    return ListTile(
      selected: isSelected,
      leading: const Icon(
        _getRoleconst Icon(rolePermissions.roleKey),
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: const Text(rolePermissions.roleName ?? rolePermissions.roleKey),
      subtitle: const Text(
        '${rolePermissions.permissions.length} 项权限',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: rolePermissions.isSystem
          ? const Chip(
              label: const Text('系统', style: TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : null,
      onTap: () {
        setState(() {
          _selectedRole = rolePermissions.roleKey;
          _pendingChanges.clear();
        });
      },
    );
  }

  Widget _buildCustomRoleItem(CustomRole role) {
    final isSelected = _selectedRole == role.id;
    final theme = Theme.of(context);

    return ListTile(
      selected: isSelected,
      leading: const Icon(
        Icons.person_outline,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: const Text(role.name),
      subtitle: const Text(
        role.description ?? '${role.permissions.length} 项权限',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: () => _deleteCustomRole(role.id),
      ),
      onTap: () {
        setState(() {
          _selectedRole = role.id;
          _pendingChanges.clear();
        });
      },
    );
  }

  Widget _buildPermissionMatrix() {
    final theme = Theme.of(context);
    final currentPermissions = _rolePermissions
        .firstWhere((rp) => rp.roleKey == _selectedRole)
        .permissions;
    final isSystemRole = _rolePermissions
        .firstWhere((rp) => rp.roleKey == _selectedRole)
        .isSystem;

    // Owner角色不能编辑
    final isOwner = _selectedRole == family_model.FamilyRole.owner.toString();

    return Column(
      children: [
        // 头部信息
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      _rolePermissions
                              .firstWhere((rp) => rp.roleKey == _selectedRole)
                              .roleName ??
                          _selectedRole!,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      isOwner ? '拥有者角色拥有所有权限，不可修改' : '勾选权限项以授予该角色相应权限',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_pendingChanges.isNotEmpty)
                Chip(
                  label: const Text('${_pendingChanges.length} 项待保存'),
                  backgroundColor: theme.colorScheme.errorContainer,
                ),
            ],
          ),
        ),

        // 权限列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _permissionCategories.entries.map((category) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text(
                    category.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: category.value.map((permission) {
                    final hasPermission =
                        currentPermissions.contains(permission.id);
                    final hasPendingChange =
                        _pendingChanges.containsKey(permission.id);
                    final willHavePermission = hasPendingChange
                        ? _pendingChanges[permission.id]!
                        : hasPermission;

                    return ListTile(
                      leading: Checkbox(
                        value: willHavePermission,
                        onChanged: isOwner
                            ? null
                            : (value) {
                                setState(() {
                                  if (value != hasPermission) {
                                    _pendingChanges[permission.id] = value!;
                                  } else {
                                    _pendingChanges.remove(permission.id);
                                  }
                                });
                              },
                      ),
                      title: const Text(permission.name),
                      subtitle: const Text(
                        permission.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: hasPendingChange
                          ? const Icon(
                              Icons.circle,
                              size: 8,
                              color: theme.colorScheme.error,
                            )
                          : null,
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _getRoleconst Icon(String role) {
    if (role == family_model.FamilyRole.owner.toString()) {
      return Icons.star;
    } else if (role == family_model.FamilyRole.admin.toString()) {
      return Icons.admin_panel_settings;
    } else if (role == family_model.FamilyRole.member.toString()) {
      return Icons.person;
    } else if (role == family_model.FamilyRole.viewer.toString()) {
      return Icons.visibility;
    }
    return Icons.person_outline;
  }

  void _exportPermissions() {
    // TODO: 实现导出功能
    _showMessage('导出功能开发中');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text(message)),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// 权限定义
class Permission {
  final String id;
  final String name;
  final String description;

  Permission(this.id, this.name, this.description);
}

/// 角色权限
class RolePermissions {
  final dynamic role;
  final String roleKey;
  final String? roleName;
  final List<String> permissions;
  final bool isSystem;

  RolePermissions({
    this.role,
    String? roleKey,
    this.roleName,
    required this.permissions,
    required this.isSystem,
  }) : roleKey = roleKey ?? role.toString();

  RolePermissions copyWith({
    List<String>? permissions,
  }) {
    return RolePermissions(
      role: role,
      roleKey: roleKey,
      roleName: roleName,
      permissions: permissions ?? this.permissions,
      isSystem: isSystem,
    );
  }
}

/// 自定义角色
class CustomRole {
  final String id;
  final String name;
  final String? description;
  final List<String> permissions;
  final DateTime createdAt;

  CustomRole({
    required this.id,
    required this.name,
    this.description,
    required this.permissions,
    required this.createdAt,
  });
}

/// 权限模板
enum PermissionTemplate {
  fullAccess,
  readOnly,
  contributor,
  moderator,
  financial,
  minimal,
}

/// 创建自定义角色对话框
class _CreateCustomRoleDialog extends StatefulWidget {
  final Function(String name, String? description, String baseRole)
      onCreateRole;

  const _CreateCustomRoleDialog({required this.onCreateRole});

  @override
  State<_CreateCustomRoleDialog> createState() =>
      _CreateCustomRoleDialogState();
}

class _CreateCustomRoleDialogState extends State<_CreateCustomRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _baseRole = family_model.FamilyRole.member.toString();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建自定义角色'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '角色名称',
                hintText: '例如：财务管理员',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入角色名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '角色的职责说明',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _baseRole,
              decoration: const InputDecoration(
                labelText: '基于角色',
                helperText: '新角色将继承所选角色的权限',
              ),
              items: [
                DropdownMenuItem(
                  value: family_model.FamilyRole.admin.toString(),
                  child: const Text('管理员'),
                ),
                DropdownMenuItem(
                  value: family_model.FamilyRole.member.toString(),
                  child: const Text('成员'),
                ),
                DropdownMenuItem(
                  value: family_model.FamilyRole.viewer.toString(),
                  child: const Text('观察者'),
                ),
              ],
              onChanged: (value) {
                setState(() => _baseRole = value!);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context);
              widget.onCreateRole(
                _nameController.text,
                _descriptionController.text.isEmpty
                    ? null
                    : _descriptionController.text,
                _baseRole,
              );
            }
          },
          child: const Text('创建'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// 权限模板对话框
class _PermissionTemplateDialog extends StatelessWidget {
  final Function(PermissionTemplate) onApplyTemplate;

  const _PermissionTemplateDialog({required this.onApplyTemplate});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择权限模板'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('完全访问'),
            subtitle: const Text('拥有所有权限'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.fullAccess);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('只读访问'),
            subtitle: const Text('仅可查看，不可修改'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.readOnly);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('贡献者'),
            subtitle: const Text('可创建和编辑内容'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.contributor);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('协管员'),
            subtitle: const Text('管理权限但不能删除'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.moderator);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: const Text('财务专员'),
            subtitle: const Text('仅管理交易和预算'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.financial);
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('最小权限'),
            subtitle: const Text('仅查看交易和报表'),
            onTap: () {
              Navigator.pop(context);
              onApplyTemplate(PermissionTemplate.minimal);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
