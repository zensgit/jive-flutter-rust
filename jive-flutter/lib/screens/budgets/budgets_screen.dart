import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../providers/budget_provider.dart';
import '../../models/budget.dart';
import '../../providers/currency_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetState = ref.watch(budgetControllerProvider);
    final currentMonth = DateTime.now();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('预算管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '本月预算'),
              Tab(text: '年度预算'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectMonth(context),
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () => _navigateToAnalytics(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildMonthlyBudget(context, ref, budgetState),
            _buildYearlyBudget(context, ref, budgetState),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('${AppRoutes.budgets}/add'),
          icon: const Icon(Icons.add),
          label: const Text('新增预算'),
        ),
      ),
    );
  }

  Widget _buildMonthlyBudget(
      BuildContext context, WidgetRef ref, BudgetState budgetState) {
    if (budgetState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (budgetState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('加载失败: ${budgetState.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(budgetControllerProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (budgetState.budgets.isEmpty) {
      return _buildEmptyState(context);
    }

    final budgetList = budgetState.budgets;
    final totalBudget = budgetState.totalBudgeted;
    final totalSpent = budgetState.totalSpent;
    final remaining = budgetState.totalRemaining;
    final progress = totalBudget > 0 ? totalSpent / totalBudget : 0.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(budgetControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览卡片
          Card(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.7),
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
                      const Text(
                        '本月预算总览',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        '${DateTime.now().month}月',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '剩余预算',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            ref.read(currencyProvider.notifier).formatCurrency(
                                remaining, ref.read(baseCurrencyProvider).code),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress > 0.8 ? Colors.orange : Colors.white,
                        ),
                        strokeWidth: 6,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Consumer(
                          builder: (context, ref, _) => _buildBudgetInfo(
                              '预算', totalBudget, Colors.white, ref)),
                      Consumer(
                          builder: (context, ref, _) => _buildBudgetInfo(
                              '已用', totalSpent, Colors.white70, ref)),
                      _buildBudgetInfo('剩余天数', DateTime.now().day.toDouble(),
                          Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 分类预算列表
          const Text(
            '分类预算',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...budgetList.map((budget) => _buildBudgetItem(context, budget)),
        ],
      ),
    );
  }

  Widget _buildYearlyBudget(
      BuildContext context, WidgetRef ref, BudgetState budgetState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_view_month,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            '年度预算',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '查看和管理年度预算计划',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: 创建年度预算
            },
            icon: const Icon(Icons.add),
            label: const Text('创建年度预算'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.pie_chart_outline,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            '还没有预算',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '创建预算来控制您的支出',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('${AppRoutes.budgets}/add'),
            icon: const Icon(Icons.add),
            label: const Text('创建预算'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetInfo(String label, double value, Color color,
      [WidgetRef? ref]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          label == '剩余天数'
              ? '${value.toInt()}天'
              : ref != null
                  ? ref.read(currencyProvider.notifier).formatCurrency(
                      value, ref.read(baseCurrencyProvider).code)
                  : value.toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetItem(BuildContext context, Budget budget) {
    final spent = budget.spent;
    final amount = budget.amount;
    final progress = amount > 0 ? spent / amount : 0.0;
    final remaining = amount - spent;
    final isOverBudget = spent > amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('${AppRoutes.budgets}/${budget.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(budget.category)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          _getCategoryconst Icon(budget.category),
                          color: _getCategoryColor(budget.category),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            budget.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            budget.category,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        isOverBudget ? '超支' : '剩余',
                        style: TextStyle(
                          color: isOverBudget ? Colors.red : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                      Consumer(builder: (context, ref, _) {
                        final str = ref
                            .read(currencyProvider.notifier)
                            .formatCurrency(remaining.abs(),
                                ref.read(baseCurrencyProvider).code);
                        return const Text(
                          str,
                          style: TextStyle(
                            color: isOverBudget ? Colors.red : Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer(builder: (context, ref, _) {
                    final used = ref
                        .read(currencyProvider.notifier)
                        .formatCurrency(
                            spent, ref.read(baseCurrencyProvider).code);
                    return const Text(
                      '已用 ' + used,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  }),
                  Consumer(builder: (context, ref, _) {
                    final totalStr = ref
                        .read(currencyProvider.notifier)
                        .formatCurrency(
                            amount, ref.read(baseCurrencyProvider).code);
                    return const Text(
                      '预算 ' + totalStr,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryconst Icon(String? category) {
    switch (category) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'bills':
        return Icons.receipt;
      case 'health':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'food':
        return Colors.orange;
      case 'transport':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'entertainment':
        return Colors.pink;
      case 'bills':
        return Colors.red;
      case 'health':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _selectMonth(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
  }

  void _navigateToAnalytics(BuildContext context) {
    // TODO: 导航到预算分析页面
  }
}
