// 预算进度组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/models/budget.dart' as models;

class BudgetProgress extends StatelessWidget {
  final String category;
  final double budgeted;
  final double spent;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool showPercentage;
  final bool showAmount;

  const BudgetProgress({
    super.key,
    required this.category,
    required this.budgeted,
    required this.spent,
    this.icon,
    this.color,
    this.onTap,
    this.showPercentage = true,
    this.showAmount = true,
  });

  // Convenience: create from BudgetSummary model
  factory BudgetProgress.fromSummary(models.BudgetSummary summary, {Key? key, String? category}) {
    return BudgetProgress(
      key: key,
      category: category ?? summary.budgetName,
      budgeted: summary.budgeted,
      spent: summary.spent,
    );
  }

  double get progress =>
      budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.5) : 0.0;
  double get percentage => progress * 100;
  double get remaining => budgeted - spent;
  bool get isOverBudget => spent > budgeted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = _getProgressColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：分类名称和金额
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (color ?? progressColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: color ?? progressColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showAmount) ...[
                        const SizedBox(height: 2),
                        Text(
                          '¥${spent.toStringAsFixed(2)} / ¥${budgeted.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showPercentage)
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    Text(
                      isOverBudget
                          ? '超支 ${ref.read(currencyProvider.notifier).formatCurrency(-remaining, ref.read(baseCurrencyProvider).code)}'
                          : '剩余 ${ref.read(currencyProvider.notifier).formatCurrency(remaining, ref.read(baseCurrencyProvider).code)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverBudget
                            ? AppConstants.errorColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: progressColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),

            // 超支指示
            if (isOverBudget) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning,
                      size: 14,
                      color: AppConstants.errorColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已超出预算 ${(percentage - 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppConstants.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getProgressColor() {
    if (progress >= 1.0) {
      return AppConstants.errorColor;
    } else if (progress >= 0.8) {
      return AppConstants.warningColor;
    } else if (progress >= 0.6) {
      return Colors.orange;
    } else {
      return AppConstants.successColor;
    }
  }
}

/// 紧凑型预算进度条
class CompactBudgetProgress extends StatelessWidget {
  final String category;
  final double budgeted;
  final double spent;
  final VoidCallback? onTap;

  const CompactBudgetProgress({
    super.key,
    required this.category,
    required this.budgeted,
    required this.spent,
    this.onTap,
  });

  double get progress =>
      budgeted > 0 ? (spent / budgeted).clamp(0.0, 1.5) : 0.0;
  double get percentage => progress * 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = _getProgressColor();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                category,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: progressColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 45,
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor() {
    if (progress >= 1.0) {
      return AppConstants.errorColor;
    } else if (progress >= 0.8) {
      return AppConstants.warningColor;
    } else {
      return AppConstants.successColor;
    }
  }
}

/// 预算进度列表
class BudgetProgressList extends StatelessWidget {
  final List<BudgetData> budgets;
  final Function(BudgetData)? onBudgetTap;
  final bool compact;

  const BudgetProgressList({
    super.key,
    required this.budgets,
    this.onBudgetTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: budgets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final budget = budgets[index];

        if (compact) {
          return CompactBudgetProgress(
            category: budget.category,
            budgeted: budget.budgeted,
            spent: budget.spent,
            onTap: onBudgetTap != null ? () => onBudgetTap!(budget) : null,
          );
        }

        return BudgetProgress(
          category: budget.category,
          budgeted: budget.budgeted,
          spent: budget.spent,
          icon: budget.icon,
          color: budget.color,
          onTap: onBudgetTap != null ? () => onBudgetTap!(budget) : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            '暂无预算',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预算数据模型
class BudgetData {
  final String id;
  final String category;
  final double budgeted;
  final double spent;
  final IconData? icon;
  final Color? color;
  final DateTime? startDate;
  final DateTime? endDate;

  const BudgetData({
    required this.id,
    required this.category,
    required this.budgeted,
    required this.spent,
    this.icon,
    this.color,
    this.startDate,
    this.endDate,
  });

  double get progress => budgeted > 0 ? spent / budgeted : 0.0;
  double get remaining => budgeted - spent;
  bool get isOverBudget => spent > budgeted;
}
