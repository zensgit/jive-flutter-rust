// 交易列表组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/ui/components/cards/transaction_card.dart';
import 'package:jive_money/ui/components/loading/loading_widget.dart';
import 'package:jive_money/models/transaction.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 类型别名以兼容现有代码
typedef TransactionData = Transaction;

class TransactionList extends ConsumerWidget {
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

    final content = groupByDate
        ? _buildGroupedList(context, ref)
        : _buildSimpleList(context, ref);

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: content,
      );
    }

    return content;
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
