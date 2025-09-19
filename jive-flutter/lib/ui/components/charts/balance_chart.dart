// 余额趋势图表组件
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/currency_provider.dart';

class BalanceChart extends ConsumerWidget {
  final List<BalancePoint> data;
  final String title;
  final Color? lineColor;
  final Color? gradientStartColor;
  final Color? gradientEndColor;
  final double height;
  final bool showGrid;
  final bool showTooltip;
  final Function(BalancePoint)? onPointTap;

  const BalanceChart({
    super.key,
    required this.data,
    this.title = '余额趋势',
    this.lineColor,
    this.gradientStartColor,
    this.gradientEndColor,
    this.height = 200,
    this.showGrid = true,
    this.showTooltip = true,
    this.onPointTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = lineColor ?? theme.primaryColor;

    if (data.isEmpty) {
      return _buildEmptyState(context);
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            const Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: showGrid,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _calculateBottomInterval(),
                      getTitlesWidget: _buildBottomTitle,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _calculateInterval(),
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) =>
                          _buildLeftTitle(context, ref, value, meta),
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: _getMinY(),
                maxY: _getMaxY(),
                lineBarsData: [
                  LineChartBarData(
                    spots: _buildSpots(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        gradientStartColor ?? primaryColor,
                        gradientEndColor ?? primaryColor.withValues(alpha: 0.3),
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: primaryColor,
                          strokeWidth: 2,
                          strokeColor: theme.scaffoldBackgroundColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (gradientStartColor ?? primaryColor).withValues(alpha: 0.3),
                          (gradientEndColor ?? primaryColor).withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: showTooltip,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: theme.cardColor,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      final base = ref.read(baseCurrencyProvider).code;
                      final formatter = ref.read(currencyProvider.notifier);
                      return spots.map((touchedSpot) {
                        const textStyle = TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        final index = touchedSpot.spotIndex;
                        if (index < data.length) {
                          final point = data[index];
                          final amountStr = formatter.formatCurrency(
                              point.amount, point.currencyCode ?? base);
                          return LineTooltipItem(
                            '${point.formattedDate}\n$amountStr',
                            textStyle,
                          );
                        }
                        return const LineTooltipItem('', TextStyle());
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response != null &&
                        response.lineBarSpots != null &&
                        onPointTap != null) {
                      final spotIndex = response.lineBarSpots!.first.spotIndex;
                      if (spotIndex < data.length) {
                        onPointTap!(data[spotIndex]);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.show_chart,
            size: 48,
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    final minAmount = data.map((e) => e.amount).reduce((a, b) => a < b ? a : b);
    return minAmount - (minAmount.abs() * 0.1);
  }

  double _getMaxY() {
    if (data.isEmpty) return 100;
    final maxAmount = data.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    return maxAmount + (maxAmount.abs() * 0.1);
  }

  double _calculateInterval() {
    final range = _getMaxY() - _getMinY();
    return range / 5; // 显示5条网格线
  }

  double _calculateBottomInterval() {
    return data.length > 7 ? (data.length / 7).ceilToDouble() : 1;
  }

  Widget _buildBottomTitle(double value, TitleMeta meta) {
    final index = value.toInt();
    if (index >= 0 && index < data.length) {
      final point = data[index];
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: const Text(
          point.formattedDate,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      );
    }
    return Container();
  }

  Widget _buildLeftTitle(
      BuildContext context, WidgetRef ref, double value, TitleMeta meta) {
    final base = ref.watch(baseCurrencyProvider).code;
    final formatted =
        ref.read(currencyProvider.notifier).formatCurrency(value, base);
    // Compact large values to keep axis tidy
    String label;
    final abs = value.abs();
    if (abs >= 100000000) {
      label = '${(value / 100000000).toStringAsFixed(1)}亿';
    } else if (abs >= 10000) {
      label = '${(value / 10000).toStringAsFixed(1)}万';
    } else if (abs >= 1000) {
      label = '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      label = formatted;
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: const Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  List<LineTooltipItem> _buildTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((LineBarSpot touchedSpot) {
      const textStyle = TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      );

      final index = touchedSpot.spotIndex;
      if (index < data.length) {
        final point = data[index];
        return LineTooltipItem(
          '${point.formattedDate}\n${point.tooltipAmount}',
          textStyle,
        );
      }

      return LineTooltipItem('', textStyle);
    }).toList();
  }
}

class BalancePoint {
  final DateTime date;
  final double amount;
  final String? label;
  final String? currencyCode; // display in base unless overridden

  const BalancePoint({
    required this.date,
    required this.amount,
    this.label,
    this.currencyCode,
  });

  String get formattedDate {
    if (label != null) return label!;

    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return '今天';
    } else if (difference == 1) {
      return '昨天';
    } else if (difference <= 7) {
      return '${difference}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  String get tooltipAmount {
    // We cannot access ref here; fallback to simple formatting with base symbol placement in UI
    // The actual formatted string will be constructed by BalanceChart using provider; keep placeholder here
    return amount.toStringAsFixed(2);
  }
}
