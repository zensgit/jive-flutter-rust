import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jive_money/models/ledger.dart';
import 'package:jive_money/providers/ledger_provider.dart';
import 'package:jive_money/widgets/dialogs/create_family_dialog.dart';

/// 家庭切换器组件
class FamilySwitcher extends ConsumerWidget {
  const FamilySwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLedger = ref.watch(currentLedgerProvider);
    final allLedgersAsync = ref.watch(ledgersProvider);

    return allLedgersAsync.when(
      data: (ledgers) => _buildSwitcher(context, ref, currentLedger, ledgers),
      loading: () => _buildLoadingState(context, currentLedger),
      error: (error, _) => _buildErrorState(context, currentLedger),
    );
  }

  Widget _buildSwitcher(
    BuildContext context,
    WidgetRef ref,
    Ledger? currentLedger,
    List<Ledger> ledgers,
  ) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getLedgerIcon(currentLedger?.type ?? LedgerType.family),
              size: 20,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                currentLedger?.name ?? '选择家庭',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: theme.primaryColor,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        // 显示所有账本
        ...ledgers.map((ledger) {
          final isSelected = currentLedger?.id == ledger.id;
          final memberCount = ledger.memberIds?.length ?? 1;

          return PopupMenuItem<String>(
            value: ledger.id,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // 图标
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getLedgerIcon(ledger.type),
                      size: 20,
                      color: isSelected ? theme.primaryColor : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 名称和信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ledger.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (ledger.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '默认',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _getLedgerTypeLabel(ledger.type),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.people,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$memberCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ledger.currency,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 选中标记
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                ],
              ),
            ),
          );
        }),

        const PopupMenuDivider(),

        // 创建新家庭选项
        PopupMenuItem<String>(
          value: 'create_new',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建新家庭',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '成为Owner，拥有全部权限',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 管理家庭选项
        PopupMenuItem<String>(
          value: 'manage',
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                const Text('管理所有家庭'),
              ],
            ),
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'create_new') {
          // 显示创建对话框
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => const CreateFamilyDialog(),
          );
          if (result == true) {
            // 刷新列表
            ref.invalidate(ledgersProvider);
          }
        } else if (value == 'manage') {
          // 导航到家庭统计仪表板
          context.go('/family/dashboard');
        } else {
          // 切换到选中的账本
          final selectedLedger = ledgers.firstWhere((l) => l.id == value);
          await ref
              .read(currentLedgerProvider.notifier)
              .switchLedger(selectedLedger);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已切换到: ${selectedLedger.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildLoadingState(BuildContext context, Ledger? currentLedger) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(currentLedger?.name ?? '加载中...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Ledger? currentLedger) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Text(currentLedger?.name ?? '加载失败'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '复制错误',
            icon: const Icon(Icons.copy, size: 16, color: Colors.red),
            onPressed: () async {
              final text = currentLedger?.name ?? '加载失败';
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制')),
                );
              }
            },
          )
        ],
      ),
    );
  }

  IconData _getLedgerIcon(LedgerType type) {
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

  String _getLedgerTypeLabel(LedgerType type) {
    switch (type) {
      case LedgerType.personal:
        return '个人';
      case LedgerType.family:
        return '家庭';
      case LedgerType.business:
        return '商业';
      case LedgerType.project:
        return '项目';
      case LedgerType.travel:
        return '旅行';
      case LedgerType.investment:
        return '投资';
    }
  }
}
