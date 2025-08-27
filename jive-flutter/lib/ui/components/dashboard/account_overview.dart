import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/account_provider.dart';

class AccountOverview extends ConsumerWidget {
  const AccountOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return accounts.when(
      data: (accountList) {
        if (accountList.isEmpty) {
          return _buildEmptyState(context);
        }

        // 按类型分组账户
        final Map<String, List<dynamic>> groupedAccounts = {};
        double totalAssets = 0;
        double totalLiabilities = 0;

        for (final account in accountList) {
          final type = account.type ?? 'other';
          groupedAccounts.putIfAbsent(type, () => []).add(account);
          
          final balance = account.balance ?? 0.0;
          if (account.type == 'loan' || account.type == 'credit_card') {
            totalLiabilities += balance.abs();
          } else {
            totalAssets += balance;
          }
        }

        return Column(
          children: [
            // 资产负债概览
            _buildAssetLiabilityOverview(totalAssets, totalLiabilities),
            const SizedBox(height: 16),
            
            // 账户列表
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: accountList.take(5).length,
                itemBuilder: (context, index) {
                  final account = accountList[index];
                  return _buildAccountItem(context, account);
                },
              ),
            ),
            
            // 查看全部按钮
            if (accountList.length > 5)
              TextButton(
                onPressed: () => context.go(AppRoutes.accounts),
                child: Text('查看全部 ${accountList.length} 个账户'),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text('加载失败: $error'),
            TextButton(
              onPressed: () => ref.invalidate(accountsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('${AppRoutes.accounts}/add'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              const Text(
                '添加您的第一个账户',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '开始记录您的财务状况',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetLiabilityOverview(double assets, double liabilities) {
    final netWorth = assets - liabilities;
    
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            '资产',
            assets,
            Colors.green,
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            '负债',
            liabilities,
            Colors.red,
            Icons.trending_down,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            '净值',
            netWorth,
            netWorth >= 0 ? Colors.blue : Colors.orange,
            Icons.account_balance,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, dynamic account) {
    final balance = account.balance ?? 0.0;
    final isNegative = balance < 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAccountColor(account.type).withOpacity(0.2),
          child: Icon(
            _getAccountIcon(account.type),
            color: _getAccountColor(account.type),
            size: 20,
          ),
        ),
        title: Text(
          account.name ?? '未命名账户',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _getAccountTypeLabel(account.type),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isNegative ? Colors.red : Colors.green,
              ),
            ),
            if (account.lastUpdated != null)
              Text(
                _formatLastUpdated(account.lastUpdated),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        onTap: () => context.go('${AppRoutes.accounts}/${account.id}'),
      ),
    );
  }

  IconData _getAccountIcon(String? type) {
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

  Color _getAccountColor(String? type) {
    switch (type) {
      case 'checking':
        return Colors.blue;
      case 'savings':
        return Colors.green;
      case 'credit_card':
        return Colors.orange;
      case 'investment':
        return Colors.purple;
      case 'loan':
        return Colors.red;
      case 'cash':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getAccountTypeLabel(String? type) {
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
        return '贷款';
      case 'cash':
        return '现金';
      default:
        return '其他';
    }
  }

  String _formatLastUpdated(dynamic date) {
    if (date == null) return '';
    
    DateTime dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      dateTime = DateTime.parse(date);
    } else {
      return '';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${(difference.inDays / 7).floor()}周前';
    }
  }
}