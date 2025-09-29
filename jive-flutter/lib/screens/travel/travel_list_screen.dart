import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/travel_provider.dart';
import '../../models/travel_event.dart';
import 'travel_detail_screen.dart';
import 'travel_create_dialog.dart';

class TravelListScreen extends StatefulWidget {
  const TravelListScreen({Key? key}) : super(key: key);

  @override
  State<TravelListScreen> createState() => _TravelListScreenState();
}

class _TravelListScreenState extends State<TravelListScreen> {
  @override
  void initState() {
    super.initState();
    // 加载旅行列表
    Future.microtask(() {
      context.read<TravelProvider>().loadTravelEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅行模式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: Consumer<TravelProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.travelEvents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flight_takeoff,
                    size: 80,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有旅行计划',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('点击右上角创建你的第一个旅行'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('创建旅行'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadTravelEvents(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.travelEvents.length,
              itemBuilder: (context, index) {
                final travel = provider.travelEvents[index];
                return _TravelCard(
                  travel: travel,
                  onTap: () => _navigateToDetail(travel),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => const TravelCreateDialog(),
    ).then((result) {
      if (result == true) {
        // 刷新列表
        context.read<TravelProvider>().loadTravelEvents();
      }
    });
  }

  void _navigateToDetail(TravelEvent travel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelDetailScreen(travelId: travel.id),
      ),
    );
  }
}

class _TravelCard extends StatelessWidget {
  final TravelEvent travel;
  final VoidCallback onTap;

  const _TravelCard({
    Key? key,
    required this.travel,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      travel.tripName,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  _StatusChip(status: travel.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                    size: 16,
                    color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(travel.startDate)} - ${_formatDate(travel.endDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${travel.durationDays}天',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (travel.totalBudget != null) ...[
                const SizedBox(height: 12),
                _BudgetProgress(travel: travel),
              ],
              if (travel.transactionCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${travel.transactionCount} 笔交易',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      case 'cancelled':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = '已取消';
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
}

class _BudgetProgress extends StatelessWidget {
  final TravelEvent travel;

  const _BudgetProgress({
    Key? key,
    required this.travel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (travel.totalBudget == null || travel.totalBudget == 0) {
      return const SizedBox.shrink();
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
            Text(
              '预算: ${travel.budgetCurrencyCode ?? 'USD'} ${travel.totalBudget?.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 100).clamp(0, 1),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '已花费: ${travel.homeCurrencyCode} ${travel.totalSpent.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}