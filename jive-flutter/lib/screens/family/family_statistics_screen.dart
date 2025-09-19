import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/family.dart' as family_model;
import '../../providers/family_provider.dart';
import '../../services/api/family_service.dart';
import 'package:intl/intl.dart';

/// 家庭统计信息页面
class FamilyStatisticsScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const FamilyStatisticsScreen({
    Key? key,
    required this.familyId,
    required this.familyName,
  }) : super(key: key);

  @override
  ConsumerState<FamilyStatisticsScreen> createState() =>
      _FamilyStatisticsScreenState();
}

class _FamilyStatisticsScreenState extends ConsumerState<FamilyStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'month';
  DateTime _selectedDate = DateTime.now();
  FamilyStatistics? _statistics;
  bool _isLoading = true;

  final _periodOptions = {
    'week': '本周',
    'month': '本月',
    'quarter': '本季度',
    'year': '本年',
    'all': '全部',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final service = FamilyService();
      final stats = await service.getFamilyStatistics(
        widget.familyId,
        period: _selectedPeriod,
        date: _selectedDate,
      );

      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('加载统计数据失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('统计分析'),
            const Text(
              widget.familyName,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          // 时间段选择
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadStatistics();
            },
            itemBuilder: (context) => _periodOptions.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: const Text(e.value),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 20),
                  const SizedBox(width: 4),
                  const Text(_periodOptions[_selectedPeriod]!),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '总览'),
            Tab(text: '趋势'),
            Tab(text: '分类'),
            Tab(text: '成员'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTrendsTab(),
                _buildCategoriesTab(),
                _buildMembersTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_statistics == null) return const SizedBox();

    final stats = _statistics!;
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: '¥');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 核心指标卡片
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '总收入',
                  value: formatter.format(stats.totalIncome),
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                  trend: stats.incomeTrend,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '总支出',
                  value: formatter.format(stats.totalExpense),
                  icon: Icons.arrow_upward,
                  color: Colors.red,
                  trend: stats.expenseTrend,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '净结余',
                  value: formatter.format(stats.netBalance),
                  icon: Icons.account_balance_wallet,
                  color: stats.netBalance >= 0 ? Colors.blue : Colors.orange,
                  trend: stats.balanceTrend,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '交易数',
                  value: '${stats.transactionCount}',
                  icon: Icons.receipt_long,
                  color: theme.primaryColor,
                  subtitle: '平均 ${stats.dailyAvgTransactions}/天',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 预算执行情况
          if (stats.budgets.isNotEmpty) ...[
            const Text('预算执行', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...stats.budgets
                .map((budget) => _BudgetProgressCard(budget: budget)),
          ],

          const SizedBox(height: 24),

          // 储蓄率
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('储蓄率', style: theme.textTheme.titleMedium),
                      const Text(
                        '${stats.savingsRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _getSavingsRateColor(stats.savingsRate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: stats.savingsRate / 100,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    color: _getSavingsRateColor(stats.savingsRate),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    _getSavingsRateMessage(stats.savingsRate),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    if (_statistics == null) return const SizedBox();

    final stats = _statistics!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 收支趋势图
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('收支趋势', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return const Text(
                                  '${(value / 1000).toStringAsFixed(0)}k',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < stats.dailyData.length) {
                                  return const Text(
                                    DateFormat('MM/dd')
                                        .format(stats.dailyData[index].date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // 收入线
                          LineChartBarData(
                            spots: stats.dailyData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.income,
                                    ))
                                .toList(),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                          ),
                          // 支出线
                          LineChartBarData(
                            spots: stats.dailyData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.expense,
                                    ))
                                .toList(),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 图例
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('收入', Colors.green),
                      const SizedBox(width: 24),
                      _buildLegendItem('支出', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 月度对比
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('月度对比', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: stats.monthlyData
                                .map((e) => e.total)
                                .reduce((a, b) => a > b ? a : b) *
                            1.2,
                        barGroups: stats.monthlyData
                            .asMap()
                            .entries
                            .map((e) => BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value.income,
                                      color: Colors.green,
                                      width: 15,
                                    ),
                                    BarChartRodData(
                                      toY: e.value.expense,
                                      color: Colors.red,
                                      width: 15,
                                    ),
                                  ],
                                ))
                            .toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < stats.monthlyData.length) {
                                  return const Text(
                                    stats.monthlyData[index].month,
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
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

  Widget _buildCategoriesTab() {
    if (_statistics == null) return const SizedBox();

    final stats = _statistics!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 支出分类饼图
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('支出分类', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sections: stats.categoryData
                            .where((c) => c.type == 'expense')
                            .map((c) => PieChartSectionData(
                                  value: c.amount,
                                  title: '${c.percentage.toStringAsFixed(1)}%',
                                  color: Color(int.parse(
                                      c.color.replaceFirst('#', '0xFF'))),
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ))
                            .toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 分类列表
                  ...stats.categoryData
                      .where((c) => c.type == 'expense')
                      .map((c) => _CategoryListItem(category: c)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 收入分类
          if (stats.categoryData.any((c) => c.type == 'income'))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('收入分类', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    ...stats.categoryData
                        .where((c) => c.type == 'income')
                        .map((c) => _CategoryListItem(category: c)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_statistics == null) return const SizedBox();

    final stats = _statistics!;
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: '¥');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 成员贡献度
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('成员贡献', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ...stats.memberData.map((member) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: const Text(
                                        member.name.substring(0, 1),
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          member.name,
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        const Text(
                                          '${member.transactionCount} 笔交易',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      formatter.format(member.totalAmount),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const Text(
                                      '${member.percentage.toStringAsFixed(1)}%',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: member.percentage / 100,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              minHeight: 4,
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 成员活跃度
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('活跃度排名', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ...stats.memberData.toList()
                    ..sort((a, b) => b.activityScore.compareTo(a.activityScore))
                        .asMap()
                        .entries
                        .map((e) => ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: _getRankColor(e.key),
                                child: const Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: const Text(e.value.name),
                              subtitle: const Text('活跃度: ${e.value.activityScore}'),
                              trailing:
                                  _getActivityBadge(e.value.activityScore),
                            )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        const Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getSavingsRateColor(double rate) {
    if (rate >= 30) return Colors.green;
    if (rate >= 20) return Colors.blue;
    if (rate >= 10) return Colors.orange;
    return Colors.red;
  }

  String _getSavingsRateMessage(double rate) {
    if (rate >= 30) return '非常好！保持良好的储蓄习惯';
    if (rate >= 20) return '不错！继续努力提高储蓄率';
    if (rate >= 10) return '还可以，建议适当增加储蓄';
    return '储蓄率偏低，建议控制支出';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  Widget _getActivityBadge(int score) {
    String label;
    Color color;

    if (score >= 90) {
      label = '极活跃';
      color = Colors.green;
    } else if (score >= 70) {
      label = '活跃';
      color = Colors.blue;
    } else if (score >= 50) {
      label = '一般';
      color = Colors.orange;
    } else {
      label = '不活跃';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: const Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                const Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trend != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: trend! >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '${trend! >= 0 ? '+' : ''}${trend!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: trend! >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              const Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 预算进度卡片
class _BudgetProgressCard extends StatelessWidget {
  final BudgetData budget;

  const _BudgetProgressCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: '¥');
    final percentage = (budget.spent / budget.amount * 100).clamp(0, 100);
    final isOverBudget = budget.spent > budget.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  budget.categoryName,
                  style: theme.textTheme.titleSmall,
                ),
                const Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color:
                        isOverBudget ? Colors.red : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color: isOverBudget ? Colors.red : Colors.blue,
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '已花费: ${formatter.format(budget.spent)}',
                  style: theme.textTheme.bodySmall,
                ),
                const Text(
                  '预算: ${formatter.format(budget.amount)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类列表项
class _CategoryListItem extends StatelessWidget {
  final CategoryStatData category;

  const _CategoryListItem({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: '¥');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: const Text(category.name),
          ),
          const Text(
            formatter.format(category.amount),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          const Text(
            '${category.percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 统计数据模型
class FamilyStatistics {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final int transactionCount;
  final double dailyAvgTransactions;
  final double incomeTrend;
  final double expenseTrend;
  final double balanceTrend;
  final double savingsRate;
  final List<BudgetData> budgets;
  final List<DailyData> dailyData;
  final List<MonthlyData> monthlyData;
  final List<CategoryStatData> categoryData;
  final List<MemberStatData> memberData;

  FamilyStatistics({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.transactionCount,
    required this.dailyAvgTransactions,
    required this.incomeTrend,
    required this.expenseTrend,
    required this.balanceTrend,
    required this.savingsRate,
    required this.budgets,
    required this.dailyData,
    required this.monthlyData,
    required this.categoryData,
    required this.memberData,
  });
}

class BudgetData {
  final String categoryName;
  final double amount;
  final double spent;

  BudgetData({
    required this.categoryName,
    required this.amount,
    required this.spent,
  });
}

class DailyData {
  final DateTime date;
  final double income;
  final double expense;

  DailyData({
    required this.date,
    required this.income,
    required this.expense,
  });
}

class MonthlyData {
  final String month;
  final double income;
  final double expense;
  final double total;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
    required this.total,
  });
}

class CategoryStatData {
  final String name;
  final String type;
  final double amount;
  final double percentage;
  final String color;

  CategoryStatData({
    required this.name,
    required this.type,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

class MemberStatData {
  final String name;
  final int transactionCount;
  final double totalAmount;
  final double percentage;
  final int activityScore;

  MemberStatData({
    required this.name,
    required this.transactionCount,
    required this.totalAmount,
    required this.percentage,
    required this.activityScore,
  });
}
