// 交易列表组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/ui/components/cards/transaction_card.dart';
import 'package:jive_money/ui/components/loading/loading_widget.dart';
import 'package:jive_money/models/transaction.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/providers/transaction_provider.dart';

// 类型别名以兼容现有代码
typedef TransactionData = Transaction;

class TransactionList extends ConsumerWidget {
  // Phase A: lightweight search/group controls
  final ValueChanged<String>? onSearch;
  final VoidCallback? onClearSearch;
  final VoidCallback? onToggleGroup;
  final List<TransactionData> transactions;
  final bool groupByDate;
  final bool showSearchBar;
  final String? emptyMessage;
  final VoidCallback? onRefresh;
  final Function(TransactionData)? onTransactionTap;
  final Function(TransactionData)? onTransactionLongPress;
  final ScrollController? scrollController;
  final bool isLoading;
  // Optional formatter for group header amounts (for testability)
  final String Function(double amount)? formatAmount;
  // Optional custom item builder for transactions (testability)
  final Widget Function(TransactionData t)? transactionItemBuilder;

  const TransactionList({
    super.key,
    required this.transactions,
    this.groupByDate = true,
    this.showSearchBar = false,
    this.emptyMessage,
    this.onRefresh,
    this.onTransactionTap,
    this.onTransactionLongPress,
    this.scrollController,
    this.isLoading = false,
    this.onSearch,
    this.onClearSearch,
    this.onToggleGroup,
    this.formatAmount,
    this.transactionItemBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (transactions.isEmpty) {
      return _buildEmptyState(context);
    }

    // Determine grouping mode from provider (Phase B1)
    final grouping = ref.watch(transactionControllerProvider).grouping;

    Widget listContent;
    if (grouping == TransactionGrouping.date) {
      listContent = groupByDate
          ? _buildGroupedListByDate(context, ref)
          : _buildSimpleList(context, ref);
    } else if (grouping == TransactionGrouping.category) {
      listContent = _buildGroupedListByCategory(context, ref);
    } else {
      listContent = _buildGroupedListByAccount(context, ref);
    }

    final content = Column(
      children: [
        if (showSearchBar) _buildSearchBar(context, grouping),
        Expanded(child: listContent),
      ],
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: content,
      );
    }

    return content;
  }

  // 顶部搜索/分组切换栏（Phase A）
  Widget _buildSearchBar(BuildContext context, TransactionGrouping grouping) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索 描述/备注/收款方…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: onClearSearch != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: grouping == TransactionGrouping.date
                ? (groupByDate ? '切换为平铺' : '按日期分组')
                : '仅日期模式可切换',
            onPressed: grouping == TransactionGrouping.date ? onToggleGroup : null,
            icon: Icon(
              grouping == TransactionGrouping.date
                  ? (groupByDate
                      ? Icons.view_agenda_outlined
                      : Icons.calendar_today_outlined)
                  : Icons.view_agenda_outlined,
            ),
          ),
          IconButton(
            tooltip: '筛选',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('筛选功能开发中')),
              );
            },
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
    );
  }





  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage ?? '暂无交易记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加您的第一笔交易开始记账',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildItem(BuildContext context, TransactionData t) {
    if (transactionItemBuilder != null) {
      return transactionItemBuilder!(t);
    }
    return TransactionCard(
      transaction: t,
      onTap: () => onTransactionTap?.call(t),
      onLongPress: () => onTransactionLongPress?.call(t),
      showDate: true,
    );
  }

