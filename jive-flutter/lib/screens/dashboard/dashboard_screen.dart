import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/components/dashboard/quick_actions.dart';
import '../../ui/components/dashboard/account_overview.dart';
import '../../ui/components/dashboard/recent_transactions.dart';
import '../../ui/components/dashboard/budget_summary.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/account.dart';
import '../../widgets/family_switcher.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLedger = ref.watch(currentLedgerProvider);
    final accounts = ref.watch(accountsProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('概览'),
            if (currentLedger != null)
              Text(
                currentLedger.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          // 使用新的家庭切换器组件
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: FamilySwitcher(),
          ),
          // 通知按钮
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 净资产卡片
            _buildNetWorthCard(context, accounts),
            const SizedBox(height: 16),
            
            // 快速操作
            const QuickActions(),
            const SizedBox(height: 24),
            
            // 账户概览
            _buildSectionTitle(context, '账户', onTap: () {
              // 导航到账户页面
            }),
            const SizedBox(height: 12),
            const AccountOverview(),
            const SizedBox(height: 24),
            
            // 最近交易
            _buildSectionTitle(context, '最近交易', onTap: () {
              // 导航到交易页面
            }),
            const SizedBox(height: 12),
            RecentTransactions(
              transactions: recentTransactions,
              onViewAll: () {
                // 导航到交易页面
              },
            ),
            const SizedBox(height: 24),
            
            // 预算摘要
            _buildSectionTitle(context, '本月预算', onTap: () {
              // 导航到预算页面
            }),
            const SizedBox(height: 12),
            const BudgetSummary(),
            const SizedBox(height: 80), // 给FAB留空间
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(BuildContext context, List<Account> accounts) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '净资产',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Icon(
                  Icons.trending_up,
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Consumer(builder: (context, ref, _) {
              final total = _calculateNetWorth(accounts);
              final formatted = ref.read(currencyProvider.notifier)
                  .formatCurrency(total, ref.read(baseCurrencyProvider).code);
              return Text(
                formatted,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer(builder: (context, ref, _) {
                    final str = ref.read(currencyProvider.notifier)
                        .formatCurrency(0, ref.read(baseCurrencyProvider).code);
                    return _buildSubAmount(
                      context,
                      '资产',
                      str,
                      Colors.green,
                    );
                  }),
                ),
                Expanded(
                  child: Consumer(builder: (context, ref, _) {
                    final str = ref.read(currencyProvider.notifier)
                        .formatCurrency(0, ref.read(baseCurrencyProvider).code);
                    return _buildSubAmount(
                      context,
                      '负债',
                      str,
                      Colors.red,
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubAmount(BuildContext context, String label, String amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onTap != null)
          TextButton(
            onPressed: onTap,
            child: const Text('查看全部'),
          ),
      ],
    );
  }

  double _calculateNetWorth(List<Account> accounts) {
    double total = 0.0;
    for (final account in accounts) {
      // 根据账户类型计算，负债账户（信用卡、贷款）为负值，其他为正值
      if (account.type == AccountType.creditCard || account.type == AccountType.loan) {
        total -= account.balance;
      } else {
        total += account.balance;
      }
    }
    return total;
  }

  void _showLedgerSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LedgerSwitcherSheet(),
    );
  }
}

class _LedgerSwitcherSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);
    final currentLedger = ref.watch(currentLedgerProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '切换账本',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: 导航到账本管理页面
                },
                icon: const Icon(Icons.settings),
                label: const Text('管理'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ledgers.when(
            data: (ledgerList) => Column(
              children: ledgerList.map((ledger) {
                final isSelected = ledger.id == currentLedger?.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected 
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    child: Icon(
                      _getLedgerIcon(ledger.type.value),
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  title: Text(ledger.name),
                  subtitle: Text(ledger.description ?? ''),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () {
                    ref.read(currentLedgerProvider.notifier).switchLedger(ledger);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('加载失败: $error')),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 导航到创建账本页面
              },
              icon: const Icon(Icons.add),
              label: const Text('创建新账本'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLedgerIcon(String type) {
    switch (type) {
      case 'personal':
        return Icons.person;
      case 'family':
        return Icons.family_restroom;
      case 'business':
        return Icons.business;
      case 'project':
        return Icons.work;
      case 'travel':
        return Icons.flight;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.book;
    }
  }
}
