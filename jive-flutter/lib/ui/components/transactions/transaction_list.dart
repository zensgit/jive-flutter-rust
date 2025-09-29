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

    final grouping = ref.watch(transactionControllerProvider).grouping;
    final listContent = grouping == TransactionGrouping.date
        ? _buildGroupedList(context, ref)
        : (grouping == TransactionGrouping.category
            ? _buildGroupedByCategory(context, ref)
            : _buildGroupedByAccount(context, ref));

    final content = Column(
      children: [
        if (showSearchBar) _buildSearchBar(context),
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
  Widget _buildSearchBar(BuildContext context) {
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
            tooltip: groupByDate ? '切换为平铺' : '按日期分组',
            onPressed: onToggleGroup,
            icon: Icon(
              groupByDate
                  ? Icons.view_agenda_outlined
                  : Icons.calendar_today_outlined,
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

  Widget _buildSimpleList(BuildContext context, WidgetRef ref) {

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

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildItem(context, transaction);
      },
    );
  }

  Widget _buildGroupedList(BuildContext context, WidgetRef ref) {
    final groupedTransactions = _groupTransactionsByDate();
    final theme = Theme.of(context);

    return ListView.builder(
      controller: scrollController,
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
            _buildDateHeader(context, ref, theme, date, dayTransactions),

            // 该日期的交易
            ...dayTransactions.map(
              (transaction) => (transactionItemBuilder != null)
                  ? transactionItemBuilder!(transaction)
                  : TransactionCard(
                      transaction: transaction,
                      onTap: () => onTransactionTap?.call(transaction),
                      onLongPress: () => onTransactionLongPress?.call(transaction),
                      showDate: false,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(BuildContext context, WidgetRef ref, ThemeData theme,
      DateTime date, List<TransactionData> transactions) {
    final total = _calculateDayTotal(transactions);
    final isPositive = total >= 0;
    String formatted;
    if (formatAmount != null) {
      formatted = formatAmount!(total.abs());
    } else {
      final base = ref.watch(baseCurrencyProvider).code;
      formatted = ref.read(currencyProvider.notifier).formatCurrency(total.abs(), base);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 日期
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatWeekday(date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 当日总计
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transactions.length} 笔交易',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${total >= 0 ? '+' : '-'}$formatted',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPositive
                      ? AppConstants.successColor
                      : AppConstants.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  double _calculateDayTotal(List<TransactionData> transactions) {
    return transactions.fold(0.0, (sum, t) => sum + t.amount);
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

  String _formatWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }


  // ---- Category grouping ----
  Widget _buildGroupedByCategory(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = _groupTransactionsByCategory();
    final collapsed = ref.watch(transactionControllerProvider).groupCollapse;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        final title = entry.key ?? '未分类';
        final collapseKey = 'category:$title';
        final isCollapsed = collapsed.contains(collapseKey);
        final total = _calculateDayTotal(entry.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(
              ref,
              theme,
              title,
              total,
              isCollapsed,
              () => ref
                  .read(transactionControllerProvider.notifier)
                  .toggleGroupCollapse(collapseKey),
            ),
            if (!isCollapsed)
              ...entry.value.map(
                (t) => (transactionItemBuilder != null)
                  ? transactionItemBuilder!(t)
                  : TransactionCard(
                      transaction: t,
                      onTap: () => onTransactionTap?.call(t),
                      showDate: true,
                    ),
              ),
          ],
        );
      },
    );
  }

  // ---- Account grouping ----
  Widget _buildGroupedByAccount(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = _groupTransactionsByAccount();
    final collapsed = ref.watch(transactionControllerProvider).groupCollapse;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
        final accountId = entry.key ?? '';
        final collapseKey = 'account:$accountId';
        final isCollapsed = collapsed.contains(collapseKey);
        final title = accountId.isEmpty ? '账户 (未知)' : '账户 $accountId';
        final total = _calculateDayTotal(entry.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupHeader(
              ref,
              theme,
              title,
              total,
              isCollapsed,
              () => ref
                  .read(transactionControllerProvider.notifier)
                  .toggleGroupCollapse(collapseKey),
            ),
            if (!isCollapsed)
              ...entry.value.map(
                (t) => (transactionItemBuilder != null)
                  ? transactionItemBuilder!(t)
                  : TransactionCard(
                      transaction: t,
                      onTap: () => onTransactionTap?.call(t),
                      showDate: true,
                    ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGroupHeader(
    WidgetRef ref,
    ThemeData theme,
    String title,
    double total,
    bool collapsed,
    VoidCallback onToggle,
  ) {
    final isPositive = total >= 0;
    String formatted;
    if (formatAmount != null) {
      formatted = formatAmount!(total.abs());
    } else {
      final base = ref.watch(baseCurrencyProvider).code;
      formatted = ref.read(currencyProvider.notifier).formatCurrency(total.abs(), base);
    }
    return InkWell(
      onTap: onToggle,
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${isPositive ? '+' : '-'}$formatted',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isPositive ? AppConstants.successColor : AppConstants.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String?, List<TransactionData>> _groupTransactionsByCategory() {
    final Map<String?, List<TransactionData>> grouped = {};
    for (final t in transactions) {
      final key = t.category;
      (grouped[key] ??= []).add(t);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => (a.key ?? '').compareTo(b.key ?? ''));
    return Map.fromEntries(entries);
  }

  Map<String?, List<TransactionData>> _groupTransactionsByAccount() {
    final Map<String?, List<TransactionData>> grouped = {};
    for (final t in transactions) {
      final key = t.accountId;
      (grouped[key] ??= []).add(t);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => (a.key ?? '').compareTo(b.key ?? ''));
    return Map.fromEntries(entries);
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
      key: Key(transaction.id ?? ''),
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
