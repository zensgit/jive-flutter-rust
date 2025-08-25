import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_models.dart';
import '../providers/family_provider.dart';
import 'create_family_dialog.dart';

/// Family 切换器组件 - 支持切换和创建 Family
class FamilySwitcher extends ConsumerWidget {
  const FamilySwitcher({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    final currentFamily = familyState.currentFamily;
    final families = familyState.userFamilies ?? [];

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showFamilyMenu(context, ref, families),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Family 图标
              _buildFamilyIcon(familyState.currentRole),
              const SizedBox(width: 8),
              
              // Family 名称和角色
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentFamily?.name ?? 'Select Family',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (familyState.currentRole != null)
                    Text(
                      _getRoleDisplayName(familyState.currentRole!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getRoleColor(familyState.currentRole!),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              
              // 下拉箭头
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyIcon(FamilyRole? role) {
    IconData iconData;
    Color color;
    
    switch (role) {
      case FamilyRole.owner:
        iconData = Icons.star;
        color = Colors.amber;
        break;
      case FamilyRole.admin:
        iconData = Icons.admin_panel_settings;
        color = Colors.blue;
        break;
      case FamilyRole.member:
        iconData = Icons.group;
        color = Colors.green;
        break;
      case FamilyRole.viewer:
        iconData = Icons.visibility;
        color = Colors.grey;
        break;
      default:
        iconData = Icons.group_outlined;
        color = Colors.grey;
    }
    
    return Icon(iconData, size: 20, color: color);
  }

  void _showFamilyMenu(BuildContext context, WidgetRef ref, List<UserFamilyInfo> families) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _FamilyMenuSheet(families: families),
    );
  }

  String _getRoleDisplayName(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return 'Owner';
      case FamilyRole.admin:
        return 'Admin';
      case FamilyRole.member:
        return 'Member';
      case FamilyRole.viewer:
        return 'Viewer';
      default:
        return '';
    }
  }

  Color _getRoleColor(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return Colors.amber;
      case FamilyRole.admin:
        return Colors.blue;
      case FamilyRole.member:
        return Colors.green;
      case FamilyRole.viewer:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

/// Family 菜单底部弹出框
class _FamilyMenuSheet extends ConsumerWidget {
  final List<UserFamilyInfo> families;

  const _FamilyMenuSheet({
    Key? key,
    required this.families,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Your Families',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${families.length} ${families.length == 1 ? 'Family' : 'Families'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          
          // Family 列表
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: families.length,
              itemBuilder: (context, index) {
                final family = families[index];
                return _FamilyListTile(family: family);
              },
            ),
          ),
          
          const Divider(height: 24),
          
          // 创建新 Family 按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showCreateFamilyDialog(context, ref);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Family'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateFamilyDialog(),
    );
  }
}

/// Family 列表项
class _FamilyListTile extends ConsumerWidget {
  final UserFamilyInfo family;

  const _FamilyListTile({
    Key? key,
    required this.family,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: family.isCurrent 
          ? theme.colorScheme.primary 
          : theme.colorScheme.surfaceVariant,
        child: Icon(
          _getRoleIcon(family.role),
          color: family.isCurrent 
            ? theme.colorScheme.onPrimary 
            : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: [
          Text(family.family.name),
          if (family.isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Current',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          // 角色标签
          Chip(
            label: Text(
              _getRoleDisplayName(family.role),
              style: const TextStyle(fontSize: 11),
            ),
            backgroundColor: _getRoleColor(family.role).withOpacity(0.2),
            padding: const EdgeInsets.all(0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // 成员数量
          Icon(Icons.person, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            '${family.memberCount} ${family.memberCount == 1 ? 'member' : 'members'}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: family.isCurrent 
        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
        : null,
      onTap: family.isCurrent 
        ? null 
        : () async {
            Navigator.pop(context);
            await ref.read(familyProvider.notifier).switchFamily(family.family.id);
          },
      onLongPress: family.canDelete 
        ? () => _showDeleteConfirmation(context, ref, family)
        : null,
    );
  }

  IconData _getRoleIcon(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return Icons.star;
      case FamilyRole.admin:
        return Icons.admin_panel_settings;
      case FamilyRole.member:
        return Icons.group;
      case FamilyRole.viewer:
        return Icons.visibility;
      default:
        return Icons.group_outlined;
    }
  }

  String _getRoleDisplayName(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return 'Owner';
      case FamilyRole.admin:
        return 'Admin';
      case FamilyRole.member:
        return 'Member';
      case FamilyRole.viewer:
        return 'Viewer';
      default:
        return '';
    }
  }

  Color _getRoleColor(FamilyRole role) {
    switch (role) {
      case FamilyRole.owner:
        return Colors.amber;
      case FamilyRole.admin:
        return Colors.blue;
      case FamilyRole.member:
        return Colors.green;
      case FamilyRole.viewer:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, UserFamilyInfo family) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Family'),
        content: Text('Are you sure you want to delete "${family.family.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context); // Close the bottom sheet
              await ref.read(familyProvider.notifier).deleteFamily(family.family.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}