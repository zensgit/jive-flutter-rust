import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/travel_event.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/travel_provider.dart';
import '../../utils/currency_formatter.dart';

class TravelTransactionLinkScreen extends ConsumerStatefulWidget {
  final TravelEvent travelEvent;

  const TravelTransactionLinkScreen({
    Key? key,
    required this.travelEvent,
  }) : super(key: key);

  @override
  ConsumerState<TravelTransactionLinkScreen> createState() => _TravelTransactionLinkScreenState();
}

class _TravelTransactionLinkScreenState extends ConsumerState<TravelTransactionLinkScreen> {
  List<Transaction> _availableTransactions = [];
  List<Transaction> _linkedTransactions = [];
  Set<String> _selectedTransactionIds = {};
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.travelEvent.startDate.subtract(const Duration(days: 7)); // Include week before
    _endDate = widget.travelEvent.endDate.add(const Duration(days: 7)); // Include week after
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all transactions within the travel date range
      final transactionState = ref.read(transactionControllerProvider);
      final allTransactions = transactionState.transactions;

      // Filter transactions by date range
      final filteredTransactions = allTransactions.where((t) {
        return t.date.isAfter(_startDate!) && t.date.isBefore(_endDate!);
      }).toList();

      // Load already linked transactions
      final travelService = ref.read(travelServiceProvider);
      final linkedTransactions = await travelService.getTransactions(widget.travelEvent.id!);

      if (mounted) {
        setState(() {
          _availableTransactions = filteredTransactions;
          _linkedTransactions = linkedTransactions;
          _selectedTransactionIds = linkedTransactions.map((t) => t.id!).toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载交易失败: $e')),
        );
      }
    }
  }

  Future<void> _saveLinkages() async {
    try {
      final travelService = ref.read(travelServiceProvider);

      // Find newly selected transactions
      final newlySelected = _selectedTransactionIds.where((id) {
        return !_linkedTransactions.any((t) => t.id == id);
      }).toList();

      // Find unselected transactions to remove
      final toRemove = _linkedTransactions.where((t) {
        return !_selectedTransactionIds.contains(t.id);
      }).map((t) => t.id!).toList();

      // Link new transactions
      for (final transactionId in newlySelected) {
        await travelService.linkTransaction(widget.travelEvent.id!, transactionId);
      }

      // Unlink removed transactions
      for (final transactionId in toRemove) {
        await travelService.unlinkTransaction(widget.travelEvent.id!, transactionId);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM-dd');
    final currencyFormatter = CurrencyFormatter();

    return Scaffold(
      appBar: AppBar(
        title: Text('关联交易 - ${widget.travelEvent.name}'),
        actions: [
          if (_selectedTransactionIds.isNotEmpty)
            TextButton(
              onPressed: _saveLinkages,
              child: Text(
                '保存 (${_selectedTransactionIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date range filter
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: theme.colorScheme.surfaceVariant,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate!,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                              _loadTransactions();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '开始日期',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_startDate!)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _endDate!,
                              firstDate: _startDate!,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                              _loadTransactions();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '结束日期',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_endDate!)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '找到 ${_availableTransactions.length} 笔交易',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '已选择 ${_selectedTransactionIds.length} 笔',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Transaction list
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _availableTransactions[index];
                      final isSelected = _selectedTransactionIds.contains(transaction.id);

                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedTransactionIds.add(transaction.id!);
                              } else {
                                _selectedTransactionIds.remove(transaction.id);
                              }
                            });
                          },
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: transaction.amount < 0
                                  ? Colors.red[100]
                                  : Colors.green[100],
                              child: Icon(
                                transaction.amount < 0
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: transaction.amount < 0 ? Colors.red : Colors.green,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(transaction.payee ?? '未知商家'),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${dateFormat.format(transaction.date)} • 账户${transaction.accountId ?? "未知"}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormatter.format(
                                transaction.amount.abs(),
                                'CNY',  // TODO: Get currency from account
                              ),
                              style: TextStyle(
                                color: transaction.amount < 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (transaction.tags?.isNotEmpty == true)
                              Text(
                                transaction.tags!.join(', '),
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTransactionIds.remove(transaction.id);
                            } else {
                              _selectedTransactionIds.add(transaction.id!);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedTransactionIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saveLinkages,
              label: Text('保存 (${_selectedTransactionIds.length})'),
              icon: const Icon(Icons.check),
            )
          : null,
    );
  }
}