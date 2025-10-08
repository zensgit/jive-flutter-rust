import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/travel_event.dart';
import '../../providers/travel_provider.dart';
import '../../utils/currency_formatter.dart';
import 'travel_edit_screen.dart';
import 'travel_detail_screen.dart';

class TravelListScreen extends ConsumerStatefulWidget {
  const TravelListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TravelListScreen> createState() => _TravelListScreenState();
}

class _TravelListScreenState extends ConsumerState<TravelListScreen> {
  List<TravelEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(travelServiceProvider);
      final events = await service.getEvents();

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TravelEditScreen(),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅行模式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAdd,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_events[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
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
          const Text('点击下方按钮创建你的第一个旅行'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAdd,
            icon: const Icon(Icons.add),
            label: const Text('创建旅行'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(TravelEvent event) {
    final dateFormat = DateFormat('MM月dd日');
    final theme = Theme.of(context);
    final currencyFormatter = CurrencyFormatter();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TravelDetailScreen(event: event),
            ),
          );

          if (result == true) {
            _loadEvents();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  _buildStatusChip(event.status),
                ],
              ),
              const SizedBox(height: 8),

              // Destination
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    event.destination,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Date and duration
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(event.startDate)} - ${dateFormat.format(event.endDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${event.endDate.difference(event.startDate).inDays + 1}天',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Budget progress (if budget exists)
              if (event.budget != null) ...[
                const SizedBox(height: 12),
                _buildBudgetProgress(event, currencyFormatter),
              ],

              // Transaction count
              if (event.transactionCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${event.transactionCount} 笔交易',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '总花费: ${currencyFormatter.format(event.totalSpent, event.currency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(TravelEventStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case TravelEventStatus.upcoming:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = '即将开始';
        break;
      case TravelEventStatus.ongoing:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = '进行中';
        break;
      case TravelEventStatus.completed:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = '已完成';
        break;
      case TravelEventStatus.cancelled:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = '已取消';
        break;
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

  Widget _buildBudgetProgress(TravelEvent event, CurrencyFormatter currencyFormatter) {
    if (event.budget == null || event.budget == 0) {
      return const SizedBox.shrink();
    }

    final percentage = (event.totalSpent / event.budget!) * 100;
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
              '预算: ${currencyFormatter.format(event.budget!, event.currency)}',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已花费: ${currencyFormatter.format(event.totalSpent, event.currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '剩余: ${currencyFormatter.format(event.budget! - event.totalSpent, event.currency)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: progressColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}