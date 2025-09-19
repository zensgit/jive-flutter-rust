import 'package:flutter/material.dart';

/// 旅行事件管理页面 - 简化版本
class TravelEventManagementPage extends StatefulWidget {
  const TravelEventManagementPage({super.key});

  @override
  State<TravelEventManagementPage> createState() =>
      _TravelEventManagementPageState();
}

class _TravelEventManagementPageState extends State<TravelEventManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  // 模拟数据
  final List<Map<String, dynamic>> _sampleEvents = [
    {
      'id': '1',
      'name': '北京商务出差',
      'description': '参加年度销售会议',
      'status': 'upcoming',
      'startDate': '2024-03-15',
      'endDate': '2024-03-18',
      'destination': '北京',
      'budget': 5000.0,
      'spent': 0.0,
      'tags': ['商务', '出差'],
      'color': Colors.blue,
    },
    {
      'id': '2',
      'name': '上海展会',
      'description': '参加国际科技展览会',
      'status': 'active',
      'startDate': '2024-02-20',
      'endDate': '2024-02-25',
      'destination': '上海',
      'budget': 8000.0,
      'spent': 3500.0,
      'tags': ['展会', '商务'],
      'color': Colors.green,
    },
    {
      'id': '3',
      'name': '日本旅游',
      'description': '东京大阪7日游',
      'status': 'completed',
      'startDate': '2024-01-10',
      'endDate': '2024-01-17',
      'destination': '日本',
      'budget': 12000.0,
      'spent': 11500.0,
      'tags': ['旅游', '休闲'],
      'color': Colors.orange,
    },
    {
      'id': '4',
      'name': '深圳技术交流',
      'description': '与合作伙伴进行技术讨论',
      'status': 'completed',
      'startDate': '2024-01-25',
      'endDate': '2024-01-27',
      'destination': '深圳',
      'budget': 3000.0,
      'spent': 2800.0,
      'tags': ['技术', '商务'],
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final upcomingEvents =
        _sampleEvents.where((e) => e['status'] == 'upcoming').length;
    final activeEvents =
        _sampleEvents.where((e) => e['status'] == 'active').length;
    final completedEvents =
        _sampleEvents.where((e) => e['status'] == 'completed').length;
    final totalBudget = _sampleEvents.fold<double>(
        0, (sum, e) => sum + (e['budget'] as double));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('旅行事件管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEventDialog(),
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
                _buildStatCard('即将开始', upcomingEvents, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('进行中', activeEvents, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard('已完成', completedEvents, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard('总预算', totalBudget.toInt(), Colors.purple),
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
                hintText: '搜索旅行事件...',
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
                Tab(text: '即将开始'),
                Tab(text: '进行中'),
                Tab(text: '已完成'),
              ],
            ),
          ),

          // 事件列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventList('upcoming'),
                _buildEventList('active'),
                _buildEventList('completed'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(),
        icon: const Icon(Icons.flight_takeoff),
        label: const Text('新建事件'),
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

  Widget _buildEventList(String status) {
    final filteredEvents = _sampleEvents.where((event) {
      final matchesStatus = event['status'] == status;
      final matchesSearch = _searchQuery.isEmpty ||
          event['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          event['destination']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          event['description']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.travel_explore,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              _searchQuery.isNotEmpty ? '未找到匹配的旅行事件' : '暂无旅行事件',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddEventDialog(),
                icon: const Icon(Icons.add),
                label: const Text('创建第一个旅行事件'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final event = filteredEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final spentRatio = (event['spent'] as double) / (event['budget'] as double);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: event['color'] as Color,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.flight,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: const Text(
          event['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '${event['destination']} • ${event['startDate']} - ${event['endDate']}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            const Text(
              event['description'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            if (event['status'] != 'upcoming') ...[
              LinearProgressIndicator(
                value: spentRatio,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  spentRatio > 0.9 ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '预算: ¥${event['budget'].toStringAsFixed(0)} / 已花: ¥${event['spent'].toStringAsFixed(0)} - 基于maybe-main设计',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ] else ...[
              const Text(
                '预算: ¥${event['budget'].toStringAsFixed(0)} - 基于maybe-main设计',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: ((event['tags'] as List)
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (event['color'] as Color).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        tag as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: event['color'] as Color,
                        ),
                      ),
                    ),
                  )
                  .toList()),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditEventDialog(event);
                break;
              case 'delete':
                _showDeleteEventDialog(event);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: const Text('编辑')),
            const PopupMenuItem(value: 'delete', child: const Text('删除')),
          ],
        ),
        onTap: () => _showEventDetails(event),
      ),
    );
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建旅行事件'),
        content: const Text('这里是创建旅行事件的功能界面，基于maybe-main设计模式实现。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: const Text('旅行事件创建功能演示')),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditEventDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑: ${event['name']}'),
        content: const Text('这里是编辑旅行事件的功能界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('已编辑: ${event['name']}')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteEventDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除旅行事件'),
        content: const Text(
          '确定要删除旅行事件"${event['name']}"吗？\n这将删除相关的所有记录。',
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
                SnackBar(content: const Text('已删除: ${event['name']}')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: event['color'] as Color,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.flight,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        event['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '${event['destination']} • ${_getStatusconst Text(event['status'] as String)}',
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
              '事件详情',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              event['description'] as String,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  '${event['startDate']} - ${event['endDate']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  '预算: ¥${event['budget'].toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (event['status'] != 'upcoming') ...[
                  const SizedBox(width: 16),
                  const Text(
                    '已花: ¥${event['spent'].toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '这是基于maybe-main项目设计的旅行事件管理功能。在实际应用中，这里会显示详细的行程安排、费用明细、相关文档等信息。',
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

  String _getStatusconst Text(String status) {
    switch (status) {
      case 'upcoming':
        return '即将开始';
      case 'active':
        return '进行中';
      case 'completed':
        return '已完成';
      default:
        return '未知状态';
    }
  }
}
