import 'package:flutter/material.dart';
import 'package:jive_money/utils/string_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/ledger.dart';
import 'package:jive_money/providers/ledger_provider.dart';
import 'package:jive_money/widgets/dialogs/invite_member_dialog.dart';

/// 家庭成员管理页面
class FamilyMembersScreen extends ConsumerStatefulWidget {
  final Ledger ledger;

  const FamilyMembersScreen({
    super.key,
    required this.ledger,
  });

  @override
  ConsumerState<FamilyMembersScreen> createState() =>
      _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  String _searchQuery = '';
  LedgerRole? _filterRole;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(ledgerMembersProvider(widget.ledger.id!));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('家庭成员'),
            Text(
              widget.ledger.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _inviteNewMember,
            tooltip: '邀请成员',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索和筛选栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 搜索框
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索成员...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 角色筛选
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<LedgerRole?>(
                    value: _filterRole,
                    hint: const Text('全部角色'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('全部角色'),
                      ),
                      ...LedgerRole.values.map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(_getRoleLabel(role)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _filterRole = value);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 成员列表
          Expanded(
            child: membersAsync.when(
              data: (members) {
                // 过滤成员
                final filteredMembers = members.where((LedgerMember member) {
                  if (_searchQuery.isNotEmpty) {
                    final searchLower = _searchQuery.toLowerCase();
                    if (!member.name.toLowerCase().contains(searchLower) &&
                        !member.email.toLowerCase().contains(searchLower)) {
                      return false;
                    }
                  }
                  if (_filterRole != null && member.role != _filterRole) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filteredMembers.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ledgerMembersProvider(widget.ledger.id!));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(
                            ledgerMembersProvider(widget.ledger.id!));
                      },
                      child: const Text('重试'),
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

  Widget _buildMemberCard(LedgerMember member) {
    final theme = Theme.of(context);
    final isOwner = member.role == LedgerRole.owner;
    final canEdit = widget.ledger.ownerId == member.userId || isOwner;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showMemberDetails(member),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              CircleAvatar(
                radius: 28,
                backgroundColor: _getRoleColor(member.role).withValues(alpha: 0.1),
                backgroundImage:
                    member.avatar != null ? NetworkImage(member.avatar!) : null,
                child: member.avatar == null
                    ? Text(
                        StringUtils.safeInitial(member.name),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(member.role),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // 成员信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 角色标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(member.role).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRoleLabel(member.role),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getRoleColor(member.role),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '加入于 ${_formatDate(member.joinedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (member.lastAccessedAt != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '最近访问 ${_formatRelativeTime(member.lastAccessedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 操作按钮
              if (!isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) => _handleMemberAction(value, member),
                  itemBuilder: (context) => [
                    if (canEdit) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('编辑权限'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove,
                                size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('移除成员', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 20),
                          SizedBox(width: 8),
                          Text('查看详情'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无成员',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角邀请新成员',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _inviteNewMember,
            icon: const Icon(Icons.person_add),
            label: const Text('邀请成员'),
          ),
        ],
      ),
    );
  }

  void _inviteNewMember() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => InviteMemberDialog(ledger: widget.ledger),
    );
    if (result == true) {
      ref.invalidate(ledgerMembersProvider(widget.ledger.id!));
    }
  }

  void _showMemberDetails(LedgerMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MemberDetailsSheet(member: member),
    );
  }

  void _handleMemberAction(String action, LedgerMember member) async {
    switch (action) {
      case 'edit':
        _editMemberPermissions(member);
        break;
      case 'remove':
        _confirmRemoveMember(member);
        break;
      case 'view':
        _showMemberDetails(member);
        break;
    }
  }

  void _editMemberPermissions(LedgerMember member) async {
    final result = await showDialog<LedgerRole>(
      context: context,
      builder: (context) => _EditPermissionsDialog(member: member),
    );
    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final service = ref.read(ledgerServiceProvider);
        await service.updateMemberPermissions(
          widget.ledger.id!,
          member.userId,
          _getRolePermissions(result),
        );
        ref.invalidate(ledgerMembersProvider(widget.ledger.id!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('权限更新成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新失败: $e'),
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

  void _confirmRemoveMember(LedgerMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移除成员'),
        content: Text('确定要将 ${member.name} 从家庭中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeMember(member);
            },
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(LedgerMember member) async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(ledgerServiceProvider);
      await service.unshareLedger(widget.ledger.id!, member.email);
      ref.invalidate(ledgerMembersProvider(widget.ledger.id!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('成员已移除'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移除失败: $e'),
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

  String _getRoleLabel(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return '所有者';
      case LedgerRole.admin:
        return '管理员';
      case LedgerRole.editor:
        return '编辑者';
      case LedgerRole.viewer:
        return '观察者';
    }
  }

  Color _getRoleColor(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return Colors.purple;
      case LedgerRole.admin:
        return Colors.blue;
      case LedgerRole.editor:
        return Colors.green;
      case LedgerRole.viewer:
        return Colors.grey;
    }
  }

  Map<String, bool> _getRolePermissions(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return {
          'view': true,
          'edit': true,
          'delete': true,
          'invite': true,
          'manage': true,
        };
      case LedgerRole.admin:
        return {
          'view': true,
          'edit': true,
          'delete': false,
          'invite': true,
          'manage': true,
        };
      case LedgerRole.editor:
        return {
          'view': true,
          'edit': true,
          'delete': false,
          'invite': false,
          'manage': false,
        };
      case LedgerRole.viewer:
        return {
          'view': true,
          'edit': false,
          'delete': false,
          'invite': false,
          'manage': false,
        };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}

/// 成员详情底部弹窗
class _MemberDetailsSheet extends StatelessWidget {
  final LedgerMember member;

  const _MemberDetailsSheet({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像和基本信息
          CircleAvatar(
            radius: 40,
            backgroundImage:
                member.avatar != null ? NetworkImage(member.avatar!) : null,
            child: member.avatar == null
                ? Text(
                    StringUtils.safeInitial(member.name),
                    style: const TextStyle(fontSize: 32),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            member.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            member.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // 详细信息
          _buildDetailRow(Icons.badge, '角色', _getRoleLabel(member.role)),
          _buildDetailRow(
              Icons.calendar_today, '加入时间', _formatDate(member.joinedAt)),
          if (member.lastAccessedAt != null)
            _buildDetailRow(Icons.access_time, '最近访问',
                _formatDateTime(member.lastAccessedAt!)),

          const SizedBox(height: 24),

          // 权限列表
          const Text(
            '权限列表',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildPermissionsList(member.permissions),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsList(Map<String, bool> permissions) {
    final permissionLabels = {
      'view': '查看账本',
      'edit': '编辑记录',
      'delete': '删除账本',
      'invite': '邀请成员',
      'manage': '管理设置',
    };

    return Column(
      children: permissions.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                entry.value ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: entry.value ? Colors.green : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text(
                permissionLabels[entry.key] ?? entry.key,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getRoleLabel(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return '所有者';
      case LedgerRole.admin:
        return '管理员';
      case LedgerRole.editor:
        return '编辑者';
      case LedgerRole.viewer:
        return '观察者';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 编辑权限对话框
class _EditPermissionsDialog extends StatefulWidget {
  final LedgerMember member;

  const _EditPermissionsDialog({required this.member});

  @override
  State<_EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<_EditPermissionsDialog> {
  late LedgerRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑权限'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('成员: ${widget.member.name}'),
          const SizedBox(height: 16),
          ...LedgerRole.values.where((r) => r != LedgerRole.owner).map((role) {
            return RadioListTile<LedgerRole>(
              title: Text(_getRoleLabel(role)),
              subtitle: Text(_getRoleDescription(role)),
              value: role,
              groupValue: _selectedRole,
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedRole),
          child: const Text('确定'),
        ),
      ],
    );
  }

  String _getRoleLabel(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return '所有者';
      case LedgerRole.admin:
        return '管理员';
      case LedgerRole.editor:
        return '编辑者';
      case LedgerRole.viewer:
        return '观察者';
    }
  }

  String _getRoleDescription(LedgerRole role) {
    switch (role) {
      case LedgerRole.owner:
        return '拥有全部权限';
      case LedgerRole.admin:
        return '可以管理成员和设置';
      case LedgerRole.editor:
        return '可以记账和编辑';
      case LedgerRole.viewer:
        return '只能查看';
    }
  }
}
