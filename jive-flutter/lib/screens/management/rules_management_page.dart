import 'package:flutter/material.dart';

/// 规则管理页面 - 简化版本
class RulesManagementPage extends StatefulWidget {
  const RulesManagementPage({super.key});

  @override
  State<RulesManagementPage> createState() => _RulesManagementPageState();
}

class _RulesManagementPageState extends State<RulesManagementPage> {
  String _searchQuery = '';

  // 模拟数据
  final List<Map<String, dynamic>> _sampleRules = [
    {
      'id': '1',
      'name': '餐饮自动分类',
      'description': '包含"餐厅"、"外卖"等关键词时自动归类到餐饮',
      'isActive': true,
      'matchCount': 156,
      'conditions': ['描述包含: 餐厅', '金额 < 200'],
      'actions': ['设置分类: 餐饮', '添加标签: 用餐'],
    },
    {
      'id': '2',
      'name': '工资自动识别',
      'description': '工资到账时自动标记收入类型',
      'isActive': true,
      'matchCount': 12,
      'conditions': ['描述包含: 工资', '金额 > 5000'],
      'actions': ['设置分类: 工资收入', '添加标签: 工作'],
    },
    {
      'id': '3',
      'name': '大额支出提醒',
      'description': '单笔支出超过1000元时发送提醒',
      'isActive': true,
      'matchCount': 28,
      'conditions': ['金额 > 1000', '类型: 支出'],
      'actions': ['发送通知', '添加标签: 大额支出'],
    },
    {
      'id': '4',
      'name': '交通费归类',
      'description': '自动识别和归类交通相关支出',
      'isActive': false,
      'matchCount': 89,
      'conditions': ['描述包含: 地铁,公交,打车'],
      'actions': ['设置分类: 交通出行'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRules = _sampleRules.where((rule) {
      return _searchQuery.isEmpty ||
          rule['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          rule['description']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();

    final activeRules =
        _sampleRules.where((rule) => rule['isActive'] == true).length;
    final totalMatches = _sampleRules.fold<int>(
        0, (sum, rule) => sum + (rule['matchCount'] as int));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('规则管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(),
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
                _buildStatCard('总规则', _sampleRules.length, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('活跃规则', activeRules, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('总匹配', totalMatches, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard(
                    '成功率',
                    totalMatches > 0
                        ? (totalMatches / _sampleRules.length).round()
                        : 0,
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
                hintText: '搜索规则...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),

          // 规则列表
          Expanded(
            child: _buildRulesList(filteredRules),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRuleDialog(),
        icon: Icon(Icons.add),
        label: Text('新建规则'),
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

  Widget _buildRulesList(List<Map<String, dynamic>> rules) {
    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? '未找到匹配的规则' : '暂无规则',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddRuleDialog(),
                icon: Icon(Icons.add),
                label: Text('创建第一个规则'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _buildRuleCard(rule);
      },
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rule['isActive'] ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            rule['isActive'] ? Icons.check_circle : Icons.pause_circle,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rule['isActive'] ? Colors.green[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rule['isActive'] ? '活跃' : '暂停',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      rule['isActive'] ? Colors.green[700] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rule['description'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              '已匹配 ${rule['matchCount']} 次 - 基于maybe-main设计',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditRuleDialog(rule);
                break;
              case 'toggle':
                _toggleRuleStatus(rule);
                break;
              case 'delete':
                _showDeleteRuleDialog(rule);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(rule['isActive'] ? '暂停' : '启用'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '触发条件:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...((rule['conditions'] as List).map(
                  (condition) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          condition as String,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 12),
                Text(
                  '执行动作:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...((rule['actions'] as List).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow,
                            size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          action as String,
                          style:
                              TextStyle(color: Colors.blue[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('新建规则'),
        content: Text('这里是创建自动化规则的功能界面，基于maybe-main设计模式实现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('规则创建功能演示')),
              );
            },
            child: Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditRuleDialog(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑规则: ${rule['name']}'),
        content: Text('这里是编辑规则的功能界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已编辑规则: ${rule['name']}')),
              );
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  void _toggleRuleStatus(Map<String, dynamic> rule) {
    setState(() {
      rule['isActive'] = !(rule['isActive'] as bool);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${rule['name']} 已${rule['isActive'] ? '启用' : '暂停'}'),
      ),
    );
  }

  void _showDeleteRuleDialog(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除规则'),
        content: Text(
          '确定要删除规则"${rule['name']}"吗？\n这将影响未来的自动化处理。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除规则: ${rule['name']}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('删除'),
          ),
        ],
      ),
    );
  }
}
