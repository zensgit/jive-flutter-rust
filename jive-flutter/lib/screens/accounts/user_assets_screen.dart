import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/models/account.dart';
import 'package:jive_money/providers/account_provider.dart';

class UserAssetsScreen extends ConsumerWidget {
  const UserAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(accountStatsProvider);
    final accounts = ref.watch(accountsProvider);
    final assetAccounts = accounts.where((a) => a.isAsset).toList();
    final liabilityAccounts = accounts.where((a) => a.isLiability).toList();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产总览'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(accountProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildNetWorthCard(theme, stats),
            const SizedBox(height: 16),
            _buildSectionHeader(theme, '资产账户', Icons.account_balance_wallet),
            ..._buildAccountRows(theme, assetAccounts),
            const SizedBox(height: 16),
            _buildSectionHeader(theme, '负债账户', Icons.credit_card),
            ..._buildAccountRows(theme, liabilityAccounts),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(ThemeData theme, AccountStats stats) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('净资产', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              stats.netWorth.toStringAsFixed(2),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpi(theme, '总资产', stats.totalAssets, color: AppConstants.successColor),
                ),
                Container(width: 1, height: 24, color: theme.dividerColor.withValues(alpha: 0.5)),
                Expanded(
                  child: _buildKpi(theme, '总负债', stats.totalLiabilities, color: AppConstants.errorColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpi(ThemeData theme, String label, double value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  List<Widget> _buildAccountRows(ThemeData theme, List<Account> accounts) {
    if (accounts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('暂无', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ),
      ];
    }
    return accounts
        .map((a) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              leading: CircleAvatar(
                backgroundColor: (a.displayColor).withValues(alpha: 0.15),
                child: Icon(a.icon, color: a.displayColor),
              ),
              title: Text(a.name),
              subtitle: Text(a.type.label),
              trailing: Text(
                a.formattedBalance,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ))
        .toList();
  }
}
