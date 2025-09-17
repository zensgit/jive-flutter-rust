import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/budget_provider.dart';

class BudgetSummary extends ConsumerWidget {
  const BudgetSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(currentMonthBudgetsProvider);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    final daysRemaining = daysInMonth - daysElapsed;
    final monthProgress = daysElapsed / daysInMonth;

    return budgets.when(
      data: (budgetList) {
        if (budgetList.isEmpty) {
          return _buildEmptyState(context);
        }

        // 计算总预算和总支出
        double totalBudget = 0;
        double totalSpent = 0;

        for (final budget in budgetList) {
          totalBudget += budget.amount ?? 0;
          totalSpent += budget.spent ?? 0;
        }

        final remaining = totalBudget - totalSpent;
        final spentPercentage =
            totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;

        return Column(
          children: [
            // 预算概览卡片
            _buildBudgetOverviewCard(
              context,
              totalBudget,
              totalSpent,
              remaining,
              spentPercentage,
              monthProgress,
              daysRemaining,
            ),
            const SizedBox(height: 16),

            // 分类预算列表（显示前3个）
            ...budgetList
                .take(3)
                .map((budget) => _buildCategoryBudgetItem(context, budget)),

            // 查看全部按钮
            if (budgetList.length > 3)
              TextButton(
                onPressed: () => context.go(AppRoutes.budgets),
                child: Text('查看全部 ${budgetList.length} 个预算'),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text('加载失败: $error'),
            TextButton(
              onPressed: () => ref.invalidate(currentMonthBudgetsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('${AppRoutes.budgets}/add'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              const Text(
                '设置您的第一个预算',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '控制支出，实现财务目标',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetOverviewCard(
    BuildContext context,
    double totalBudget,
    double totalSpent,
    double remaining,
    double spentPercentage,
    double monthProgress,
    int daysRemaining,
  ) {
    final isOverBudget = totalSpent > totalBudget;
    final warningLevel = _getWarningLevel(spentPercentage, monthProgress);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              warningLevel.color.withOpacity(0.1),
              warningLevel.color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月预算',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${totalBudget.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: spentPercentage.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(warningLevel.color),
                        strokeWidth: 8,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${(spentPercentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: warningLevel.color,
                          ),
                        ),
                        Text(
                          '已用',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 预算状态
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warningLevel.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    warningLevel.icon,
                    color: warningLevel.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningLevel.message,
                      style: TextStyle(
                        color: warningLevel.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 统计信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('已支出', totalSpent, Colors.orange),
                _buildStatItem('剩余', remaining.abs(),
                    isOverBudget ? Colors.red : Colors.green),
                _buildStatItem('剩余天数', daysRemaining.toDouble(), Colors.blue,
                    suffix: '天'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color,
      {String suffix = ''}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          suffix.isEmpty
              ? '¥${value.toStringAsFixed(2)}'
              : '${value.toInt()}$suffix',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgetItem(BuildContext context, dynamic budget) {
    final spent = budget.spent ?? 0.0;
    final amount = budget.amount ?? 0.0;
    final remaining = amount - spent;
    final progress = amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = spent > amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('${AppRoutes.budgets}/${budget.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          _getCategoryColor(budget.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(budget.category),
                      color: _getCategoryColor(budget.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.name ?? budget.category ?? '未分类',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '¥${spent.toStringAsFixed(2)} / ¥${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isOverBudget ? '超支' : '剩余',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                      Text(
                        '¥${remaining.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOverBudget ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget
                        ? Colors.red
                        : progress > 0.8
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _WarningLevel _getWarningLevel(double spentPercentage, double monthProgress) {
    if (spentPercentage >= 1.0) {
      return _WarningLevel(
        color: Colors.red,
        icon: Icons.warning,
        message: '预算已超支！请控制支出',
      );
    } else if (spentPercentage > monthProgress + 0.2) {
      return _WarningLevel(
        color: Colors.orange,
        icon: Icons.info,
        message: '支出速度过快，请注意控制',
      );
    } else if (spentPercentage > 0.8) {
      return _WarningLevel(
        color: Colors.amber,
        icon: Icons.info_outline,
        message: '预算即将用完',
      );
    } else {
      return _WarningLevel(
        color: Colors.green,
        icon: Icons.check_circle,
        message: '预算控制良好',
      );
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
      case '餐饮':
        return Icons.restaurant;
      case 'transport':
      case '交通':
        return Icons.directions_car;
      case 'shopping':
      case '购物':
        return Icons.shopping_bag;
      case 'entertainment':
      case '娱乐':
        return Icons.movie;
      case 'bills':
      case '账单':
        return Icons.receipt;
      case 'health':
      case '医疗':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
      case '餐饮':
        return Colors.orange;
      case 'transport':
      case '交通':
        return Colors.blue;
      case 'shopping':
      case '购物':
        return Colors.purple;
      case 'entertainment':
      case '娱乐':
        return Colors.pink;
      case 'bills':
      case '账单':
        return Colors.red;
      case 'health':
      case '医疗':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _WarningLevel {
  final Color color;
  final IconData icon;
  final String message;

  _WarningLevel({
    required this.color,
    required this.icon,
    required this.message,
  });
}
