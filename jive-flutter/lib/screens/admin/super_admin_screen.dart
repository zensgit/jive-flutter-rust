import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/string_utils.dart';
import 'currency_admin_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': '张三',
      'email': 'zhangsan@example.com',
      'role': 'Owner',
      'families': 2,
      'status': 'active',
      'createdAt': '2024-01-15',
    },
    {
      'id': '2',
      'name': '李四',
      'email': 'lisi@example.com',
      'role': 'Admin',
      'families': 1,
      'status': 'active',
      'createdAt': '2024-02-20',
    },
    {
      'id': '3',
      'name': '王五',
      'email': 'wangwu@example.com',
      'role': 'Member',
      'families': 1,
      'status': 'suspended',
      'createdAt': '2024-03-10',
    },
  ];

  final List<Map<String, dynamic>> _systemStats = [
    {
      'title': '总用户数',
      'value': '1,234',
      'icon': Icons.people,
      'color': Colors.blue
    },
    {
      'title': '活跃用户',
      'value': '987',
      'icon': Icons.person_add,
      'color': Colors.green
    },
    {
      'title': '家庭数量',
      'value': '456',
      'icon': Icons.family_restroom,
      'color': Colors.orange
    },
    {
      'title': '交易笔数',
      'value': '12,345',
      'icon': Icons.receipt_long,
      'color': Colors.purple
    },
  ];

  @override
  void initState() {
    super.initState();
    final isAdmin = ref.read(currentUserProvider)?.isAdmin ?? false;
    _tabController = TabController(length: isAdmin ? 5 : 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/Jiva.svg',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            const Text('系统管理'),
          ],
        ),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: '仪表盘', icon: const Icon(Icons.dashboard)),
            const Tab(text: '用户管理', icon: const Icon(Icons.people)),
            const Tab(text: '系统配置', icon: const Icon(Icons.settings)),
            const Tab(text: '日志监控', icon: const Icon(Icons.monitor)),
            if ((ref.read(currentUserProvider)?.isAdmin ?? false))
              const Tab(text: '币种管理', icon: const Icon(Icons.currency_exchange)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildUserManagementTab(),
          _buildSystemConfigTab(),
          _buildLogsTab(),
          if ((ref.read(currentUserProvider)?.isAdmin ?? false))
            const CurrencyAdminScreen()
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '系统概览',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 统计卡片
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _systemStats.length,
            itemBuilder: (context, index) {
              final stat = _systemStats[index];
              return Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        stat['icon'],
                        size: 32,
                        color: stat['color'],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              stat['title'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const Text(
                              stat['value'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // 最近活动
          const Text(
            '最近活动',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildActivityItem(
                    Icons.person_add, '新用户注册', '张三 刚刚注册', '2分钟前'),
                _buildActivityItem(
                    Icons.family_restroom, '创建家庭', '李四 创建了新家庭', '10分钟前'),
                _buildActivityItem(Icons.warning, '异常登录', '王五 异地登录检测', '1小时前'),
                _buildActivityItem(Icons.backup, '数据备份', '系统自动备份完成', '3小时前'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      IconData icon, String title, String subtitle, String time) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Icon(icon, color: Colors.blue[700]),
      ),
      title: const Text(title),
      subtitle: const Text(subtitle),
      trailing: const Text(
        time,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildUserManagementTab() {
    return Column(
      children: [
        // 搜索和过滤
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '搜索用户',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateUserDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('创建用户'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // 用户列表
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getUserRoleColor(user['role']),
                    child: const Text(
                      StringUtils.safeInitial(user['name']?.toString()),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: const Text(user['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(user['email']),
                      const Text('角色: ${user['role']} | 家庭数: ${user['families']}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(value, user),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: const Text('编辑')),
                      const PopupMenuItem(value: 'suspend', child: const Text('暂停')),
                      const PopupMenuItem(value: 'delete', child: const Text('删除')),
                      const PopupMenuItem(
                          value: 'reset_password', child: const Text('重置密码')),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSystemConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '系统配置',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildConfigSection('应用设置', [
          _buildConfigItem('应用名称', 'Jive Money - 集腋记账'),
          _buildConfigItem('版本号', '1.0.0'),
          _buildConfigItem('维护模式', '关闭',
              trailing: Switch(value: false, onChanged: (v) {})),
        ]),
        _buildConfigSection('安全设置', [
          _buildConfigItem('强制MFA', '启用',
              trailing: Switch(value: true, onChanged: (v) {})),
          _buildConfigItem('密码复杂度', '高'),
          _buildConfigItem('会话超时', '30分钟'),
        ]),
        _buildConfigSection('通知设置', [
          _buildConfigItem('邮件通知', '启用',
              trailing: Switch(value: true, onChanged: (v) {})),
          _buildConfigItem('短信通知', '启用',
              trailing: Switch(value: true, onChanged: (v) {})),
          _buildConfigItem('推送通知', '启用',
              trailing: Switch(value: true, onChanged: (v) {})),
        ]),
        _buildConfigSection('数据设置', [
          _buildConfigItem('自动备份', '每日'),
          _buildConfigItem('数据保留', '7年'),
          _buildConfigItem('导出格式', 'CSV, PDF, Excel'),
        ]),
      ],
    );
  }

  Widget _buildConfigSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String title, String value, {Widget? trailing}) {
    return ListTile(
      title: const Text(title),
      subtitle: const Text(value),
      trailing: trailing ?? const Icon(Icons.edit),
      contentPadding: EdgeInsets.zero,
      onTap: trailing == null ? () {} : null,
    );
  }

  Widget _buildLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '搜索日志',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: '全部',
                items: const [
                  DropdownMenuItem(value: '全部', child: const Text('全部')),
                  DropdownMenuItem(value: '错误', child: const Text('错误')),
                  DropdownMenuItem(value: '警告', child: const Text('警告')),
                  DropdownMenuItem(value: '信息', child: const Text('信息')),
                ],
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: ListTile(
                  leading: const Icon(
                    index % 3 == 0
                        ? Icons.error
                        : index % 3 == 1
                            ? Icons.warning
                            : Icons.info,
                    color: index % 3 == 0
                        ? Colors.red
                        : index % 3 == 1
                            ? Colors.orange
                            : Colors.blue,
                  ),
                  title: const Text('日志事件 ${index + 1}'),
                  subtitle: const Text('2024-08-26 10:${30 + index}:00 - 系统正常运行'),
                  trailing: const Text('IP: 192.168.1.${100 + index}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getUserRoleColor(String role) {
    switch (role) {
      case 'Owner':
        return Colors.purple;
      case 'Admin':
        return Colors.blue;
      case 'Member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'suspend':
        _showSuspendUserDialog(user);
        break;
      case 'delete':
        _showDeleteUserDialog(user);
        break;
      case 'reset_password':
        _showResetPasswordDialog(user);
        break;
    }
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新用户'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: '姓名')),
            const SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: '邮箱')),
            const SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: '初始密码')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑用户 - ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '姓名'),
              controller: TextEditingController(text: user['name']),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: '邮箱'),
              controller: TextEditingController(text: user['email']),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showSuspendUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂停用户'),
        content: const Text('确定要暂停用户 "${user['name']}" 吗？暂停后用户将无法登录系统。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('暂停'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除用户'),
        content: const Text('确定要删除用户 "${user['name']}" 吗？此操作不可撤销，将删除用户的所有数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('为用户 "${user['name']}" 重置密码'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: '新密码'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}
