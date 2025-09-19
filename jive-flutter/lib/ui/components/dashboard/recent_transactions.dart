// 最近交易组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/transaction.dart';
import '../cards/transaction_card.dart';

class RecentTransactions extends StatelessWidget {
  final List<Transaction> transactions;
  final String title;
  final VoidCallback? onViewAll;
  final int maxItems;

  const RecentTransactions({
    super.key,
    required this.transactions,
    this.title = '最近交易',
    this.onViewAll,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTransactions = transactions.take(maxItems).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：标题和查看全部按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看全部',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 交易列表
          if (displayTransactions.isNotEmpty)
            ...displayTransactions.asMap().entries.map((entry) {
              final index = entry.key;
              final transaction = entry.value;

              return Column(
                children: [
                  if (index > 0) const Divider(height: 1),
                  TransactionCard(
                    transaction: transaction,
                    showDate: true,
                    compact: true,
                    margin: EdgeInsets.zero,
                    elevation: 0,
                  ),
                ],
              );
            }),

          // 空状态
          if (displayTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无交易记录',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 按日期分组的最近交易
class GroupedRecentTransactions extends StatelessWidget {
  final List<Transaction> transactions;
  final String title;
  final VoidCallback? onViewAll;
  final int maxDays;

  const GroupedRecentTransactions({
    super.key,
    required this.transactions,
    this.title = '最近交易',
    this.onViewAll,
    this.maxDays = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedTransactions = _groupTransactionsByDate();
    final displayGroups = groupedTransactions.entries.take(maxDays).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: Text('查看全部'),
                  ),
              ],
            ),
          ),

          // 按日期分组的交易
          if (displayGroups.isNotEmpty)
            ...displayGroups.map(
              (group) => _buildDateGroup(theme, group.key, group.value),
            ),

          // 空状态
          if (displayGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无交易记录',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(
      ThemeData theme, DateTime date, List<Transaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期头部
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                _formatDate(date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),

        // 该日期的交易
        ...transactions.map(
          (transaction) => TransactionCard(
            transaction: transaction,
            showDate: false,
            compact: true,
            margin: EdgeInsets.zero,
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate() {
    final Map<DateTime, List<Transaction>> grouped = {};

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
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}
