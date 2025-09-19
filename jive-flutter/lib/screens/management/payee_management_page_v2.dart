import 'package:flutter/material.dart';
import '../../utils/string_utils.dart';
import '../../services/api_service.dart';
import '../../models/payee.dart';

/// 交易对方管理页面 - API版本
class PayeeManagementPageV2 extends StatefulWidget {
  const PayeeManagementPageV2({super.key});

  @override
  State<PayeeManagementPageV2> createState() => _PayeeManagementPageV2State();
}

class _PayeeManagementPageV2State extends State<PayeeManagementPageV2>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  String _searchQuery = '';
  List<Payee> _allPayees = [];
  List<Payee> _filteredPayees = [];
  bool _isLoading = true;
  String? _error;

  // 使用固定的测试账本ID
  final String _ledgerId = '550e8400-e29b-41d4-a716-446655440001';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPayees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final payees = await _apiService.getPayees(
        ledgerId: _ledgerId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _allPayees = payees;
        _filteredPayees = payees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterPayees(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredPayees = _allPayees;
      } else {
        _filteredPayees = _allPayees
            .where((payee) =>
                payee.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _deletePayee(String payeeId) async {
    try {
      await _apiService.deletePayee(payeeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收款人已删除')),
      );
      _loadPayees(); // 重新加载列表
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  Future<void> _showAddPayeeDialog() async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    bool isVendor = true;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加收款人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: '备注',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: Text('供应商'),
                value: isVendor,
                onChanged: (value) => setState(() => isVendor = value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await _apiService.createPayee(Payee(
                    id: '', // API会生成
                    ledgerId: _ledgerId,
                    name: nameController.text,
                    notes: notesController.text.isNotEmpty
                        ? notesController.text
                        : null,
                    isVendor: isVendor,
                    isCustomer: !isVendor,
                    isActive: true,
                    transactionCount: 0,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ));

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('收款人已创建')),
                  );
                  _loadPayees();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建失败: $e')),
                  );
                }
              }
            },
            child: Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendors = _filteredPayees.where((p) => p.isVendor).toList();
    final customers = _filteredPayees.where((p) => p.isCustomer).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('收款人管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPayees,
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddPayeeDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '供应商'),
            Tab(text: '客户'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterPayees,
              decoration: InputDecoration(
                hintText: '搜索收款人...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 内容区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('加载失败: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPayees,
                              child: Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPayeeList(_filteredPayees),
                          _buildPayeeList(vendors),
                          _buildPayeeList(customers),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayeeList(List<Payee> payees) {
    if (payees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无收款人', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payees.length,
      itemBuilder: (context, index) {
        final payee = payees[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColorForPayee(payee),
              child: Text(
                StringUtils.safeInitial(payee.name),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              payee.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (payee.categoryName != null)
                  Text('分类: ${payee.categoryName}'),
                Text('交易次数: ${payee.transactionCount}'),
                if (payee.totalAmount != null)
                  Consumer(builder: (context, ref, _) {
                    final base = ref.watch(baseCurrencyProvider).code;
                    final str = ref
                        .read(currencyProvider.notifier)
                        .formatCurrency(payee.totalAmount ?? 0, base);
                    return Text('总金额: $str');
                  }),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  // TODO: 实现编辑功能
                } else if (value == 'delete') {
                  _deletePayee(payee.id);
                } else if (value == 'merge') {
                  // TODO: 实现合并功能
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'merge', child: Text('合并')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getColorForPayee(Payee payee) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.amber,
    ];

    final hash = payee.name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}
