import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jive_money/providers/travel_provider.dart';
import 'package:jive_money/models/travel_event.dart';
import 'travel_budget_manager.dart';
import 'travel_transaction_picker.dart';

class TravelDetailScreen extends StatefulWidget {
  final String travelId;

  const TravelDetailScreen({
    Key? key,
    required this.travelId,
  }) : super(key: key);

  @override
  State<TravelDetailScreen> createState() => _TravelDetailScreenState();
}

class _TravelDetailScreenState extends State<TravelDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // 加载旅行详情
    Future.microtask(() {
      context.read<TravelProvider>().loadTravelDetail(widget.travelId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, child) {
        final travel = provider.currentTravel;

        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (travel == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('旅行信息未找到')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(travel.tripName),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, travel),
                itemBuilder: (context) => [
                  if (travel.canActivate)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('激活旅行'),
                    ),
                  if (travel.canComplete)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('完成旅行'),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('编辑'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除'),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '概览'),
                Tab(text: '预算'),
                Tab(text: '交易'),
                Tab(text: '统计'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(travel: travel),
              _BudgetTab(travel: travel),
              _TransactionsTab(travel: travel),
              _StatisticsTab(
                travel: travel,
                statistics: provider.statistics,
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleMenuAction(String action, TravelEvent travel) async {
    final provider = context.read<TravelProvider>();

    switch (action) {
      case 'activate':
        final confirmed = await _showConfirmDialog(
          '激活旅行',
          '确定要激活这个旅行吗？',
        );
        if (confirmed) {
          await provider.activateTravel(travel.id);
        }
        break;

      case 'complete':
        final confirmed = await _showConfirmDialog(
          '完成旅行',
          '确定要标记这个旅行为已完成吗？',
        );
        if (confirmed) {
          await provider.completeTravel(travel.id);
        }
        break;

      case 'edit':
        // TODO: 打开编辑对话框
        break;

      case 'delete':
        final confirmed = await _showConfirmDialog(
          '删除旅行',
          '确定要删除这个旅行吗？此操作不可恢复。',
        );
        if (confirmed) {
          final success = await provider.deleteTravelEvent(travel.id);
          if (success && mounted) {
            Navigator.pop(context);
          }
        }
        break;
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// 概览标签页
class _OverviewTab extends StatelessWidget {
  final TravelEvent travel;

  const _OverviewTab({Key? key, required this.travel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '旅行信息',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      _buildStatusChip(travel.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today,
                    '日期',
                    '${_formatDate(travel.startDate)} - ${_formatDate(travel.endDate)}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.timer,
                    '时长',
                    '${travel.durationDays}天',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 预算卡片
          if (travel.totalBudget != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '预算概览',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _BudgetOverview(travel: travel),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 快速操作
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '快速操作',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (travel.canActivate)
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('激活旅行'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TravelTransactionPicker(
                                travelId: travel.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.attach_money),
                        label: const Text('关联交易'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TravelBudgetManager(
                                travelId: travel.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.pie_chart),
                        label: const Text('管理预算'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'planning':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = '计划中';
        break;
      case 'active':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = '进行中';
        break;
      case 'completed':
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = '已完成';
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

// 预算概览组件
class _BudgetOverview extends StatelessWidget {
  final TravelEvent travel;

  const _BudgetOverview({Key? key, required this.travel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (travel.totalBudget == null) {
      return const Text('未设置预算');
    }

    final percentage = travel.budgetUsagePercent ?? 0;
    final isOverBudget = percentage > 100;
    final progressColor = isOverBudget
        ? Colors.red
        : (percentage > 80 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '总预算',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${travel.budgetCurrencyCode ?? travel.homeCurrencyCode} ${travel.totalBudget!.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '已花费',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${travel.homeCurrencyCode} ${travel.totalSpent.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: progressColor,
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0, 1),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '使用 ${percentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (travel.remainingBudget != null)
              Text(
                '剩余 ${travel.remainingBudget!.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

// 预算标签页
class _BudgetTab extends StatelessWidget {
  final TravelEvent travel;

  const _BudgetTab({Key? key, required this.travel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, child) {
        final budgets = provider.budgets;

        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.pie_chart_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text('还未设置分类预算'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TravelBudgetManager(
                          travelId: travel.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('设置预算'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: budgets.length,
          itemBuilder: (context, index) {
            final budget = budgets[index];
            return _BudgetCard(budget: budget);
          },
        );
      },
    );
  }
}

// 预算卡片
class _BudgetCard extends StatelessWidget {
  final TravelBudget budget;

  const _BudgetCard({Key? key, required this.budget}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = budget.usagePercent;
    final isOverBudget = budget.isOverBudget;
    final progressColor = isOverBudget
        ? Colors.red
        : (percentage > 80 ? Colors.orange : Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '分类ID: ${budget.categoryId}', // TODO: 显示分类名称
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (budget.shouldAlert)
                  Icon(
                    Icons.warning,
                    color: Colors.orange,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '预算: ${budget.budgetAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0, 1),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已花费: ${budget.spentAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '剩余: ${budget.remaining.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 交易标签页
class _TransactionsTab extends StatelessWidget {
  final TravelEvent travel;

  const _TransactionsTab({Key? key, required this.travel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (travel.transactionCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('还没有关联的交易'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TravelTransactionPicker(
                      travelId: travel.id,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('关联交易'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 ${travel.transactionCount} 笔交易',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TravelTransactionPicker(
                        travelId: travel.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('交易列表待实现'),
          ),
        ),
      ],
    );
  }
}

// 统计标签页
class _StatisticsTab extends StatelessWidget {
  final TravelEvent travel;
  final TravelStatistics? statistics;

  const _StatisticsTab({
    Key? key,
    required this.travel,
    this.statistics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (statistics == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总体统计
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总体统计',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('总花费', '${travel.homeCurrencyCode} ${statistics.totalSpent.toStringAsFixed(2)}'),
                  _buildStatRow('交易笔数', '${statistics.transactionCount}'),
                  _buildStatRow('日均花费', '${travel.homeCurrencyCode} ${statistics.dailyAverage.toStringAsFixed(2)}'),
                  if (statistics.budgetUsage != null)
                    _buildStatRow('预算使用', '${statistics.budgetUsage!.toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 分类统计
          if (statistics.byCategory.isNotEmpty) ...[
            Text(
              '分类统计',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...statistics.byCategory.map((category) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(category.categoryName),
                    subtitle: Text('${category.transactionCount} 笔交易'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${travel.homeCurrencyCode} ${category.amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '${category.percentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}