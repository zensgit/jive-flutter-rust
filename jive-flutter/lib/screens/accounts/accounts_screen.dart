import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../providers/account_provider.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String _viewMode = 'list'; // list, group
  String _selectedGroupId = 'all';

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final accountGroups = ref.watch(accountGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
        actions: [
          // 视图切换
          IconButton(
            icon: Icon(_viewMode == 'list' ? Icons.folder : Icons.list),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'list' ? 'group' : 'list';
              });
            },
            tooltip: _viewMode == 'list' ? '分组视图' : '列表视图',
          ),
          // 更多操作
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'sort':
                  _showSortDialog();
                  break;
                case 'manage_groups':
                  _navigateToGroupManagement();
                  break;
                case 'archive':
                  _navigateToArchived();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sort',
                child: Text('排序'),
              ),
              const PopupMenuItem(
                value: 'manage_groups',
                child: Text('管理分组'),
              ),
              const PopupMenuItem(
                value: 'archive',
                child: Text('已归档账户'),
              ),
            ],
          ),
        ],
      ),
      body: accounts.when(
        data: (accountList) {
          if (accountList.isEmpty) {
            return _buildEmptyState();
          }

          if (_viewMode == 'group') {
            return _buildGroupView(accountList, accountGroups);
          } else {
            return _buildListView(accountList);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(accountsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('${AppRoutes.accounts}/add'),
        icon: const Icon(Icons.add),
        label: const Text('新增账户'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            '还没有账户',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加您的第一个账户开始记账',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('${AppRoutes.accounts}/add'),
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<dynamic> accounts) {
    // 按类型分组显示
    final Map<String, List<dynamic>> accountsByType = {};
    for (final account in accounts) {
      final type = account.type ?? 'other';
      accountsByType.putIfAbsent(type, () => []).add(account);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: accountsByType.length,
        itemBuilder: (context, index) {
          final type = accountsByType.keys.elementAt(index);
          final typeAccounts = accountsByType[type]!;
          
          return _buildAccountSection(type, typeAccounts);
        },
      ),
    );
  }

  Widget _buildGroupView(List<dynamic> accounts, AsyncValue<List<dynamic>> groups) {
    return groups.when(
      data: (groupList) {
        return DefaultTabController(
          length: groupList.length + 1,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabs: [
                  const Tab(text: '全部'),
                  ...groupList.map((group) => Tab(text: group.name)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAccountGrid(accounts),
                    ...groupList.map((group) {
                      final groupAccounts = accounts.where((account) {
                        // TODO: 根据实际的分组关系过滤
                        return false;
                      }).toList();
                      return _buildAccountGrid(groupAccounts);
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildListView(accounts),
    );
  }

  Widget _buildAccountSection(String type, List<dynamic> accounts) {
    final totalBalance = accounts.fold<double>(
      0,
      (sum, account) => sum + (account.balance ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getAccountTypeIcon(type),
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getAccountTypeLabel(type),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${accounts.length})',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '¥${totalBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: totalBalance >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
        ...accounts.map((account) => _buildAccountTile(account)),
      ],
    );
  }

  Widget _buildAccountTile(dynamic account) {
    final balance = account.balance ?? 0;
    final isPositive = balance >= 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Icon(
          _getAccountTypeIcon(account.type ?? 'other'),
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(account.name ?? '未命名账户'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (account.accountNumber != null)
            Text(
              '尾号 ${account.accountNumber!.substring(account.accountNumber!.length - 4)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (account.lastTransaction != null)
            Text(
              '最后交易: ${account.lastTransaction}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '¥${balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
          if (account.currency != null && account.currency != 'CNY')
            Text(
              account.currency!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      onTap: () {
        context.go('${AppRoutes.accounts}/${account.id}');
      },
      onLongPress: () {
        _showAccountActions(account);
      },
    );
  }

  Widget _buildAccountGrid(List<dynamic> accounts) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return _buildAccountCard(account);
      },
    );
  }

  Widget _buildAccountCard(dynamic account) {
    final balance = account.balance ?? 0;
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('${AppRoutes.accounts}/${account.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    _getAccountTypeIcon(account.type ?? 'other'),
                    color: Theme.of(context).primaryColor,
                  ),
                  if (account.isDefault == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '默认',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                account.name ?? '未命名',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '¥${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: balance >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'checking':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'credit_card':
        return Icons.credit_card;
      case 'investment':
        return Icons.trending_up;
      case 'loan':
        return Icons.money_off;
      case 'cash':
        return Icons.account_balance_wallet;
      default:
        return Icons.account_circle;
    }
  }

  String _getAccountTypeLabel(String type) {
    switch (type) {
      case 'checking':
        return '支票账户';
      case 'savings':
        return '储蓄账户';
      case 'credit_card':
        return '信用卡';
      case 'investment':
        return '投资账户';
      case 'loan':
        return '贷款账户';
      case 'cash':
        return '现金';
      default:
        return '其他';
    }
  }

  void _showAccountActions(dynamic account) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑账户'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导航到编辑页面
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: Text(account.isDefault ? '取消默认' : '设为默认'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 设置默认账户
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('归档账户'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 归档账户
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除账户', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(account);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(dynamic account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账户"${account.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 删除账户
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    // TODO: 实现排序对话框
  }

  void _navigateToGroupManagement() {
    // TODO: 导航到分组管理页面
  }

  void _navigateToArchived() {
    // TODO: 导航到归档账户页面
  }
}