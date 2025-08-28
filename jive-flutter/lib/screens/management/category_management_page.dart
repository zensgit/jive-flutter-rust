import 'package:flutter/material.dart';

/// 分类管理页面 - 简化版本
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  
  // 模拟数据
  final List<Map<String, dynamic>> _sampleCategories = [
    {'id': '1', 'name': '餐饮', 'icon': '🍽️', 'color': Colors.orange, 'type': 'expense'},
    {'id': '2', 'name': '交通', 'icon': '🚗', 'color': Colors.blue, 'type': 'expense'},
    {'id': '3', 'name': '购物', 'icon': '🛒', 'color': Colors.green, 'type': 'expense'},
    {'id': '4', 'name': '娱乐', 'icon': '🎬', 'color': Colors.purple, 'type': 'expense'},
    {'id': '5', 'name': '医疗', 'icon': '🏥', 'color': Colors.red, 'type': 'expense'},
    {'id': '6', 'name': '工资', 'icon': '💰', 'color': Colors.teal, 'type': 'income'},
    {'id': '7', 'name': '投资', 'icon': '📈', 'color': Colors.purple, 'type': 'income'},
    {'id': '8', 'name': '奖金', 'icon': '🎁', 'color': Colors.amber, 'type': 'income'},
    {'id': '9', 'name': '账户转账', 'icon': '🔄', 'color': Colors.grey, 'type': 'transfer'},
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('分类管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(),
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
                _buildStatCard('总分类', _sampleCategories.length, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('收入', _sampleCategories.where((c) => c['type'] == 'income').length, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('支出', _sampleCategories.where((c) => c['type'] == 'expense').length, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('转账', _sampleCategories.where((c) => c['type'] == 'transfer').length, Colors.grey),
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
                hintText: '搜索分类...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Tab(text: '收入'),
                Tab(text: '支出'),
                Tab(text: '转账'),
              ],
            ),
          ),
          
          // 分类列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList('income'),
                _buildCategoryList('expense'),
                _buildCategoryList('transfer'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新建分类'),
      ),
    );
  }
  
  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
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
  
  Widget _buildCategoryList(String type) {
    final filteredCategories = _sampleCategories.where((category) {
      final matchesType = category['type'] == type;
      final matchesSearch = _searchQuery.isEmpty ||
          category['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();
    
    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的分类' : '暂无分类',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('添加分类'),
              ),
            ],
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _buildCategoryCard(category);
      },
    );
  }
  
  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category['color'] as Color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              category['icon'] as String,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          category['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '示例分类 - 基于maybe-main设计',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditCategoryDialog(category);
                break;
              case 'delete':
                _showDeleteCategoryDialog(category);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _showCategoryDetails(category),
      ),
    );
  }
  
  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分类'),
        content: const Text('这里是添加分类的功能界面，基于maybe-main设计模式实现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分类添加功能演示')),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
  
  void _showEditCategoryDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑分类: ${category['name']}'),
        content: const Text('这里是编辑分类的功能界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已编辑分类: ${category['name']}')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteCategoryDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类"${category['name']}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除分类: ${category['name']}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  void _showCategoryDetails(Map<String, dynamic> category) {
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
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: category['color'] as Color,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      category['icon'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${category['type']} 分类',
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
              '分类详情',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '这是基于maybe-main项目设计的分类管理功能。在实际应用中，这里会显示该分类的使用统计、相关交易记录等详细信息。',
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}