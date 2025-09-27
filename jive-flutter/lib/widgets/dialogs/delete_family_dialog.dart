import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/family.dart' as family_model;
import 'package:jive_money/services/api/family_service.dart';
import 'package:jive_money/providers/family_provider.dart';

class DeleteFamilyDialog extends ConsumerStatefulWidget {
  final family_model.Family family;
  final FamilyStatistics statistics;

  const DeleteFamilyDialog({
    super.key,
    required this.family,
    required this.statistics,
  });

  @override
  ConsumerState<DeleteFamilyDialog> createState() => _DeleteFamilyDialogState();
}

class _DeleteFamilyDialogState extends ConsumerState<DeleteFamilyDialog> {
  final _nameController = TextEditingController();
  bool _isNameValid = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateName);
  }

  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text == widget.family.name;
      _error = null;
    });
  }

  Future<void> _deleteFamily() async {
    if (!_isNameValid) return;

    // 二次确认
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 最终确认'),
        content: Text(
          '您确定要删除 "${widget.family.name}" 吗？\n'
          '此操作不可恢复！\n\n'
          '将删除：\n'
          '• ${widget.statistics.memberCount} 个成员\n'
          '• ${widget.statistics.accountCount} 个账户\n'
          '• ${widget.statistics.transactionCount} 条交易记录',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (secondConfirm != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      // Capture UI handles before async work
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final familyService = FamilyService();
      await familyService.deleteFamily(widget.family.id);

      // 刷新Family列表
      ref.refresh(userFamiliesProvider);

      if (mounted) {
        // 如果删除的是当前Family，切换到其他Family或显示空状态
        final currentFamily = ref.read(currentFamilyProvider);
        if (currentFamily?.id == widget.family.id) {
          final families = ref.read(userFamiliesProvider);
          if (families.isNotEmpty) {
            // 切换到第一个可用的Family
            await familyService.switchFamily(families.first.family.id);
            if (!context.mounted) return;
            ref.refresh(currentFamilyProvider);
          }
        }

        navigator.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text('已删除 "${widget.family.name}"'),
            backgroundColor: Colors.green,
          ),
        );

        // 导航到Family列表或Dashboard
        navigator.pushNamedAndRemoveUntil(
          '/dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Text('删除Family'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '此操作将永久删除 "${widget.family.name}" 及其所有数据。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // 数据统计
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '将被删除的数据：',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                      Icons.people, '成员', widget.statistics.memberCount),
                  _buildStatRow(Icons.account_balance_wallet, '账户',
                      widget.statistics.accountCount),
                  _buildStatRow(Icons.receipt_long, '交易',
                      widget.statistics.transactionCount),
                  _buildStatRow(
                      Icons.category, '分类', widget.statistics.ledgerCount),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 输入确认
            Text(
              '请输入Family名称以确认删除：',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: widget.family.name,
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: _isNameValid
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
              enabled: !_isDeleting,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isNameValid && !_isDeleting ? _deleteFamily : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('删除Family'),
        ),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
