// 账户卡片组件
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/core/constants/app_constants.dart';

class AccountCard extends ConsumerWidget {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String currency;
  final Color? color;
  final IconData? icon;
  final String? bankName;
  final String? lastFourDigits;
  final bool isActive;
  final DateTime? lastSyncAt;
  final VoidCallback? onTap;
  final VoidCallback? onSync;

  const AccountCard({
    super.key,
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'CNY',
    this.color,
    this.icon,
    this.bankName,
    this.lastFourDigits,
    this.isActive = true,
    this.lastSyncAt,
    this.onTap,
    this.onSync,
    // Additional compatibility parameters
    dynamic account,
    VoidCallback? onLongPress,
    EdgeInsets? margin,
  });

  // Factory constructor that accepts Account object
  factory AccountCard.fromAccount({
    Key? key,
    required dynamic account,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return AccountCard(
      key: key,
      id: account.id ?? '',
      name: account.name ?? 'Unknown Account',
      type: account.type ?? 'unknown',
      balance: account.balance ?? 0.0,
      currency: account.currency ?? 'CNY',
      color: account.color,
      onTap: onTap,
      onSync: onLongPress,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shadowColor: (color ?? theme.primaryColor).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color ?? theme.primaryColor,
              (color ?? theme.primaryColor).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：账户名称和图标
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        icon ?? _getAccountTypeIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getAccountSubtitle(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '已停用',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // 余额部分
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '余额',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ref
                                .read(currencyProvider.notifier)
                                .formatCurrency(balance, currency),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onSync != null) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSync,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.sync,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // 底部信息
                if (lastSyncAt != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.sync,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '上次同步: ${_formatLastSync()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAccountTypeIcon() {
    switch (type.toLowerCase()) {
      case 'checking':
      case 'savings':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'investment':
        return Icons.trending_up;
      case 'loan':
        return Icons.money_off;
      case 'cash':
        return Icons.wallet;
      default:
        return Icons.account_balance_wallet;
    }
  }

  String _getAccountSubtitle() {
    if (bankName != null && lastFourDigits != null) {
      return '$bankName •••• $lastFourDigits';
    } else if (bankName != null) {
      return bankName!;
    } else if (lastFourDigits != null) {
      return '•••• $lastFourDigits';
    } else {
      return _getAccountTypeName();
    }
  }

  String _getAccountTypeName() {
    switch (type.toLowerCase()) {
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
        return '账户';
    }
  }

  // _getCurrencySymbol no longer used; currency formatting is centralized.
  String _getCurrencySymbol() {
    switch (currency.toUpperCase()) {
      case 'CNY':
        return '¥';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'JPY':
        return '¥';
      case 'GBP':
        return '£';
      default:
        return '¥';
    }
  }

  String _formatLastSync() {
    if (lastSyncAt == null) return '从未';

    final now = DateTime.now();
    final difference = now.difference(lastSyncAt!);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return DateFormat('MM/dd HH:mm').format(lastSyncAt!);
    }
  }
}
