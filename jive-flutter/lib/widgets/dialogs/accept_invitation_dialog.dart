import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/invitation.dart';
import 'package:jive_money/models/family.dart' as family_model;
import 'package:jive_money/models/user.dart';
import 'package:jive_money/services/invitation_service.dart';
import 'package:jive_money/providers/family_provider.dart';
import 'package:jive_money/providers/auth_provider.dart';
import 'package:jive_money/utils/snackbar_utils.dart';

/// 接受邀请对话框
class AcceptInvitationDialog extends ConsumerStatefulWidget {
  final InvitationWithDetails invitationDetails;
  final VoidCallback? onAccepted;

  const AcceptInvitationDialog({
    super.key,
    required this.invitationDetails,
    this.onAccepted,
  });

  @override
  ConsumerState<AcceptInvitationDialog> createState() =>
      _AcceptInvitationDialogState();
}

class _AcceptInvitationDialogState
    extends ConsumerState<AcceptInvitationDialog> {
  final _invitationService = InvitationService();
  bool _isLoading = false;
  bool _showConfirmation = false;
  String? _userNote;

  Invitation get invitation => widget.invitationDetails.invitation;
  family_model.Family get family => widget.invitationDetails.family;
  User get inviter => widget.invitationDetails.inviter;

  Future<void> _acceptInvitation() async {
    if (!_showConfirmation) {
      setState(() {
        _showConfirmation = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      // 调用服务接受邀请
      final success = await _invitationService.acceptInvitation(
        invitationId: invitation.id,
        note: _userNote,
      );

      if (success && mounted) {
        // 刷新家庭列表
        await ref.read(familyControllerProvider.notifier).loadUserFamilies();
        if (!mounted) return;

        // 显示成功消息
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('已成功加入 ${family.name}')),
        );
        // 关闭对话框
        navigator.pop(true);

        // 触发回调
        widget.onAccepted?.call();
      }
    } catch (e) {
      if (mounted) {
        final messengerErr = ScaffoldMessenger.of(context);
        messengerErr.showSnackBar(
          SnackBar(
            content: Text('接受邀请失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_showConfirmation ? '确认加入' : '邀请详情'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 家庭信息卡片
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              family.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                family.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '智能记账，理财无忧',
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 统计信息
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          Icons.people_outline,
                          '1',
                          '成员',
                        ),
                        _buildStatItem(
                          context,
                          Icons.folder_outlined,
                          '0',
                          '分类',
                        ),
                        _buildStatItem(
                          context,
                          Icons.receipt_long_outlined,
                          '0',
                          '交易',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 邀请信息
            _buildInfoRow(
              context,
              Icons.person_outline,
              '邀请人',
              inviter.displayName,
            ),

            _buildInfoRow(
              context,
              Icons.shield_outlined,
              '您的角色',
              _getRoleDisplay(invitation.role),
            ),

            _buildInfoRow(
              context,
              Icons.access_time,
              '有效期',
              invitation.remainingTimeDescription,
            ),

            if (!_showConfirmation) ...[
              const SizedBox(height: 16),
              // 角色权限说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getRoleDisplay(invitation.role)}权限',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._getRolePermissions(invitation.role).map(
                      (permission) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                permission,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 确认阶段的附加信息
            if (_showConfirmation) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '加入后，您将可以访问该家庭的所有共享数据',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 备注输入
              TextField(
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加一条消息给邀请人',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                maxLines: 2,
                onChanged: (value) {
                  _userNote = value.isNotEmpty ? value : null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_showConfirmation) {
                    setState(() {
                      _showConfirmation = false;
                      _userNote = null;
                    });
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
          child: Text(_showConfirmation ? '返回' : '取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _acceptInvitation,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_showConfirmation ? '确认加入' : '接受邀请'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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

  List<String> _getRolePermissions(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return [
          '完全控制家庭设置',
          '管理所有成员和权限',
          '查看和编辑所有数据',
          '删除家庭',
        ];
      case family_model.FamilyRole.admin:
        return [
          '管理成员和邀请',
          '查看和编辑所有数据',
          '管理分类和标签',
          '导出数据',
        ];
      case family_model.FamilyRole.member:
        return [
          '查看和编辑交易',
          '创建和管理分类',
          '查看报表',
          '邀请新成员',
        ];
      case family_model.FamilyRole.viewer:
        return [
          '查看交易记录',
          '查看报表',
          '查看成员列表',
        ];
    }
  }
}
