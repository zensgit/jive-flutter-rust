// 预算图表组件
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import 'budget_progress.dart';

class BudgetPieChart extends StatefulWidget {
  final List<BudgetData> budgets;
  final String title;
  final bool showLegend;
  final bool showValues;
  final double? height;

  const BudgetPieChart({
    super.key,
    required this.budgets,
    this.title = '预算分配',
    this.showLegend = true,
    this.showValues = true,
    this.height = 300,
  });

  @override
  State<BudgetPieChart> createState() => _BudgetPieChartState();
}

class _BudgetPieChartState extends State<BudgetPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBudget = widget.budgets.fold<double>(
      0, 
      (sum, budget) => sum + budget.budgeted,
    );
    
    if (widget.budgets.isEmpty || totalBudget == 0) {
      return _buildEmptyState(theme);
    }

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // 饼图
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildSections(),
                    ),
                  ),
                ),
                
                // 图例
                if (widget.showLegend)
                  Expanded(
                    flex: 2,
                    child: _buildLegend(theme),
                  ),
              ],
            ),
          ),
          
          // 总计
          _buildTotal(theme, totalBudget),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final totalBudget = widget.budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.budgeted,
    );
    
    return widget.budgets.asMap().entries.map((entry) {
      final index = entry.key;
      final budget = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 14.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final percentage = (budget.budgeted / totalBudget * 100);
      
      return PieChartSectionData(
        color: budget.color ?? _getDefaultColor(index),
        value: budget.budgeted,
        title: widget.showValues 
            ? '${percentage.toStringAsFixed(0)}%'
            : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.budgets.asMap().entries.map((entry) {
          final index = entry.key;
          final budget = entry.value;
          final color = budget.color ?? _getDefaultColor(index);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    budget.category,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotal(ThemeData theme, double totalBudget) {
    final totalSpent = widget.budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.spent,
    );
    final percentage = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '总预算',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '¥${totalBudget.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '已使用',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '¥${totalSpent.toStringAsFixed(2)} (${percentage.toStringAsFixed(0)}%)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getPercentageColor(percentage / 100),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无预算数据',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDefaultColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 1.0) {
      return AppConstants.errorColor;
    } else if (percentage >= 0.8) {
      return AppConstants.warningColor;
    } else {
      return AppConstants.successColor;
    }
  }
}

/// 预算对比图表
class BudgetComparisonChart extends StatelessWidget {
  final List<BudgetData> budgets;
  final String title;
  final double? height;

  const BudgetComparisonChart({
    super.key,
    required this.budgets,
    this.title = '预算 vs 实际',
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (budgets.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          
          // 柱状图
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxY(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: theme.colorScheme.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final budget = budgets[groupIndex];
                      final value = rodIndex == 0 ? budget.budgeted : budget.spent;
                      final label = rodIndex == 0 ? '预算' : '实际';
                      return BarTooltipItem(
                        '$label\n¥${value.toStringAsFixed(2)}',
                        TextStyle(
                          color: rod.color,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= budgets.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            budgets[value.toInt()].category,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '¥${value.toInt()}',
                          style: theme.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarGroups(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
          
          // 图例
          _buildLegend(theme),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return budgets.asMap().entries.map((entry) {
      final index = entry.key;
      final budget = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: budget.budgeted,
            color: AppConstants.primaryColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: budget.spent,
            color: budget.spent > budget.budgeted 
                ? AppConstants.errorColor 
                : AppConstants.successColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildLegend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(theme, '预算', AppConstants.primaryColor),
          const SizedBox(width: 24),
          _buildLegendItem(theme, '实际支出', AppConstants.successColor),
          const SizedBox(width: 24),
          _buildLegendItem(theme, '超支', AppConstants.errorColor),
        ],
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无预算数据',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    double max = 0;
    for (final budget in budgets) {
      if (budget.budgeted > max) max = budget.budgeted;
      if (budget.spent > max) max = budget.spent;
    }
    return max * 1.2; // 添加20%的空间
  }

  double _calculateInterval() {
    final max = _calculateMaxY();
    if (max <= 1000) return 200;
    if (max <= 5000) return 1000;
    if (max <= 10000) return 2000;
    return 5000;
  }
}