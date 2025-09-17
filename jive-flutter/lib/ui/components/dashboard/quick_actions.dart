import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';

class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickActionCard(
            icon: Icons.add_circle,
            label: '收入',
            color: Colors.green,
            onTap: () => _navigateToAddTransaction(context, 'income'),
          ),
          _QuickActionCard(
            icon: Icons.remove_circle,
            label: '支出',
            color: Colors.red,
            onTap: () => _navigateToAddTransaction(context, 'expense'),
          ),
          _QuickActionCard(
            icon: Icons.swap_horiz,
            label: '转账',
            color: Colors.blue,
            onTap: () => _navigateToAddTransaction(context, 'transfer'),
          ),
          _QuickActionCard(
            icon: Icons.camera_alt,
            label: '扫票据',
            color: Colors.orange,
            onTap: () => _scanReceipt(context),
          ),
          _QuickActionCard(
            icon: Icons.repeat,
            label: '定期交易',
            color: Colors.purple,
            onTap: () => _navigateToScheduled(context),
          ),
        ],
      ),
    );
  }

  void _navigateToAddTransaction(BuildContext context, String type) {
    context.go('${AppRoutes.transactions}/add?type=$type');
  }

  void _scanReceipt(BuildContext context) {
    // TODO: 实现扫描票据功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('扫描票据功能开发中')),
    );
  }

  void _navigateToScheduled(BuildContext context) {
    // TODO: 导航到定期交易页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('定期交易功能开发中')),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
