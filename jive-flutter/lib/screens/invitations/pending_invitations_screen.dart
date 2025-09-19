import 'package:flutter/material.dart';
import '../../utils/string_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invitation.dart';
import '../../models/family.dart';
import '../../services/api/family_service.dart';
import '../../providers/family_provider.dart' as family_provider;

/// 待处理邀请页面
class PendingInvitationsScreen extends ConsumerStatefulWidget {
  const PendingInvitationsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PendingInvitationsScreen> createState() =>
      _PendingInvitationsScreenState();
}

class _PendingInvitationsScreenState
    extends ConsumerState<PendingInvitationsScreen> {
  final _familyService = FamilyService();
  bool _isLoading = true;
  List<InvitationWithDetails> _invitations = [];
  String? _error;

  // 筛选和排序
  InvitationStatus? _filterStatus;
  String _sortBy = 'date'; // date, family, role

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: 调用实际的API
      // final invitations = await _familyService.getPendingInvitations();
      // 模拟数据
      final invitations = <InvitationWithDetails>[];

      setState(() {
        _invitations = invitations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvitation(InvitationWithDetails invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('接受邀请'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您确定要加入 "${invitation.family.name}" 吗？'),
            const SizedBox(height: 8),
            Text(
              '角色: ${_getRoleDisplayName(invitation.invitation.role)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('接受'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // TODO: 调用实际的API
      // await _familyService.acceptInvitation(invitation.invitation.id);

      // 刷新Family列表
      await ref.refresh(family_provider.userFamiliesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加入 ${invitation.family.name}'),
            backgroundColor: Colors.green,
          ),
        );

        // TODO: 切换到新Family
        // await _familyService.switchFamily(invitation.invitation.familyId);
        // await ref.refresh(family_provider.currentFamilyProvider);

        // 刷新邀请列表
        await _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('接受邀请失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineInvitation(InvitationWithDetails invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('拒绝邀请'),
        content: Text('您确定要拒绝来自 "${invitation.family.name}" 的邀请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('拒绝'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // TODO: 调用实际的API
      // await _familyService.declineInvitation(invitation.invitation.id);
      await _loadInvitations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已拒绝邀请'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<InvitationWithDetails> get _filteredInvitations {
    var filtered = _invitations;

    // 状态筛选
    if (_filterStatus != null) {
      filtered =
          filtered.where((i) => i.invitation.status == _filterStatus).toList();
    }

    // 排序
    switch (_sortBy) {
      case 'family':
        filtered.sort((a, b) => a.family.name.compareTo(b.family.name));
        break;
      case 'role':
        filtered.sort((a, b) =>
            b.invitation.role.level.compareTo(a.invitation.role.level));
        break;
      case 'date':
      default:
        filtered.sort(
            (a, b) => b.invitation.createdAt.compareTo(a.invitation.createdAt));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('待处理的邀请'),
        actions: [
          // 筛选按钮
          PopupMenuButton<InvitationStatus?>(
            icon: Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (status) {
              setState(() {
                _filterStatus = status;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              const PopupMenuDivider(),
              ...InvitationStatus.values.map((status) => PopupMenuItem(
                    value: status,
                    child: Text(status.label),
                  )),
            ],
          ),
          // 排序按钮
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'date',
                child: Text('按日期'),
              ),
              const PopupMenuItem(
                value: 'family',
                child: Text('按Family'),
              ),
              const PopupMenuItem(
                value: 'role',
                child: Text('按角色'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadInvitations,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    final invitations = _filteredInvitations;

    if (invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _filterStatus != null
                  ? '没有${_filterStatus!.label}的邀请'
                  : '暂无待处理的邀请',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_filterStatus != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = null;
                  });
                },
                child: Text('查看全部'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invitations.length,
        itemBuilder: (context, index) {
          final invitation = invitations[index];
          return _buildInvitationCard(invitation);
        },
      ),
    );
  }

  Widget _buildInvitationCard(InvitationWithDetails invitation) {
    final theme = Theme.of(context);
    final isExpired = invitation.invitation.isExpired;
    final canAccept = invitation.invitation.canAccept;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canAccept ? () => _showInvitationDetails(invitation) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部信息
              Row(
                children: [
                  // Family头像
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      StringUtils.safeInitial(invitation.family.name),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Family信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.family.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '邀请者: ${invitation.inviter.fullName}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // 状态标签
                  _buildStatusChip(invitation.invitation),
                ],
              ),
              const SizedBox(height: 12),

              // 角色信息
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(invitation.invitation.role)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '角色: ${_getRoleDisplayName(invitation.invitation.role)}',
                  style: TextStyle(
                    color: _getRoleColor(invitation.invitation.role),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 时间信息
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: isExpired ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    invitation.invitation.remainingTimeDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isExpired ? Colors.red : null,
                    ),
                  ),
                ],
              ),

              // 操作按钮
              if (canAccept) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _declineInvitation(invitation),
                      child: Text('拒绝'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _acceptInvitation(invitation),
                      child: Text('接受'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Invitation invitation) {
    Color color;
    IconData icon;

    switch (invitation.status) {
      case InvitationStatus.pending:
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case InvitationStatus.accepted:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case InvitationStatus.declined:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case InvitationStatus.expired:
        color = Colors.grey;
        icon = Icons.timer_off;
        break;
      case InvitationStatus.cancelled:
        color = Colors.grey;
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            invitation.status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showInvitationDetails(InvitationWithDetails invitation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // 拖动指示器
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Text(
                '邀请详情',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Family信息
              _buildDetailSection(
                '家庭信息',
                [
                  _buildDetailRow('名称', invitation.family.name),
                  _buildDetailRow('货币', invitation.family.currency),
                  _buildDetailRow('时区', invitation.family.timezone),
                ],
              ),
              const SizedBox(height: 16),

              // 邀请信息
              _buildDetailSection(
                '邀请信息',
                [
                  _buildDetailRow('邀请者', invitation.inviter.fullName),
                  _buildDetailRow('邀请邮箱', invitation.invitation.email),
                  _buildDetailRow(
                    '角色',
                    _getRoleDisplayName(invitation.invitation.role),
                  ),
                  _buildDetailRow(
                    '创建时间',
                    _formatDateTime(invitation.invitation.createdAt),
                  ),
                  _buildDetailRow(
                    '过期时间',
                    _formatDateTime(invitation.invitation.expiresAt),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 操作按钮
              if (invitation.invitation.canAccept) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _declineInvitation(invitation);
                        },
                        child: Text('拒绝'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _acceptInvitation(invitation);
                        },
                        child: Text('接受邀请'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return '所有者';
      case FamilyRole.admin:
        return '管理员';
      case FamilyRole.member:
        return '成员';
      case FamilyRole.viewer:
        return '查看者';
    }
  }

  Color _getRoleColor(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return const Color(0xFF6366F1);
      case FamilyRole.admin:
        return const Color(0xFF3B82F6);
      case FamilyRole.member:
        return const Color(0xFF10B981);
      case FamilyRole.viewer:
        return const Color(0xFF6B7280);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
