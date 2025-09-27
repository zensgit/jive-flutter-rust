// 仪表板概览组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/ui/components/charts/balance_chart.dart';
import 'package:jive_money/ui/components/dashboard/summary_card.dart';
import 'package:jive_money/ui/components/dashboard/quick_actions.dart';
import 'package:jive_money/ui/components/dashboard/recent_transactions.dart';
import 'package:jive_money/ui/components/cards/transaction_card.dart';

class DashboardOverview extends StatelessWidget {
  final DashboardData data;
  final VoidCallback? onRefresh;

  const DashboardOverview({
    super.key,
    required this.data,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh != null ? () async => onRefresh!() : () async {},
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 摘要卡片
            SummaryCardGrid(cards: data.summaryCards),

            const SizedBox(height: 20),

            // 余额趋势图表
            if (data.balanceData.isNotEmpty) _buildBalanceChart(context),

            const SizedBox(height: 20),

            // 快捷操作
            QuickActions(
              actions: data.quickActions,
              itemsPerRow: 4,
            ),

            const SizedBox(height: 20),

            // 最近交易
            RecentTransactions(
              transactions: data.recentTransactions,
              onViewAll: data.onViewAllTransactions,
            ),

            const SizedBox(height: 20),

            // 账户概览
            if (data.accounts.isNotEmpty) _buildAccountsOverview(context),

            const SizedBox(height: 20),

            // 预算概览
            if (data.budgets.isNotEmpty) _buildBudgetOverview(context),

            // 底部安全区域
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceChart(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '余额趋势',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BalanceChart(
                data: data.balanceData,
                showGrid: true,
                showTooltip: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('7天', true),
          _buildPeriodButton('30天', false),
          _buildPeriodButton('90天', false),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppConstants.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildAccountsOverview(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '账户概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: data.onViewAllAccounts,
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.accounts.take(3).map(
                  (account) => _buildAccountItem(context, account),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, AccountOverviewData account) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: account.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              account.icon,
              color: account.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  account.type,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Text(
            account.balance,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: account.isPositive
                      ? AppConstants.successColor
                      : AppConstants.errorColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetOverview(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '预算概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: data.onViewAllBudgets,
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.budgets.take(3).map(
                  (budget) => _buildBudgetItem(context, budget),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(BuildContext context, BudgetOverviewData budget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                budget.category,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                '${budget.spent} / ${budget.budget}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: budget.progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              budget.progress > 0.9
                  ? AppConstants.errorColor
                  : budget.progress > 0.7
                      ? AppConstants.warningColor
                      : AppConstants.successColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 仪表板数据模型
class DashboardData {
  final List<SummaryCardData> summaryCards;
  final List<BalanceDataPoint> balanceData;
  final List<QuickActionData> quickActions;
  final List<TransactionData> recentTransactions;
  final List<AccountOverviewData> accounts;
  final List<BudgetOverviewData> budgets;
  final VoidCallback? onViewAllTransactions;
  final VoidCallback? onViewAllAccounts;
  final VoidCallback? onViewAllBudgets;

  const DashboardData({
    required this.summaryCards,
    required this.balanceData,
    required this.quickActions,
    required this.recentTransactions,
    required this.accounts,
    required this.budgets,
    this.onViewAllTransactions,
    this.onViewAllAccounts,
    this.onViewAllBudgets,
  });
}

/// 账户概览数据
class AccountOverviewData {
  final String name;
  final String type;
  final String balance;
  final IconData icon;
  final Color color;
  final bool isPositive;

  const AccountOverviewData({
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
    this.isPositive = true,
  });
}

/// 预算概览数据
class BudgetOverviewData {
  final String category;
  final String budget;
  final String spent;
  final double progress;

  const BudgetOverviewData({
    required this.category,
    required this.budget,
    required this.spent,
    required this.progress,
  });
}
