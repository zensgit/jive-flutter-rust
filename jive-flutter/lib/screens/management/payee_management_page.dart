import 'package:flutter/material.dart';
import '../../utils/string_utils.dart';

/// 交易对方管理页面 - 简化版本
class PayeeManagementPage extends StatefulWidget {
  const PayeeManagementPage({super.key});

  @override
  State<PayeeManagementPage> createState() => _PayeeManagementPageState();
}

class _PayeeManagementPageState extends State<PayeeManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  // 模拟数据
  final List<Map<String, dynamic>> _samplePayees = [
    {
      'id': '1',
      'name': '张三',
      'type': 'family',
      'email': 'zhangsan@email.com',
      'phone': '13800138001',
      'color': Colors.blue,
      'transactionCount': 25
    },
    {
      'id': '2',
      'name': '李四',
      'type': 'family',
      'email': 'lisi@email.com',
      'phone': '13800138002',
      'color': Colors.green,
      'transactionCount': 18
    },
    {
      'id': '3',
      'name': '王五',
      'type': 'family',
      'email': '',
      'phone': '13800138003',
      'color': Colors.orange,
      'transactionCount': 12
    },
    {
      'id': '4',
      'name': '阿里巴巴',
      'type': 'provider',
      'email': 'support@alibaba.com',
      'phone': '400-800-1688',
      'color': Colors.purple,
      'transactionCount': 45
    },
    {
      'id': '5',
      'name': '腾讯科技',
      'type': 'provider',
      'email': 'service@tencent.com',
      'phone': '400-600-0700',
      'color': Colors.teal,
      'transactionCount': 32
    },
    {
      'id': '6',
      'name': '京东商城',
      'type': 'provider',
      'email': 'service@jd.com',
      'phone': '400-606-5500',
      'color': Colors.red,
      'transactionCount': 28
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyPayees =
        _samplePayees.where((p) => p['type'] == 'family').toList();
    final providerPayees =
        _samplePayees.where((p) => p['type'] == 'provider').toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('交易对方管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPayeeDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计面板
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard('总对方', _samplePayees.length, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('家庭成员', familyPayees.length, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('服务提供商', providerPayees.length, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard(
                    '总交易',
                    _samplePayees.fold<int>(
                        0, (sum, p) => sum + (p['transactionCount'] as int)),
                    Colors.purple),
              ],
            ),
          ),

          // 搜索栏
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索交易对方...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          // Tab栏
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '家庭成员'),
                Tab(text: '服务提供商'),
              ],
            ),
          ),

          // 交易对方列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPayeeList('family'),
                _buildPayeeList('provider'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPayeeDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('新建对方'),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayeeList(String type) {
    final filteredPayees = _samplePayees.where((payee) {
      final matchesType = payee['type'] == type;
      final matchesSearch = _searchQuery.isEmpty ||
          payee['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          payee['email']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          payee['phone'].toString().contains(_searchQuery);
      return matchesType && matchesSearch;
    }).toList();

    if (filteredPayees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              type == 'family' ? Icons.family_restroom : Icons.business,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              _searchQuery.isNotEmpty ? '未找到匹配的交易对方' : '暂无交易对方',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddPayeeDialog(),
                icon: const Icon(Icons.add),
                label: const Text('添加${type == 'family' ? '家庭成员' : '服务提供商'}'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPayees.length,
      itemBuilder: (context, index) {
        final payee = filteredPayees[index];
        return _buildPayeeCard(payee);
      },
    );
  }

  Widget _buildPayeeCard(Map<String, dynamic> payee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: payee['color'] as Color,
          child: const Text(
            StringUtils.safeInitial(payee['name']?.toString()),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: const Text(
          payee['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (payee['email'].toString().isNotEmpty)
              const Text(
                '邮箱: ${payee['email']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (payee['phone'].toString().isNotEmpty)
              const Text(
                '电话: ${payee['phone']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const Text(
              '交易次数: ${payee['transactionCount']} 次 - 基于maybe-main设计',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditPayeeDialog(payee);
                break;
              case 'delete':
                _showDeletePayeeDialog(payee);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: const Text('编辑')),
            const PopupMenuItem(value: 'delete', child: const Text('删除')),
          ],
        ),
        onTap: () => _showPayeeDetails(payee),
      ),
    );
  }

  void _showAddPayeeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建交易对方'),
        content: const Text('这里是创建交易对方的功能界面，基于maybe-main设计模式实现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: const Text('交易对方创建功能演示')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditPayeeDialog(Map<String, dynamic> payee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑: ${payee['name']}'),
        content: const Text('这里是编辑交易对方的功能界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('已编辑: ${payee['name']}')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeletePayeeDialog(Map<String, dynamic> payee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易对方'),
        content: const Text(
          '确定要删除"${payee['name']}"吗？\n这将影响 ${payee['transactionCount']} 笔交易记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('已删除: ${payee['name']}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showPayeeDetails(Map<String, dynamic> payee) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: payee['color'] as Color,
                  child: const Text(
                    StringUtils.safeInitial(payee['name']?.toString()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        payee['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        payee['type'] == 'family' ? '家庭成员' : '服务提供商',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '联系信息',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (payee['email'].toString().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text(
                    payee['email'] as String,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (payee['phone'].toString().isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text(
                    payee['phone'] as String,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  '共 ${payee['transactionCount']} 笔交易',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '这是基于maybe-main项目设计的交易对方管理功能。在实际应用中，这里会显示与该交易对方的所有交易记录、金额统计等详细信息。',
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
