import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jive_money/providers/travel_provider.dart';
import 'package:jive_money/models/travel_event.dart';
import 'package:jive_money/core/router/app_router.dart';

class TravelListScreen extends ConsumerStatefulWidget {
  const TravelListScreen({super.key});

  @override
  ConsumerState<TravelListScreen> createState() => _TravelListScreenState();
}

class _TravelListScreenState extends ConsumerState<TravelListScreen> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(travelEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('旅行记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.travelAdd),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) => _buildEventsList(events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(travelEventsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.travelAdd),
        icon: const Icon(Icons.flight_takeoff),
        label: const Text('新建旅行'),
      ),
    );
  }

  Widget _buildEventsList(List<TravelEvent> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.travel_explore,
              size: 96,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有旅行记录',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮创建你的第一个旅行',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    // Group events by status
    final activeEvents = events.where((e) => e.status == TravelEventStatus.active).toList();
    final upcomingEvents = events.where((e) => e.status == TravelEventStatus.upcoming).toList();
    final completedEvents = events.where((e) => e.status == TravelEventStatus.completed).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeEvents.isNotEmpty) ...[
          _buildSectionHeader('正在进行', Icons.flight, Colors.green),
          ...activeEvents.map((event) => _buildEventCard(event)),
          const SizedBox(height: 24),
        ],
        if (upcomingEvents.isNotEmpty) ...[
          _buildSectionHeader('即将开始', Icons.schedule, Colors.orange),
          ...upcomingEvents.map((event) => _buildEventCard(event)),
          const SizedBox(height: 24),
        ],
        if (completedEvents.isNotEmpty) ...[
          _buildSectionHeader('已完成', Icons.check_circle, Colors.grey),
          ...completedEvents.map((event) => _buildEventCard(event)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(TravelEvent event) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(event.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('${AppRoutes.travel}/${event.id}'),
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
                      event.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(event.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (event.budget != null) ...[
                    Icon(Icons.account_balance_wallet, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '预算: ${event.budget!.toStringAsFixed(0)} ${event.currency}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return Colors.orange;
      case TravelEventStatus.active:
        return Colors.green;
      case TravelEventStatus.completed:
        return Colors.grey;
      case TravelEventStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return '即将开始';
      case TravelEventStatus.active:
        return '进行中';
      case TravelEventStatus.completed:
        return '已完成';
      case TravelEventStatus.cancelled:
        return '已取消';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}