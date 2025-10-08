import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/travel_event.dart';
import '../../models/transaction.dart';
import '../../providers/travel_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../screens/travel/travel_edit_screen.dart';
import '../../screens/travel/travel_transaction_link_screen.dart';
import '../../screens/travel/travel_budget_screen.dart';
import '../../screens/travel/travel_statistics_widget.dart';
import '../../ui/components/transactions/transaction_list.dart';
import '../../utils/currency_formatter.dart';

class TravelDetailScreen extends ConsumerStatefulWidget {
  final TravelEvent event;

  const TravelDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  ConsumerState<TravelDetailScreen> createState() => _TravelDetailScreenState();
}

class _TravelDetailScreenState extends ConsumerState<TravelDetailScreen> {
  late TravelEvent _event;
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load travel transactions
      final travelService = ref.read(travelServiceProvider);
      final transactions = await travelService.getTransactions(_event.id!);

      // Refresh event data
      final updatedEvent = await travelService.getEvent(_event.id!);

      if (mounted) {
        setState(() {
          _transactions = transactions;
          if (updatedEvent != null) {
            _event = updatedEvent;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    }
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelEditScreen(event: _event),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final theme = Theme.of(context);
    final currencyFormatter = CurrencyFormatter();

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: '预算管理',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TravelBudgetScreen(
                    travelEvent: _event,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Event Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '基本信息',
                                style: theme.textTheme.titleLarge,
                              ),
                              Chip(
                                label: Text(
                                  _getStatusLabel(_event.status ?? TravelEventStatus.upcoming),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: _getStatusColor(_event.status ?? TravelEventStatus.upcoming),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildInfoRow(Icons.location_on, '目的地', _event.destination ?? _event.location ?? '未知'),
                          if (_event.description != null)
                            _buildInfoRow(Icons.description, '描述', _event.description!),
                          _buildInfoRow(
                            Icons.date_range,
                            '日期',
                            '${dateFormat.format(_event.startDate)} - ${dateFormat.format(_event.endDate)}',
                          ),
                          _buildInfoRow(
                            Icons.calendar_today,
                            '天数',
                            '${_event.endDate.difference(_event.startDate).inDays + 1} 天',
                          ),
                          if (_event.notes != null)
                            _buildInfoRow(Icons.note, '备注', _event.notes!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Budget Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '预算与花费',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          if (_event.budget != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('预算'),
                                Text(
                                  currencyFormatter.format(_event.budget!, _event.currency),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('已花费'),
                              Text(
                                currencyFormatter.format(_event.totalSpent, _event.currency),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),

                          if (_event.budget != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('剩余'),
                                Text(
                                  currencyFormatter.format(
                                    _event.budget! - _event.totalSpent,
                                    _event.currency,
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: _event.budget! - _event.totalSpent >= 0
                                        ? Colors.green
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Budget Progress Bar
                            LinearProgressIndicator(
                              value: _event.budget! > 0
                                  ? (_event.totalSpent / _event.budget!).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _event.totalSpent > _event.budget!
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '已使用 ${((_event.totalSpent / _event.budget!) * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statistics Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '统计信息',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.receipt,
                                '交易数',
                                _event.transactionCount.toString(),
                              ),
                              if (_event.transactionCount > 0)
                                _buildStatItem(
                                  Icons.attach_money,
                                  '平均花费',
                                  currencyFormatter.format(
                                    _event.totalSpent / _event.transactionCount,
                                    _event.currency,
                                  ),
                                ),
                              _buildStatItem(
                                Icons.today,
                                '日均花费',
                                currencyFormatter.format(
                                  _event.totalSpent / (_event.endDate.difference(_event.startDate).inDays + 1),
                                  _event.currency,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Transactions Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '相关交易',
                                style: theme.textTheme.titleLarge,
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.link),
                                label: const Text('关联交易'),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TravelTransactionLinkScreen(
                                        travelEvent: _event,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadData(); // Reload data after linking transactions
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_transactions.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('暂无相关交易'),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _transactions[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: transaction.amount < 0
                                        ? Colors.red[100]
                                        : Colors.green[100],
                                    child: Icon(
                                      transaction.amount < 0
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: transaction.amount < 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                  title: Text(transaction.payee ?? '未知'),
                                  subtitle: Text(
                                    DateFormat('MM-dd HH:mm').format(transaction.date),
                                  ),
                                  trailing: Text(
                                    currencyFormatter.format(
                                      transaction.amount.abs(),
                                      _event.currency,
                                    ),
                                    style: TextStyle(
                                      color: transaction.amount < 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    // Navigate to transaction detail
                                    // TODO: Implement transaction detail navigation
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Statistics Section (only show if transactions exist)
                  if (_transactions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TravelStatisticsWidget(
                      travelEvent: _event,
                      transactions: _transactions,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return '即将开始';
      case TravelEventStatus.ongoing:
        return '进行中';
      case TravelEventStatus.completed:
        return '已完成';
      case TravelEventStatus.cancelled:
        return '已取消';
    }
  }

  Color _getStatusColor(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return Colors.blue[100]!;
      case TravelEventStatus.ongoing:
        return Colors.green[100]!;
      case TravelEventStatus.completed:
        return Colors.grey[300]!;
      case TravelEventStatus.cancelled:
        return Colors.red[100]!;
    }
  }
}