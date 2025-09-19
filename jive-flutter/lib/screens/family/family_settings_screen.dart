import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../models/ledger.dart';
import '../../models/family.dart' as family_model;
import '../../providers/ledger_provider.dart';
import '../../providers/family_provider.dart';
import '../../services/api/ledger_service.dart';
import '../../services/api/family_service.dart';
import '../../widgets/dialogs/delete_family_dialog.dart';
import 'family_members_screen.dart';
import '../invitations/invitation_management_screen.dart';
import '../../widgets/sheets/generate_invite_code_sheet.dart';

/// 家庭设置页面
class FamilySettingsScreen extends ConsumerStatefulWidget {
  final Ledger ledger;

  const FamilySettingsScreen({
    super.key,
    required this.ledger,
  });

  @override
  ConsumerState<FamilySettingsScreen> createState() =>
      _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends ConsumerState<FamilySettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late LedgerType _selectedType;
  // 货币字段已移除，但保留原值以兼容性
  late bool _isDefault;

  File? _avatarImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _hasChanges = false;
  LedgerStatistics? _statistics;
  FamilyStatistics? _familyStats;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ledger.name);
    _descriptionController =
        TextEditingController(text: widget.ledger.description);
    _selectedType = widget.ledger.type;
    // 货币字段已移除
    _isDefault = widget.ledger.isDefault;

    // 监听变化
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {
      _hasChanges = _nameController.text != widget.ledger.name ||
          _descriptionController.text != widget.ledger.description ||
          _selectedType != widget.ledger.type ||
          // 货币字段已移除
          _isDefault != widget.ledger.isDefault ||
          _avatarImage != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statisticsAsync =
        ref.watch(ledgerStatisticsProvider(widget.ledger.id!));
    final membersAsync = ref.watch(ledgerMembersProvider(widget.ledger.id!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭设置'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: const Text(
                '保存',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 家庭头像和基本信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.1),
                    theme.primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // 头像
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                        backgroundImage: _avatarImage != null
                            ? FileImage(_avatarImage!)
                            : null,
                        child: _avatarImage == null
                            ? const Icon(
                                _getTypeconst Icon(_selectedType),
                                size: 50,
                                color: theme.primaryColor,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.primaryColor,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 统计信息
                  statisticsAsync.when(
                    data: (stats) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('账户', stats.accountCount.toString()),
                        _buildStatItem('交易', stats.transactionCount.toString()),
                        membersAsync.when(
                          data: (members) =>
                              _buildStatItem('成员', members.length.toString()),
                          loading: () => _buildStatItem('成员', '...'),
                          error: (_, __) => _buildStatItem('成员', '0'),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),

            // 基本信息设置
            _buildSection(
              title: '基本信息',
              children: [
                // 名称
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '家庭名称',
                      prefixIcon: const Icon(Icons.home),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // 类型
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<LedgerType>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: '类型',
                      prefixIcon: const Icon(_getTypeconst Icon(_selectedType)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: LedgerType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            const Icon(_getTypeconst Icon(type), size: 20),
                            const SizedBox(width: 8),
                            const Text(type.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                ),

                // 货币选项已移除

                // 描述
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: '描述',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),

                // 设为默认
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SwitchListTile(
                    title: const Text('设为默认家庭'),
                    subtitle: const Text('登录后自动选择此家庭'),
                    value: _isDefault,
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value;
                        _hasChanges = true;
                      });
                    },
                  ),
                ),
              ],
            ),

            // 成员管理
            _buildSection(
              title: '成员管理',
              children: [
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('查看所有成员'),
                  subtitle: membersAsync.when(
                    data: (members) => const Text('共 ${members.length} 位成员'),
                    loading: () => const Text('加载中...'),
                    error: (_, __) => const Text('加载失败'),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FamilyMembersScreen(ledger: widget.ledger),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('邀请新成员'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _inviteMember,
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('管理邀请码'),
                  subtitle: const Text('查看和管理待处理的邀请'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _manageInvitations,
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: const Text('生成邀请码'),
                  subtitle: const Text('创建新的邀请链接或二维码'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _generateInviteCode,
                ),
              ],
            ),

            // 高级设置
            _buildSection(
              title: '高级设置',
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('导出数据'),
                  subtitle: const Text('导出此家庭的所有数据'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _exportData,
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('活动日志'),
                  subtitle: const Text('查看家庭活动记录'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _viewActivityLog,
                ),
                ListTile(
                  leading: const Icon(Icons.archive),
                  title: const Text('归档家庭'),
                  subtitle: const Text('暂时隐藏此家庭'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _archiveFamily,
                ),
              ],
            ),

            // 危险区域
            _buildSection(
              title: '危险区域',
              titleColor: Colors.red,
              children: [
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: const Text('退出家庭',
                      style: TextStyle(color: Colors.orange)),
                  subtitle: const Text('退出后需要重新邀请才能加入'),
                  onTap: _leaveFamily,
                ),
                if (widget.ledger.ownerId == ref.read(currentUserProvider)?.id)
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title:
                        const Text('删除家庭', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('此操作不可恢复，所有数据将被永久删除'),
                    onTap: _deleteFamily,
                  ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        const Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    Color? titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: const Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor ?? Colors.grey[700],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatarImage = File(image.path);
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() => _isLoading = true);

    try {
      final updatedLedger = widget.ledger.copyWith(
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim(),
        currency: widget.ledger.currency, // 保持原有货币值不变
        isDefault: _isDefault,
      );

      await ref
          .read(currentLedgerProvider.notifier)
          .updateLedger(updatedLedger);

      // TODO: 上传头像
      // if (_avatarImage != null) {
      //   await _uploadAvatar();
      // }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text('设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败: $e'),
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

  void _inviteMember() {
    // 导航到邀请页面
    showDialog(
      context: context,
      builder: (context) => InviteMemberDialog(ledger: widget.ledger),
    );
  }

  void _manageInvitations() {
    // 导航到邀请管理页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvitationManagementScreen(
          familyId: widget.ledger.id!,
          familyName: widget.ledger.name,
        ),
      ),
    );
  }

  void _generateInviteCode() {
    // 显示生成邀请码对话框
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GenerateInviteCodeSheet(
        familyId: widget.ledger.id!,
        familyName: widget.ledger.name,
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: const Text('导出功能开发中')),
    );
  }

  void _viewActivityLog() {
    // TODO: 导航到活动日志页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: const Text('活动日志功能开发中')),
    );
  }

  void _archiveFamily() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('归档家庭'),
        content: const Text('归档后，此家庭将从列表中隐藏，但数据不会丢失。您可以随时恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实现归档功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: const Text('归档功能开发中')),
              );
            },
            child: const Text('归档'),
          ),
        ],
      ),
    );
  }

  void _leaveFamily() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出家庭'),
        content: const Text('确定要退出"${widget.ledger.name}"吗？退出后需要重新邀请才能加入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: 实现退出功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: const Text('退出功能开发中')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFamily() async {
    if (_familyStats == null) {
      // 如果没有统计信息，先获取
      try {
        final familyService = FamilyService();
        final stats =
            await familyService.getFamilyStatistics(widget.ledger.id!);
        // 保存原始统计数据用于显示
        _familyStats = stats;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('获取统计信息失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // 创建Family对象用于删除对话框
    final family = family_model.Family(
      id: widget.ledger.id!,
      name: widget.ledger.name,
      createdAt: widget.ledger.createdAt ?? DateTime.now(),
      updatedAt: widget.ledger.updatedAt ?? DateTime.now(),
      settings: {
        'currency': widget.ledger.currency ?? 'CNY',
        'locale': 'zh_CN',
        'timezone': 'Asia/Shanghai',
        'start_of_week': 1,
      },
    );

    // 使用已经获取的familyStats或创建一个默认值
    final familyStats = _familyStats ??
        FamilyStatistics(
          memberCount: 1,
          ledgerCount: 0,
          accountCount: _statistics?.accountCount ?? 0,
          transactionCount: _statistics?.transactionCount ?? 0,
          totalBalance: {},
          lastActivity: DateTime.now(),
        );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteFamilyDialog(
        family: family,
        statistics: familyStats,
      ),
    );

    if (result == true && mounted) {
      // Family已删除，对话框会处理导航
    }
  }

  IconData _getTypeconst Icon(LedgerType type) {
    switch (type) {
      case LedgerType.personal:
        return Icons.person;
      case LedgerType.family:
        return Icons.family_restroom;
      case LedgerType.business:
        return Icons.business;
      case LedgerType.project:
        return Icons.work;
      case LedgerType.travel:
        return Icons.flight;
      case LedgerType.investment:
        return Icons.trending_up;
    }
  }
}

// 需要导入的包
class InviteMemberDialog extends StatelessWidget {
  final Ledger ledger;

  const InviteMemberDialog({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    // 使用之前创建的 InviteMemberDialog
    return Container();
  }
}

// 临时的 currentUserProvider
final currentUserProvider = Provider<User?>((ref) => null);

class User {
  final String id;
  const User({required this.id});
}
