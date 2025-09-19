import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

class HomeScreen extends StatefulWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(
      path: AppRoutes.dashboard,
      icon: Icons.dashboard,
      label: '概览',
    ),
    _NavItem(
      path: AppRoutes.transactions,
      icon: Icons.receipt_long,
      label: '交易',
    ),
    _NavItem(
      path: AppRoutes.accounts,
      icon: Icons.account_balance,
      label: '账户',
    ),
    _NavItem(
      path: AppRoutes.budgets,
      icon: Icons.pie_chart,
      label: '预算',
    ),
    _NavItem(
      path: AppRoutes.settings,
      icon: Icons.settings,
      label: '设置',
    ),
  ];

  void _onItemTapped(int index, BuildContext context) {
    setState(() {
      _selectedIndex = index;
    });
    context.go(_navItems[index].path);
  }

  int _calculateSelectedIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    _selectedIndex = _calculateSelectedIndex(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    // 只在概览和交易页面显示快速添加按钮
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      return FloatingActionButton(
        onPressed: () => _showQuickAddDialog(context),
        child: Icon(Icons.add),
        tooltip: '快速添加',
      );
    }
    return null;
  }

  void _showQuickAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快速操作',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickActionButton(
                  icon: Icons.remove,
                  label: '支出',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('${AppRoutes.transactions}/add?type=expense');
                  },
                ),
                _QuickActionButton(
                  icon: Icons.add,
                  label: '收入',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('${AppRoutes.transactions}/add?type=income');
                  },
                ),
                _QuickActionButton(
                  icon: Icons.swap_horiz,
                  label: '转账',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('${AppRoutes.transactions}/add?type=transfer');
                  },
                ),
                _QuickActionButton(
                  icon: Icons.account_balance,
                  label: '账户',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('${AppRoutes.accounts}/add');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;

  _NavItem({
    required this.path,
    required this.icon,
    required this.label,
  });
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
