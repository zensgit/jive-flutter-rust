import 'package:flutter/material.dart';

/// 标签管理页面 - 简化版本
class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  String _searchQuery = '';
  
  // 模拟数据
  final List<Map<String, dynamic>> _sampleTags = [
    {'id': '1', 'name': '工作', 'color': Colors.blue, 'usageCount': 25, 'isActive': true},
    {'id': '2', 'name': '家庭', 'color': Colors.green, 'usageCount': 18, 'isActive': true},
    {'id': '3', 'name': '健康', 'color': Colors.red, 'usageCount': 12, 'isActive': true},
    {'id': '4', 'name': '教育', 'color': Colors.purple, 'usageCount': 8, 'isActive': true},
    {'id': '5', 'name': '旅行', 'color': Colors.orange, 'usageCount': 15, 'isActive': true},
    {'id': '6', 'name': '购物', 'color': Colors.teal, 'usageCount': 22, 'isActive': true},
    {'id': '7', 'name': '娱乐', 'color': Colors.pink, 'usageCount': 6, 'isActive': false},
  ];
  
  @override
  Widget build(BuildContext context) {
    final filteredTags = _sampleTags.where((tag) {
      return _searchQuery.isEmpty ||
          tag['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    final activeTags = filteredTags.where((tag) => tag['isActive'] == true).length;
    final totalUsage = _sampleTags.fold<int>(0, (sum, tag) => sum + (tag['usageCount'] as int));
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('标签管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTagDialog(),
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
                _buildStatCard('总标签', _sampleTags.length, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('活跃标签', activeTags, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('总使用', totalUsage, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('平均使用', totalUsage ~/ _sampleTags.length, Colors.purple),
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
                hintText: '搜索标签...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          
          // 标签列表
          Expanded(
            child: _buildTagList(filteredTags),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTagDialog(),
        icon: const Icon(Icons.add),
        label: const Text('新建标签'),
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
  
  Widget _buildTagList(List<Map<String, dynamic>> tags) {
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.label_outline,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的标签' : '暂无标签',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddTagDialog(),
                icon: const Icon(Icons.add),
                label: const Text('创建第一个标签'),
              ),
            ],
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        return _buildTagCard(tag);
      },
    );
  }
  
  Widget _buildTagCard(Map<String, dynamic> tag) {
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
            color: tag['color'] as Color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.label,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              tag['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            if (!(tag['isActive'] as bool))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '已禁用',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '使用次数: ${tag['usageCount']} 次 - 基于maybe-main设计',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditTagDialog(tag);
                break;
              case 'toggle':
                _toggleTagStatus(tag);
                break;
              case 'delete':
                _showDeleteTagDialog(tag);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(tag['isActive'] ? '禁用' : '启用'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _showTagDetails(tag),
      ),
    );
  }
  
  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建标签'),
        content: const Text('这里是创建标签的功能界面，基于maybe-main设计模式实现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('标签创建功能演示')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
  
  void _showEditTagDialog(Map<String, dynamic> tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑标签: ${tag['name']}'),
        content: const Text('这里是编辑标签的功能界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已编辑标签: ${tag['name']}')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
  
  void _toggleTagStatus(Map<String, dynamic> tag) {
    setState(() {
      tag['isActive'] = !(tag['isActive'] as bool);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tag['name']} 已${tag['isActive'] ? '启用' : '禁用'}'),
      ),
    );
  }
  
  void _showDeleteTagDialog(Map<String, dynamic> tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text(
          '确定要删除标签"${tag['name']}"吗？\n这将影响 ${tag['usageCount']} 笔交易。',
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
                SnackBar(content: Text('已删除标签: ${tag['name']}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  void _showTagDetails(Map<String, dynamic> tag) {
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
                    color: tag['color'] as Color,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.label,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '使用次数: ${tag['usageCount']} 次',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag['isActive'] ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag['isActive'] ? '活跃' : '禁用',
                    style: TextStyle(
                      fontSize: 12,
                      color: tag['isActive'] ? Colors.green[700] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '标签详情',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '这是基于maybe-main项目设计的标签管理功能。在实际应用中，这里会显示使用该标签的所有交易记录、使用趋势图表等详细信息。',
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