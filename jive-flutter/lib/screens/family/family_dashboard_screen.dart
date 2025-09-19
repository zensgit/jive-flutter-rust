import 'package:flutter/material.dart';
import '../../utils/string_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/ledger.dart';
import '../../providers/ledger_provider.dart';
import '../../services/api/ledger_service.dart';
import 'family_settings_screen.dart';
import 'family_members_screen.dart';

/// 家庭统计仪表板
class FamilyDashboardScreen extends ConsumerStatefulWidget {
  final Ledger ledger;

  const FamilyDashboardScreen({
    super.key,
    required this.ledger,
  });

  @override
  ConsumerState<FamilyDashboardScreen> createState() =>
      _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends ConsumerState<FamilyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '本月';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statisticsAsync =
        ref.watch(ledgerStatisticsProvider(widget.ledger.id!));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('家庭概览'),
            const Text(
              widget.ledger.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '本周', child: const Text('本周')),
              const PopupMenuItem(value: '本月', child: const Text('本月')),
              const PopupMenuItem(value: '本季度', child: const Text('本季度')),
              const PopupMenuItem(value: '本年', child: const Text('本年')),
              const PopupMenuItem(value: '全部', child: const Text('全部')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FamilySettingsScreen(ledger: widget.ledger),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '总览'),
            Tab(text: '趋势'),
            Tab(text: '成员'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 总览标签
          _buildOverviewTab(statisticsAsync),
          // 趋势标签
          _buildTrendsTab(statisticsAsync),
          // 成员标签
          _buildMembersTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(AsyncValue<LedgerStatistics> statisticsAsync) {
    return statisticsAsync.when(
      data: (stats) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ledgerStatisticsProvider(widget.ledger.id!));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 净资产卡片
              _buildNetWorthCard(stats),
              const SizedBox(height: 16),

              // 资产负债对比
              Row(
                children: [
                  Expanded(
                    child: _buildFinanceCard(
                      title: '总资产',
                      amount: stats.totalAssets,
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFinanceCard(
                      title: '总负债',
                      amount: stats.totalLiabilities,
                      icon: Icons.credit_card,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 账户分布
              _buildAccountDistribution(stats),
              const SizedBox(height: 16),

              // 快速统计
              _buildQuickStats(stats),
              const SizedBox(height: 16),

              // 最近活动
              _buildRecentActivity(stats),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('加载失败: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(ledgerStatisticsProvider(widget.ledger.id!));
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(LedgerStatistics stats) {
    final netWorth = stats.netWorth;
    final isPositive = netWorth >= 0;

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isPositive
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '净资产',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '${widget.ledger.currency} ${_formatAmount(netWorth)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  isPositive ? '资产健康' : '需要关注',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                const Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              _formatAmount(amount),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDistribution(LedgerStatistics stats) {
    if (stats.accountTypeBreakdown.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '账户分布',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _createPieChartSections(stats.accountTypeBreakdown),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(stats.accountTypeBreakdown),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _createPieChartSections(
      Map<String, double> breakdown) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    int index = 0;
    return breakdown.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        value: entry.value,
        title: '${(entry.value).toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, double> breakdown) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: breakdown.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '${_getAccountTypeLabel(item.key)} ${item.value.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuickStats(LedgerStatistics stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速统计',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.account_balance,
                  label: '账户',
                  value: stats.accountCount.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.receipt_long,
                  label: '交易',
                  value: stats.transactionCount.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  icon: Icons.calendar_today,
                  label: '最近交易',
                  value: stats.lastTransactionDate != null
                      ? _formatRelativeDate(stats.lastTransactionDate!)
                      : '无',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        const Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(LedgerStatistics stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近活动',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 导航到活动日志
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // TODO: 实现活动列表
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: const Text(
                  '暂无最近活动',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab(AsyncValue<LedgerStatistics> statisticsAsync) {
    return statisticsAsync.when(
      data: (stats) {
        if (stats.monthlyTrend.isEmpty) {
          return const Center(
            child: const Text('暂无趋势数据'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 月度趋势图
              _buildMonthlyTrendChart(stats.monthlyTrend),
              const SizedBox(height: 16),

              // 收支对比
              _buildIncomeExpenseComparison(),
              const SizedBox(height: 16),

              // 类别趋势
              _buildCategoryTrends(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: const Text('加载失败: $error')),
    );
  }

  Widget _buildMonthlyTrendChart(Map<String, double> monthlyTrend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月度趋势',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final months = monthlyTrend.keys.toList();
                          if (value.toInt() < months.length) {
                            return const Text(
                              months[value.toInt()].substring(5),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthlyTrend.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '收支对比',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // TODO: 实现收支对比图表
            const Center(
              child: const Text('收支对比图表开发中'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '类别趋势',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // TODO: 实现类别趋势图表
            const Center(
              child: const Text('类别趋势图表开发中'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final membersAsync = ref.watch(ledgerMembersProvider(widget.ledger.id!));

    return membersAsync.when(
      data: (members) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: members.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('共 ${members.length} 位成员'),
                subtitle: const Text('点击查看详情'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FamilyMembersScreen(ledger: widget.ledger),
                    ),
                  );
                },
              ),
            );
          }

          final member = members[index - 1];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    member.avatar != null ? NetworkImage(member.avatar!) : null,
                child: member.avatar == null
                    ? const Text(StringUtils.safeInitial(member.name))
                    : null,
              ),
              title: const Text(member.name),
              subtitle: const Text(member.role.label),
              trailing: member.lastAccessedAt != null
                  ? const Text(
                      _formatRelativeDate(member.lastAccessedAt!),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: const Text('加载失败: $error')),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else {
      return '刚刚';
    }
  }

  String _getAccountTypeLabel(String type) {
    final labels = {
      'cash': '现金',
      'bank': '银行',
      'credit': '信用卡',
      'investment': '投资',
      'loan': '贷款',
      'other': '其他',
    };
    return labels[type] ?? type;
  }
}