Widget _buildSimpleList(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        return _buildItem(context, t);
      },
    );
  }

  Widget _buildGroupedList(BuildContext context, WidgetRef ref) {
    final grouped = _groupTransactionsByDate(transactions);
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final date = entry.key;
        final dayTxs = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _formatDateTL(date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...dayTxs.map((t) => transactionItemBuilder != null
                ? transactionItemBuilder!(t)
                : TransactionCard(
                    transaction: t,
                    onTap: () => onTransactionTap?.call(t),
                    onLongPress: () => onTransactionLongPress?.call(t),
                    showDate: false,
                  )),
          ],
        );
      },
    );
  }

  Map<DateTime, List<TransactionData>> _groupTransactionsByDate(
      List<TransactionData> list) {
    final Map<DateTime, List<TransactionData>> grouped = {};
    for (final t in list) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      (grouped[d] ??= []).add(t);
    }
    final entries = grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(entries);
  }

  String _formatDateTL(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return '今天';
    if (date == yesterday) return '昨天';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// 可滑动删除的交易列表

class SwipeableTransactionList extends StatelessWidget {
  final List<TransactionData> transactions;
  final Function(TransactionData) onDelete;
  final Function(TransactionData)? onEdit;
  final Function(TransactionData)? onTransactionTap;
  final bool groupByDate;

  const SwipeableTransactionList({
    super.key,
    required this.transactions,
    required this.onDelete,
    this.onEdit,
    this.onTransactionTap,
    this.groupByDate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _buildEmptyState(context);
    }

    return groupByDate ? _buildGroupedList(context) : _buildSimpleList(context);
  }

  Widget _buildEmptyState(BuildContext context) {
    return const TransactionList(
      transactions: [],
    );
  }

  Widget _buildSimpleList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildSwipeableItem(context, transaction);
      },
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final groupedTransactions = _groupTransactionsByDate();
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final group = groupedTransactions.entries.elementAt(index);
        final date = group.key;
        final dayTransactions = group.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _formatDate(date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // 该日期的交易
            ...dayTransactions.map(
              (transaction) => _buildSwipeableItem(context, transaction),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwipeableItem(
      BuildContext context, TransactionData transaction) {
    return Dismissible(
      key: ValueKey(transaction.id ?? "unknown"),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // 删除确认
          return await _showDeleteConfirmation(context);
        } else if (direction == DismissDirection.startToEnd && onEdit != null) {
          // 编辑
          onEdit!(transaction);
          return false;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete(transaction);
        }
      },
      background: Container(
        color: AppConstants.primaryColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.edit,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: AppConstants.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: TransactionCard(
        transaction: transaction,
        onTap: () => onTransactionTap?.call(transaction),
        showDate: !groupByDate,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这笔交易吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppConstants.errorColor,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Map<DateTime, List<TransactionData>> _groupTransactionsByDate() {
    final Map<DateTime, List<TransactionData>> grouped = {};

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(transaction);
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return '今天';
    } else if (date == yesterday) {
      return '昨天';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}


extension on TransactionList {
  // 按分类分组
  Widget _buildGroupedListByCategory(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<TransactionData>>{};
    for (final t in transactions) {
      final key = (t.category != null && t.category!.trim().isNotEmpty)
          ? t.category!.trim()
          : '未分类';
      (grouped[key] ??= <TransactionData>[]).add(t);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final theme = Theme.of(context);
    final collapsed = ref.watch(transactionControllerProvider).groupCollapse;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        final key = 'category:${e.key}';
        final isCollapsed = collapsed.contains(key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(context, ref, theme, e.key, e.value, key, isCollapsed),
            if (!isCollapsed)
              ...e.value.map(
                (t) => TransactionCard(
                  transaction: t,
                  onTap: () => onTransactionTap?.call(t),
                  onLongPress: () => onTransactionLongPress?.call(t),
                  showDate: true,
                ),
              ),
          ],
        );
      },
    );
  }

  // 按账户分组（使用账户ID占位）
  Widget _buildGroupedListByAccount(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<TransactionData>>{};
    for (final t in transactions) {
      final key = (t.accountId != null && t.accountId!.trim().isNotEmpty)
          ? t.accountId!.trim()
          : '未知账户';
      (grouped[key] ??= <TransactionData>[]).add(t);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final theme = Theme.of(context);
    final collapsed = ref.watch(transactionControllerProvider).groupCollapse;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        final key = 'account:${e.key}';
        final isCollapsed = collapsed.contains(key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(context, ref, theme, e.key, e.value, key, isCollapsed),
            if (!isCollapsed)
              ...e.value.map(
                (t) => TransactionCard(
                  transaction: t,
                  onTap: () => onTransactionTap?.call(t),
                  onLongPress: () => onTransactionLongPress?.call(t),
                  showDate: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    String title,
    List<TransactionData> items,
    String collapseKey,
    bool isCollapsed,
  ) {
    final total = _calculateDayTotal(items);
    final isPositive = total >= 0;
    final base = ref.watch(baseCurrencyProvider).code;
    final formatted =
        ref.read(currencyProvider.notifier).formatCurrency(total.abs(), base);
    final sign = total >= 0 ? '+' : '-';
    return InkWell(
      onTap: () =>
          ref.read(transactionControllerProvider.notifier).toggleGroupCollapse(collapseKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${items.length} 笔交易',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign$formatted',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isPositive
                    ? AppConstants.successColor
                    : AppConstants.errorColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
          ],
        ),
      ),
    );
  }
}
