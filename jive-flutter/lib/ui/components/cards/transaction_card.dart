// 交易卡片组件
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/currency_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/transaction.dart';

class TransactionCard extends ConsumerWidget {
  // 支持Transaction对象的构造方法
  final Transaction? transaction;
  final bool? showDate;
  final bool? compact;
  final EdgeInsets? margin;
  final double? elevation;

  // 原有的构造参数
  final String? id;
  final String? title;
  final String? description;
  final double? amount;
  final DateTime? date;
  final String? category;
  final Color? categoryColor;
  final IconData? categoryIcon;
  final bool? isIncome;
  final String? payee;
  final List<String>? tags;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  // Transaction对象构造方法
  const TransactionCard({
    super.key,
    this.transaction,
    this.showDate = true,
    this.compact = false,
    this.margin,
    this.elevation,
    this.onTap,
    this.onLongPress,
  })  : id = null,
        title = null,
        description = null,
        amount = null,
        date = null,
        category = null,
        categoryColor = null,
        categoryIcon = null,
        isIncome = null,
        payee = null,
        tags = null;

  // 原有的构造方法
  const TransactionCard.legacy({
    super.key,
    required this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.categoryColor,
    this.categoryIcon,
    required this.isIncome,
    this.payee,
    this.tags,
    this.onTap,
    this.onLongPress,
  })  : transaction = null,
        showDate = true,
        compact = false,
        margin = null,
        elevation = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatter = ref.read(currencyProvider.notifier);

    // 从transaction对象或直接参数获取数据
    final cardTitle = transaction?.description ?? title ?? '';
    final cardDescription = transaction?.note ?? description;
    final cardAmount = transaction?.amount ?? amount ?? 0.0;
    final cardDate = transaction?.date ?? date ?? DateTime.now();
    final cardCategory = transaction?.category ?? category ?? '';
    final cardIsIncome =
        transaction?.type == TransactionType.income ?? (isIncome ?? false);
    final cardPayee = transaction?.payee ?? payee;
    final cardTags = transaction?.tags ?? tags;

    final cardMargin = margin ??
        (compact == true
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 4));
    final cardElevation = elevation ?? (compact == true ? 0 : 1);

    return Card(
      margin: cardMargin,
      elevation: cardElevation,
      shadowColor: theme.shadowColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 分类图标
              _buildCategoryIcon(theme),
              const SizedBox(width: 12),

              // 交易信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和时间
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cardTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('MM/dd HH:mm').format(cardDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // 分类和收款方
                    Row(
                      children: [
                        // 分类标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (transaction?.type.color ??
                                    categoryColor ??
                                    theme.primaryColor)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            cardCategory,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: transaction?.type.color ??
                                  categoryColor ??
                                  theme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        if (cardPayee != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $cardPayee',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),

                    // 描述
                    if (cardDescription != null &&
                        cardDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cardDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 标签
                    if (cardTags != null && cardTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: cardTags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 金额
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${cardIsIncome ? '+' : '-'}${formatter.formatCurrency(cardAmount.abs(), ref.read(baseCurrencyProvider).code)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cardIsIncome
                          ? AppConstants.successColor
                          : AppConstants.errorColor,
                    ),
                  ),
                  if (cardDate.day == DateTime.now().day) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '今天',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(ThemeData theme) {
    final iconColor =
        transaction?.type.color ?? categoryColor ?? theme.primaryColor;
    final iconData = transaction?.type.icon ?? categoryIcon ?? Icons.category;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }
}
