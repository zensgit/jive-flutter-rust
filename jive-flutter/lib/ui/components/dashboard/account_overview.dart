import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/account_provider.dart';
import '../../../models/account.dart';

class AccountOverview extends ConsumerWidget {
  const AccountOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountProvider);

    if (accountState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (accountState.errorMessage != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text('加载失败: ${accountState.errorMessage}'),
            TextButton(
              onPressed: () => ref.read(accountProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final accountList = accountState.accounts;
    if (accountList.isEmpty) {
      return _buildEmptyState(context);
    }

    // 按类型分组账户
    final Map<AccountType, List<Account>> groupedAccounts = {};
    double totalAssets = accountState.totalAssets;
    double totalLiabilities = accountState.totalLiabilities;

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

    return SizedBox(
      width: double.infinity,
      child: Row(
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
      ),
    );
  }

  Widget _buildOverviewCard(
      String title, double amount, Color color, IconData icon) {
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

  Widget _buildAccountItem(BuildContext context, Account account) {
    final balance = account.balance;
    final isNegative = balance < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: account.displayColor.withOpacity(0.2),
          child: Icon(
            account.icon,
            color: account.displayColor,
            size: 20,
          ),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          account.type.label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              account.formattedBalance,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isNegative ? Colors.red : Colors.green,
              ),
            ),
            if (account.lastTransactionDate != null)
              Text(
                _formatLastUpdated(account.lastTransactionDate),
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
