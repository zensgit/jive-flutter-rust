import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invitation.dart';
import '../../models/family.dart' as family_model;
import '../../services/invitation_service.dart';
import '../../utils/snackbar_utils.dart';

/// 生成邀请码底部弹窗
class GenerateInviteCodeSheet extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;
  final VoidCallback? onInvitationCreated;

  const GenerateInviteCodeSheet({
    super.key,
    required this.familyId,
    required this.familyName,
    this.onInvitationCreated,
  });

  @override
  ConsumerState<GenerateInviteCodeSheet> createState() =>
      _GenerateInviteCodeSheetState();
}

class _GenerateInviteCodeSheetState
    extends ConsumerState<GenerateInviteCodeSheet> {
  final _invitationService = InvitationService();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  family_model.FamilyRole _selectedRole = family_model.FamilyRole.member;
  int _expirationDays = 7;
  bool _isLoading = false;
  bool _showAdvancedOptions = false;

  // 生成的邀请信息
  Invitation? _generatedInvitation;
  String? _inviteLink;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _generateInvitation() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      SnackbarUtils.showError(context, '请输入邮箱地址');
      return;
    }

    if (!_isValidEmail(email)) {
      SnackbarUtils.showError(context, '请输入有效的邮箱地址');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final invitation = await _invitationService.createInvitation(
        familyId: widget.familyId,
        email: email,
        role: _selectedRole,
        expiresInDays: _expirationDays,
      );

      setState(() {
        _generatedInvitation = invitation;
        _inviteLink = _generateInviteLink(invitation);
        _isLoading = false;
      });

      // 触发回调
      widget.onInvitationCreated?.call();

      if (mounted) {
        SnackbarUtils.showSuccess(context, '邀请已生成');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, '生成邀请失败: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  String _generateInviteLink(Invitation invitation) {
    // TODO: 使用实际的域名
    return 'https://jivemoney.app/invite/${invitation.token}';
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    SnackbarUtils.showSuccess(context, '已复制到剪贴板');
  }

  void _shareInvitation() {
    if (_inviteLink == null) return;

    // TODO: 实现分享功能
    SnackbarUtils.showInfo(context, '分享功能开发中');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '生成邀请码',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '邀请新成员加入 ${widget.familyName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 如果已生成邀请，显示结果
            if (_generatedInvitation != null && _inviteLink != null) ...[
              _buildInvitationResult(),
            ] else ...[
              // 邮箱输入
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '邮箱地址',
                  hintText: '输入被邀请人的邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // 角色选择
              DropdownButtonFormField<family_model.FamilyRole>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: '分配角色',
                  prefixIcon: Icon(Icons.shield_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: family_model.FamilyRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(
                          _getRoleconst Icon(role),
                          size: 20,
                          color: _getRoleColor(role),
                        ),
                        const SizedBox(width: 8),
                        Text(_getRoleDisplay(role)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              // 高级选项
              InkWell(
                onTap: () {
                  setState(() {
                    _showAdvancedOptions = !_showAdvancedOptions;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _showAdvancedOptions
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '高级选项',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (_showAdvancedOptions) ...[
                const SizedBox(height: 16),

                // 有效期选择
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '邀请有效期',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildExpirationOption(1, '1天'),
                        const SizedBox(width: 8),
                        _buildExpirationOption(3, '3天'),
                        const SizedBox(width: 8),
                        _buildExpirationOption(7, '7天'),
                        const SizedBox(width: 8),
                        _buildExpirationOption(30, '30天'),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 附加消息
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: '附加消息（可选）',
                    hintText: '给被邀请人的留言',
                    prefixIcon: Icon(Icons.message_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 24),

              // 生成按钮
              const SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generateInvitation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.send),
                  label: Text(_isLoading ? '生成中...' : '生成邀请'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationOption(int days, String label) {
    final isSelected = _expirationDays == days;
    final theme = Theme.of(context);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _expirationDays = days);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationResult() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 成功图标
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 邀请信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _generatedInvitation!.email,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '角色: ${_getRoleDisplay(_generatedInvitation!.role)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '有效期: ${_generatedInvitation!.remainingTimeDescription}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 邀请链接
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _inviteLink!,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () => _copyToClipboard(_inviteLink!),
                tooltip: '复制链接',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 操作按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _generatedInvitation = null;
                    _inviteLink = null;
                    _emailController.clear();
                    _messageController.clear();
                  });
                },
                icon: Icon(Icons.add),
                label: Text('新建邀请'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _shareInvitation,
                icon: Icon(Icons.share),
                label: Text('分享邀请'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getRoleconst Icon(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return Icons.star;
      case family_model.FamilyRole.admin:
        return Icons.admin_panel_settings;
      case family_model.FamilyRole.member:
        return Icons.person;
      case family_model.FamilyRole.viewer:
        return Icons.visibility;
    }
  }

  Color _getRoleColor(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return Colors.amber;
      case family_model.FamilyRole.admin:
        return Colors.blue;
      case family_model.FamilyRole.member:
        return Colors.green;
      case family_model.FamilyRole.viewer:
        return Colors.grey;
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
}
