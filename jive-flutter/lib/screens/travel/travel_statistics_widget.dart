import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/travel_event.dart';
import '../../models/transaction.dart';
import '../../utils/currency_formatter.dart';

class TravelStatisticsWidget extends StatelessWidget {
  final TravelEvent travelEvent;
  final List<Transaction> transactions;

  const TravelStatisticsWidget({
    Key? key,
    required this.travelEvent,
    required this.transactions,
  }) : super(key: key);

  // Calculate spending by category
  Map<String, double> _calculateCategorySpending() {
    final Map<String, double> categorySpending = {};

    for (var transaction in transactions) {
      final category = transaction.category ?? 'other';
      categorySpending[category] = (categorySpending[category] ?? 0) + transaction.amount.abs();
    }

    return categorySpending;
  }

  // Calculate daily spending
  Map<DateTime, double> _calculateDailySpending() {
    final Map<DateTime, double> dailySpending = {};

    for (var transaction in transactions) {
      final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      dailySpending[date] = (dailySpending[date] ?? 0) + transaction.amount.abs();
    }

    return dailySpending;
  }

  // Get category info
  Map<String, dynamic> _getCategoryInfo(String categoryId) {
    final categories = {
      'accommodation': {'name': '住宿', 'color': Colors.blue, 'icon': Icons.hotel},
      'transportation': {'name': '交通', 'color': Colors.green, 'icon': Icons.directions_car},
      'dining': {'name': '餐饮', 'color': Colors.orange, 'icon': Icons.restaurant},
      'attractions': {'name': '景点', 'color': Colors.purple, 'icon': Icons.attractions},
      'shopping': {'name': '购物', 'color': Colors.pink, 'icon': Icons.shopping_bag},
      'entertainment': {'name': '娱乐', 'color': Colors.red, 'icon': Icons.sports_esports},
      'other': {'name': '其他', 'color': Colors.grey, 'icon': Icons.more_horiz},
    };

    return categories[categoryId] ?? {'name': categoryId, 'color': Colors.grey, 'icon': Icons.category};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = CurrencyFormatter();
    final categorySpending = _calculateCategorySpending();
    final dailySpending = _calculateDailySpending();
    final totalSpent = transactions.fold<double>(
      0,
      (sum, t) => sum + t.amount.abs(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Spending Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分类支出',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Pie chart
                if (categorySpending.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: categorySpending.entries.map((entry) {
                          final percentage = (entry.value / totalSpent * 100);
                          final categoryInfo = _getCategoryInfo(entry.key);

                          return PieChartSectionData(
                            color: categoryInfo['color'] as Color,
                            value: entry.value,
                            title: '${percentage.toStringAsFixed(1)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Category legend
                ...categorySpending.entries.map((entry) {
                  final categoryInfo = _getCategoryInfo(entry.key);
                  final percentage = (entry.value / totalSpent * 100);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: categoryInfo['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          categoryInfo['icon'] as IconData,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(categoryInfo['name']),
                        ),
                        Text(
                          currencyFormatter.format(entry.value, travelEvent.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Daily Spending Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每日支出',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Line chart
                if (dailySpending.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final dates = dailySpending.keys.toList()..sort();
                                if (value.toInt() >= 0 && value.toInt() < dates.length) {
                                  final date = dates[value.toInt()];
                                  return Text(
                                    '${date.month}/${date.day}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const Text('');
                              },
                              interval: 1,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: () {
                              final dates = dailySpending.keys.toList()..sort();
                              return dates.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  dailySpending[entry.value]!,
                                );
                              }).toList();
                            }(),
                            isCurved: true,
                            color: theme.colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Summary statistics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.calendar_today,
                      '天数',
                      '${dailySpending.length}',
                      context,
                    ),
                    _buildStatItem(
                      Icons.attach_money,
                      '日均',
                      currencyFormatter.format(
                        dailySpending.isNotEmpty ? totalSpent / dailySpending.length : 0,
                        travelEvent.currency,
                      ),
                      context,
                    ),
                    _buildStatItem(
                      Icons.trending_up,
                      '最高',
                      currencyFormatter.format(
                        dailySpending.isNotEmpty
                            ? dailySpending.values.reduce((a, b) => a > b ? a : b)
                            : 0,
                        travelEvent.currency,
                      ),
                      context,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Top expenses
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最大支出',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                ...(transactions.toList()
                      ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs())))
                    .take(5)
                    .map((transaction) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Icon(
                              Icons.attach_money,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(transaction.payee ?? transaction.description),
                          subtitle: Text(
                            '${transaction.date.month}月${transaction.date.day}日',
                          ),
                          trailing: Text(
                            currencyFormatter.format(
                              transaction.amount.abs(),
                              travelEvent.currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}