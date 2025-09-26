import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jive_money/providers/currency_provider.dart';

class TransactionListItem extends ConsumerWidget {
  final dynamic transaction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = transaction.amount ?? 0.0;
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final base = ref.watch(baseCurrencyProvider).code;
    final formatted = ref
        .read(currencyProvider.notifier)
        .formatCurrency(amount.abs(), transaction.currency ?? base);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIconColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(),
                  color: _getIconColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.description ?? '未命名交易',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (transaction.isPending == true)
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
                              '待确认',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          transaction.category ?? '未分类',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (transaction.account != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            transaction.account!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 金额和日期
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : isIncome ? '+' : ''}$formatted',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isExpense
                          ? Colors.red
                          : isIncome
                              ? Colors.green
                              : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.date),
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
      ),
    );
  }

  IconData _getIcon() {
    final category = transaction.category?.toLowerCase() ?? '';

    if (category.contains('餐') || category.contains('食')) {
      return Icons.restaurant;
    } else if (category.contains('交通') || category.contains('车')) {
      return Icons.directions_car;
    } else if (category.contains('购物') || category.contains('买')) {
      return Icons.shopping_bag;
    } else if (category.contains('娱乐') || category.contains('游')) {
      return Icons.movie;
    } else if (category.contains('工资') || category.contains('薪')) {
      return Icons.account_balance_wallet;
    } else if (category.contains('医') || category.contains('药')) {
      return Icons.medical_services;
    } else if (category.contains('教育') || category.contains('学')) {
      return Icons.school;
    } else if (category.contains('住') || category.contains('房')) {
      return Icons.home;
    } else if (transaction.type == 'transfer') {
      return Icons.swap_horiz;
    } else if (transaction.type == 'income') {
      return Icons.arrow_downward;
    } else if (transaction.type == 'expense') {
      return Icons.arrow_upward;
    } else {
      return Icons.attach_money;
    }
  }

  Color _getIconColor() {
    if (transaction.type == 'expense') {
      return Colors.red;
    } else if (transaction.type == 'income') {
      return Colors.green;
    } else if (transaction.type == 'transfer') {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';

    DateTime dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      dateTime = DateTime.parse(date);
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate =
        DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (transactionDate == today) {
      return '今天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (transactionDate == yesterday) {
      return '昨天 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (transactionDate.year == now.year) {
      return DateFormat('MM月dd日').format(dateTime);
    } else {
      return DateFormat('yyyy年MM月dd日').format(dateTime);
    }
  }
}
