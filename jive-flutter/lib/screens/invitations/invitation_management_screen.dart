import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invitation.dart';
import '../../models/family.dart' as family_model;
import '../../services/invitation_service.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/sheets/generate_invite_code_sheet.dart';

/// 邀请管理页面
class InvitationManagementScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const InvitationManagementScreen({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  @override
  ConsumerState<InvitationManagementScreen> createState() =>
      _InvitationManagementScreenState();
}

class _InvitationManagementScreenState
    extends ConsumerState<InvitationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _invitationService = InvitationService();

  List<Invitation> _pendingInvitations = [];
  List<Invitation> _expiredInvitations = [];
  List<Invitation> _acceptedInvitations = [];
  InvitationStatistics? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInvitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);

    try {
      final invitations = await _invitationService.getFamilyInvitations(
        widget.familyId,
      );

      final stats = await _invitationService.getFamilyInvitationStatistics(
        widget.familyId,
      );

      setState(() {
        _pendingInvitations = invitations
            .where((i) => i.status == InvitationStatus.pending && !i.isExpired)
            .toList();
        _expiredInvitations = invitations
            .where((i) => i.status == InvitationStatus.expired || i.isExpired)
            .toList();
        _acceptedInvitations = invitations
            .where((i) => i.status == InvitationStatus.accepted)
            .toList();
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, '加载邀请失败: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelInvitation(Invitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('取消邀请'),
        content: Text('确定要取消发送给 ${invitation.email} 的邀请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _invitationService.cancelInvitation(invitation.id);
        await _loadInvitations();
        if (mounted) {
          SnackbarUtils.showSuccess(context, '邀请已取消');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, '取消失败: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _resendInvitation(Invitation invitation) async {
    try {
      await _invitationService.resendInvitation(invitation.id);
      if (mounted) {
        SnackbarUtils.showSuccess(context, '邀请已重新发送');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, '发送失败: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('邀请管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: '待处理',
              icon: Badge(
                label: Text(_pendingInvitations.length.toString()),
                child: Icon(Icons.pending),
              ),
            ),
            Tab(
              text: '已接受',
              icon: Badge(
                label: Text(_acceptedInvitations.length.toString()),
                child: Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: '已过期',
              icon: Badge(
                label: Text(_expiredInvitations.length.toString()),
                child: Icon(Icons.schedule),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvitations,
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息卡片
          if (_statistics != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    '总发送',
                    _statistics!.totalSent.toString(),
                    Icons.send,
                  ),
                  _buildStatItem(
                    '接受率',
                    '${_statistics!.acceptanceRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                  _buildStatItem(
                    '活跃邀请',
                    _statistics!.activeInvitations.toString(),
                    Icons.hourglass_empty,
                  ),
                ],
              ),
            ),

          // Tab内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvitationList(
                        _pendingInvitations,
                        emptyMessage: '没有待处理的邀请',
                        showActions: true,
                      ),
                      _buildInvitationList(
                        _acceptedInvitations,
                        emptyMessage: '还没有人接受邀请',
                        showAcceptedInfo: true,
                      ),
                      _buildInvitationList(
                        _expiredInvitations,
                        emptyMessage: '没有过期的邀请',
                        showResend: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => GenerateInviteCodeSheet(
              familyId: widget.familyId,
              familyName: widget.familyName,
              onInvitationCreated: _loadInvitations,
            ),
          );
        },
        icon: Icon(Icons.add),
        label: Text('新建邀请'),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onPrimaryContainer,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationList(
    List<Invitation> invitations, {
    required String emptyMessage,
    bool showActions = false,
    bool showAcceptedInfo = false,
    bool showResend = false,
  }) {
    if (invitations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invitation = invitations[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _getStatusColor(invitation.status).withValues(alpha: 0.2),
              child: Icon(
                _getStatusIcon(invitation.status),
                color: _getStatusColor(invitation.status),
              ),
            ),
            title: Text(invitation.email),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '角色: ${_getRoleDisplay(invitation.role)}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (showAcceptedInfo && invitation.acceptedAt != null)
                  Text(
                    '接受时间: ${_formatDateTime(invitation.acceptedAt!)}',
                    style: const TextStyle(fontSize: 12),
                  )
                else if (!invitation.isExpired)
                  Text(
                    invitation.remainingTimeDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          invitation.hoursRemaining < 24 ? Colors.orange : null,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showActions) ...[
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () => _resendInvitation(invitation),
                    tooltip: '重新发送',
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel),
                    onPressed: () => _cancelInvitation(invitation),
                    tooltip: '取消邀请',
                  ),
                ] else if (showResend)
                  TextButton(
                    onPressed: () => _resendInvitation(invitation),
                    child: Text('重新邀请'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.pending:
        return Colors.orange;
      case InvitationStatus.accepted:
        return Colors.green;
      case InvitationStatus.declined:
        return Colors.red;
      case InvitationStatus.expired:
        return Colors.grey;
      case InvitationStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.pending:
        return Icons.hourglass_empty;
      case InvitationStatus.accepted:
        return Icons.check_circle;
      case InvitationStatus.declined:
        return Icons.cancel;
      case InvitationStatus.expired:
        return Icons.schedule;
      case InvitationStatus.cancelled:
        return Icons.block;
    }
  }

  String _getRoleDisplay(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return '拥有者';
      case family_model.FamilyRole.admin:
        return '管理员';
      case family_model.FamilyRole.member:
        return '成员';
      case family_model.FamilyRole.viewer:
        return '查看者';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
