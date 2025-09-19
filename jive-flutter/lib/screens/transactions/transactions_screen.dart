import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../providers/transaction_provider.dart';
import '../../ui/components/transactions/transaction_list_item.dart';
import '../../models/transaction.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = ref.watch(transactionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易记录'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '支出'),
            Tab(text: '收入'),
            Tab(text: '转账'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionList(transactionState, 'all'),
          _buildTransactionList(transactionState, 'expense'),
          _buildTransactionList(transactionState, 'income'),
          _buildTransactionList(transactionState, 'transfer'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增交易'),
      ),
    );
  }

  Widget _buildTransactionList(
    TransactionState transactionState,
    String type,
  ) {
    if (transactionState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactionState.error != null) {
      final errorText = transactionState.error.toString();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Selectableconst Text('加载失败: $errorText'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => ref
                      .read(transactionControllerProvider.notifier)
                      .refresh(),
                  child: const Text('重试'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制错误信息'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: errorText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: const Text('已复制错误信息')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    final filtered =
        _filterTransactions(transactionState.filteredTransactions, type);
    if (filtered.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(transactionControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final transaction = filtered[index];
          return TransactionListItem(
            transaction: transaction,
            onTap: () {
              context.go('${AppRoutes.transactions}/${transaction.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    IconData icon;

    switch (type) {
      case 'expense':
        message = '暂无支出记录';
        icon = Icons.remove_circle_outline;
        break;
      case 'income':
        message = '暂无收入记录';
        icon = Icons.add_circle_outline;
        break;
      case 'transfer':
        message = '暂无转账记录';
        icon = Icons.swap_horiz;
        break;
      default:
        message = '暂无交易记录';
        icon = Icons.receipt_long;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddTransactionDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('添加${_getTypeLabel(type)}'),
          ),
        ],
      ),
    );
  }

  List<Transaction> _filterTransactions(
      List<Transaction> transactions, String type) {
    if (type == 'all') return transactions;

    return transactions.where((t) {
      switch (type) {
        case 'expense':
          return t.type == TransactionType.expense;
        case 'income':
          return t.type == TransactionType.income;
        case 'transfer':
          return t.type == TransactionType.transfer;
        default:
          return true;
      }
    }).toList();
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'expense':
        return '支出';
      case 'income':
        return '收入';
      case 'transfer':
        return '转账';
      default:
        return '交易';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选交易'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 日期范围选择
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text(_dateRange == null
                  ? '选择日期范围'
                  : '${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}'),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (range != null) {
                  setState(() {
                    _dateRange = range;
                  });
                  Navigator.pop(context);
                }
              },
            ),
            // 账户选择
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('选择账户'),
              onTap: () {
                // TODO: 显示账户选择对话框
              },
            ),
            // 分类选择
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('选择分类'),
              onTap: () {
                // TODO: 显示分类选择对话框
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilter = 'all';
                _dateRange = null;
              });
              Navigator.pop(context);
            },
            child: const Text('重置'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 应用筛选
              Navigator.pop(context);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: TransactionSearchDelegate(ref),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择交易类型',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, color: Colors.red),
                ),
                title: const Text('支出'),
                subtitle: const Text('记录日常开支'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('${AppRoutes.transactions}/add?type=expense');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.green),
                ),
                title: const Text('收入'),
                subtitle: const Text('记录收入来源'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('${AppRoutes.transactions}/add?type=income');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz, color: Colors.blue),
                ),
                title: const Text('转账'),
                subtitle: const Text('账户间转移资金'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('${AppRoutes.transactions}/add?type=transfer');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  TransactionSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // TODO: 实现搜索结果
    return Center(
      child: const Text('搜索: $query'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // TODO: 实现搜索建议
    return const Center(
      child: const Text('输入关键词搜索交易'),
    );
  }
}
