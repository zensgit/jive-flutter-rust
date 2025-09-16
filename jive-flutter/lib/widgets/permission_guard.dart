import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permission_service.dart';
import '../models/family.dart' as family_model;

/// 权限守卫组件 - 根据权限控制UI显示
class PermissionGuard extends ConsumerWidget {
  final String familyId;
  final PermissionAction? action;
  final family_model.FamilyRole? minimumRole;
  final Widget child;
  final Widget? fallback;
  final bool hideWhenDenied;
  
  const PermissionGuard({
    super.key,
    required this.familyId,
    this.action,
    this.minimumRole,
    required this.child,
    this.fallback,
    this.hideWhenDenied = true,
  }) : assert(
    action != null || minimumRole != null,
    'Either action or minimumRole must be provided',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionService = ref.watch(permissionServiceProvider);
    
    bool hasPermission = false;
    
    // 检查具体权限
    if (action != null) {
      hasPermission = permissionService.hasPermission(
        familyId: familyId,
        action: action!,
      );
    }
    
    // 检查最低角色要求
    if (minimumRole != null && !hasPermission) {
      final userRole = permissionService.getUserRole(familyId);
      if (userRole != null) {
        hasPermission = _checkRoleHierarchy(userRole, minimumRole!);
      }
    }
    
    if (hasPermission) {
      return child;
    } else if (fallback != null) {
      return fallback!;
    } else if (hideWhenDenied) {
      return const SizedBox.shrink();
    } else {
      return _buildDeniedWidget(context);
    }
  }
  
  bool _checkRoleHierarchy(
    family_model.FamilyRole userRole,
    family_model.FamilyRole requiredRole,
  ) {
    final hierarchy = {
      family_model.FamilyRole.owner: 4,
      family_model.FamilyRole.admin: 3,
      family_model.FamilyRole.member: 2,
      family_model.FamilyRole.viewer: 1,
    };
    
    return hierarchy[userRole]! >= hierarchy[requiredRole]!;
  }
  
  Widget _buildDeniedWidget(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '您没有权限访问此内容',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 权限按钮 - 根据权限控制按钮可用性
class PermissionButton extends ConsumerWidget {
  final String familyId;
  final PermissionAction action;
  final Widget child;
  final VoidCallback? onPressed;
  final bool showTooltipWhenDisabled;
  
  const PermissionButton({
    super.key,
    required this.familyId,
    required this.action,
    required this.child,
    this.onPressed,
    this.showTooltipWhenDisabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionService = ref.watch(permissionServiceProvider);
    
    final hasPermission = permissionService.hasPermission(
      familyId: familyId,
      action: action,
    );
    
    Widget button;
    
    if (child is ElevatedButton) {
      final elevatedButton = child as ElevatedButton;
      button = ElevatedButton(
        onPressed: hasPermission ? onPressed ?? elevatedButton.onPressed : null,
        style: elevatedButton.style,
        child: elevatedButton.child,
      );
    } else if (child is TextButton) {
      final textButton = child as TextButton;
      button = TextButton(
        onPressed: hasPermission ? onPressed ?? textButton.onPressed : null,
        style: textButton.style,
        child: textButton.child,
      );
    } else if (child is IconButton) {
      final iconButton = child as IconButton;
      button = IconButton(
        onPressed: hasPermission ? onPressed ?? iconButton.onPressed : null,
        icon: iconButton.icon,
        tooltip: iconButton.tooltip,
      );
    } else if (child is FilledButton) {
      final filledButton = child as FilledButton;
      button = FilledButton(
        onPressed: hasPermission ? onPressed ?? filledButton.onPressed : null,
        style: filledButton.style,
        child: filledButton.child,
      );
    } else {
      button = child;
    }
    
    if (!hasPermission && showTooltipWhenDisabled) {
      return Tooltip(
        message: '您没有权限执行此操作',
        child: button,
      );
    }
    
    return button;
  }
}

/// 角色徽章 - 显示用户角色
class RoleBadge extends StatelessWidget {
  final family_model.FamilyRole role;
  final bool showLabel;
  
  const RoleBadge({
    super.key,
    required this.role,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getRoleColor(role);
    final icon = _getRoleIcon(role);
    final label = _getRoleLabel(role);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
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
  
  IconData _getRoleIcon(family_model.FamilyRole role) {
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
  
  String _getRoleLabel(family_model.FamilyRole role) {
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

/// 权限提示组件 - 显示权限不足的提示
class PermissionHint extends StatelessWidget {
  final PermissionAction action;
  final String? customMessage;
  
  const PermissionHint({
    super.key,
    required this.action,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.warningContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.onWarningContainer.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onWarningContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              customMessage ?? _getDefaultMessage(action),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getDefaultMessage(PermissionAction action) {
    switch (action) {
      case PermissionAction.editFamily:
        return '只有管理员和拥有者可以编辑家庭信息';
      case PermissionAction.deleteFamily:
        return '只有拥有者可以删除家庭';
      case PermissionAction.inviteMembers:
        return '只有管理员和拥有者可以邀请新成员';
      case PermissionAction.removeMembers:
        return '只有管理员和拥有者可以移除成员';
      case PermissionAction.editMemberRoles:
        return '只有管理员和拥有者可以修改成员角色';
      case PermissionAction.deleteTransactions:
        return '只有管理员可以删除交易记录';
      case PermissionAction.exportTransactions:
        return '只有管理员和拥有者可以导出数据';
      case PermissionAction.viewAuditLogs:
        return '只有管理员和拥有者可以查看审计日志';
      default:
        return '您没有权限执行此操作';
    }
  }
}