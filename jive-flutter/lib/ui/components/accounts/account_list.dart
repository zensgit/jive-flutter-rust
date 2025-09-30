// 账户列表组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/ui/components/cards/account_card.dart';
import 'package:jive_money/ui/components/loading/loading_widget.dart';
import 'package:jive_money/models/account.dart' as model;

// 类型别名以兼容现有代码
typedef AccountData = model.Account;

class AccountList extends StatelessWidget {
  final List<AccountData> accounts;
  final bool groupByType;
  final Function(AccountData)? onAccountTap;
  final Function(AccountData)? onAccountLongPress;
  final VoidCallback? onAddAccount;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final bool showTotal;

  const AccountList({
    super.key,
    required this.accounts,
    this.groupByType = true,
    this.onAccountTap,
    this.onAccountLongPress,
    this.onAddAccount,
    this.onRefresh,
    this.isLoading = false,
    this.showTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (accounts.isEmpty) {
      return _buildEmptyState(context);
    }

    final content =
        groupByType ? _buildGroupedList(context) : _buildSimpleList(context);

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh!(),
        child: content,
      );
    }

    return content;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账户',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加您的第一个账户开始管理财务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          if (onAddAccount != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
              label: const Text('添加账户'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleList(BuildContext context) {
    return Column(
      children: [
        if (showTotal) _buildTotalSection(context),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AccountCard.fromAccount(
                account: account,
                onTap: () => onAccountTap?.call(account),
                onLongPress: () => onAccountLongPress?.call(account),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final groupedAccounts = _groupAccountsByType();
    final theme = Theme.of(context);

    return Column(
      children: [
        if (showTotal) _buildTotalSection(context),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedAccounts.length,
            itemBuilder: (context, index) {
              final group = groupedAccounts.entries.elementAt(index);
              final type = group.key;
              final typeAccounts = group.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 类型头部
                  _buildTypeHeader(theme, type, typeAccounts),

                  // 该类型的账户
                  ...typeAccounts.map(
                    (account) => AccountCard.fromAccount(
                      account: account,
                      onTap: () => onAccountTap?.call(account),
                      onLongPress: () => onAccountLongPress?.call(account),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection(BuildContext context) {
    final theme = Theme.of(context);
    final totalAssets = _calculateTotal(AccountType.asset);
    final totalLiabilities = _calculateTotal(AccountType.liability);
    final netWorth = totalAssets - totalLiabilities;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '净资产',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(netWorth),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总资产',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _formatAmount(totalAssets),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '总负债',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _formatAmount(totalLiabilities),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeHeader(
      ThemeData theme, AccountType type, List<AccountData> accounts) {
    final total =
        accounts.fold<double>(0, (sum, account) => sum + account.balance);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Icon(
            _getTypeIcon(type),
            size: 20,
            color: _getTypeColor(type),
          ),
          const SizedBox(width: 8),
          Text(
            _getTypeName(type),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _formatAmount(total),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: _getTypeColor(type),
            ),
          ),
        ],
      ),
    );
  }

  Map<AccountType, List<AccountData>> _groupAccountsByType() {
    final Map<AccountType, List<AccountData>> grouped = {};

    for (final account in accounts) {
      final key = _toUiAccountType(account.type);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(account);
    }

    // 按类型排序：资产、负债
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index)),
    );
  }

  double _calculateTotal(AccountType type) {
    return accounts
        .where((account) => account.type == _toModelAccountType(type))
        .fold(0.0, (sum, account) => sum + account.balance);
  }

  IconData _getTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return Icons.account_balance_wallet;
      case AccountType.liability:
        return Icons.credit_card;
    }
  }

  Color _getTypeColor(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return AppConstants.successColor;
      case AccountType.liability:
        return AppConstants.errorColor;
    }
  }

  String _getTypeName(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return '资产账户';
      case AccountType.liability:
        return '负债账户';
    }
  }

  String _formatAmount(double amount) {
    // Use base currency for account list totals
    // Note: This widget is not a ConsumerWidget; keep simple formatting here
    final sign = amount >= 0 ? '' : '-';
    return '$sign${amount.abs().toStringAsFixed(2)}';
  }
}

/// 账户类型枚举
enum AccountType {
  asset, // 资产
  liability, // 负债
}

/// 账户子类型枚举
enum AccountSubType {
  // 资产子类型
  cash, // 现金
  debitCard, // 借记卡
  savingsAccount, // 储蓄账户
  investment, // 投资账户
  prepaidCard, // 预付卡
  digitalWallet, // 数字钱包

  // 负债子类型
  creditCard, // 信用卡
  loan, // 贷款
  mortgage, // 房贷
}


  // Model<->UI AccountType adapter (moved below enums for analyzer)
// Model<->UI AccountType adapter
  model.AccountType _toModelAccountType(AccountType t) {
    switch (t) {
      case AccountType.asset:
        return model.AccountType.asset;
      case AccountType.liability:
        return model.AccountType.liability;
    }
  }

  AccountType _toUiAccountType(model.AccountType t) {
    switch (t) {
      case model.AccountType.asset:
        return AccountType.asset;
      case model.AccountType.liability:
        return AccountType.liability;
    }
  }


/// 账户分组列表
class GroupedAccountList extends StatelessWidget {
  final Map<String, List<AccountData>> groupedAccounts;
  final Function(AccountData)? onAccountTap;
  final bool showGroupTotal;

  const GroupedAccountList({
    super.key,
    required this.groupedAccounts,
    this.onAccountTap,
    this.showGroupTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupedAccounts.length,
      itemBuilder: (context, index) {
        final group = groupedAccounts.entries.elementAt(index);
        final groupName = group.key;
        final accounts = group.value;

        return ExpansionTile(
          title: Row(
            children: [
              Text(
                groupName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${accounts.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: showGroupTotal
              ? Text(
                  '总计: ${_formatGroupTotal(accounts)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                )
              : null,
          children: accounts
              .map(
                (account) => AccountCard.fromAccount(
                  account: account,
                  onTap: () => onAccountTap?.call(account),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _formatGroupTotal(List<AccountData> accounts) {
    final total =
        accounts.fold<double>(0, (sum, account) => sum + account.balance);
    return total.toStringAsFixed(2);
  }
}
