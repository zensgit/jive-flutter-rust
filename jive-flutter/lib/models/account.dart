import 'package:flutter/material.dart';

/// 账户类型枚举
enum AccountType {
  checking('checking', '支票账户', Icons.account_balance),
  savings('savings', '储蓄账户', Icons.savings),
  creditCard('credit_card', '信用卡', Icons.credit_card),
  cash('cash', '现金', Icons.account_balance_wallet),
  investment('investment', '投资账户', Icons.trending_up),
  loan('loan', '贷款', Icons.money_off),
  other('other', '其他', Icons.account_circle);
  
  final String value;
  final String label;
  final IconData icon;
  
  const AccountType(this.value, this.label, this.icon);
  
  static AccountType fromString(String? value) {
    return AccountType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AccountType.other,
    );
  }
}

/// 账户模型
class Account {
  final String? id;
  final String name;
  final AccountType type;
  final double balance;
  final String currency;
  final String? accountNumber;
  final String? description;
  final Color? color;
  final bool isDefault;
  final bool excludeFromStats;
  final bool isArchived;
  final String? ledgerId;
  final String? groupId;
  final int? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastTransactionDate;
  
  Account({
    this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.currency = 'CNY',
    this.accountNumber,
    this.description,
    this.color,
    this.isDefault = false,
    this.excludeFromStats = false,
    this.isArchived = false,
    this.ledgerId,
    this.groupId,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
    this.lastTransactionDate,
  });
  
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      type: AccountType.fromString(json['type']),
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'CNY',
      accountNumber: json['account_number'],
      description: json['description'],
      color: json['color'] != null ? Color(json['color']) : null,
      isDefault: json['is_default'] ?? false,
      excludeFromStats: json['exclude_from_stats'] ?? false,
      isArchived: json['is_archived'] ?? false,
      ledgerId: json['ledger_id']?.toString(),
      groupId: json['group_id']?.toString(),
      sortOrder: json['sort_order'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.value,
      'balance': balance,
      'currency': currency,
      'account_number': accountNumber,
      'description': description,
      'color': color?.value,
      'is_default': isDefault,
      'exclude_from_stats': excludeFromStats,
      'is_archived': isArchived,
      'ledger_id': ledgerId,
      'group_id': groupId,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
    };
  }
  
  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? currency,
    String? accountNumber,
    String? description,
    Color? color,
    bool? isDefault,
    bool? excludeFromStats,
    bool? isArchived,
    String? ledgerId,
    String? groupId,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastTransactionDate,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      accountNumber: accountNumber ?? this.accountNumber,
      description: description ?? this.description,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
      isArchived: isArchived ?? this.isArchived,
      ledgerId: ledgerId ?? this.ledgerId,
      groupId: groupId ?? this.groupId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
  
  /// 获取显示的账户号码（后4位）
  String? get displayAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) {
      return accountNumber;
    }
    return '****${accountNumber!.substring(accountNumber!.length - 4)}';
  }
  
  /// 获取账户图标
  IconData get icon => type.icon;
  
  /// 获取账户颜色
  Color get displayColor => color ?? _getDefaultColor();
  
  /// 获取默认颜色
  Color _getDefaultColor() {
    switch (type) {
      case AccountType.checking:
        return Colors.blue;
      case AccountType.savings:
        return Colors.green;
      case AccountType.creditCard:
        return Colors.orange;
      case AccountType.cash:
        return Colors.teal;
      case AccountType.investment:
        return Colors.purple;
      case AccountType.loan:
        return Colors.red;
      case AccountType.other:
      default:
        return Colors.grey;
    }
  }
  
  /// 是否是负债账户
  bool get isLiability {
    return type == AccountType.creditCard || type == AccountType.loan;
  }
  
  /// 是否是资产账户
  bool get isAsset => !isLiability;
  
  /// 获取格式化的余额
  String get formattedBalance {
    final sign = isLiability && balance > 0 ? '-' : '';
    return '$sign$currencySymbol${balance.abs().toStringAsFixed(2)}';
  }
  
  /// 获取货币符号
  String get currencySymbol {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      default:
        return currency;
    }
  }
}

/// 账户分组
class AccountGroup {
  final String? id;
  final String name;
  final String? description;
  final Color? color;
  final IconData? icon;
  final int sortOrder;
  final List<String> accountIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  AccountGroup({
    this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.accountIds = const [],
    this.createdAt,
    this.updatedAt,
  });
  
  factory AccountGroup.fromJson(Map<String, dynamic> json) {
    return AccountGroup(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      description: json['description'],
      color: json['color'] != null ? Color(json['color']) : null,
      icon: json['icon'] != null 
          ? IconData(json['icon'], fontFamily: 'MaterialIcons') 
          : null,
      sortOrder: json['sort_order'] ?? 0,
      accountIds: json['account_ids'] != null
          ? List<String>.from(json['account_ids'])
          : [],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'color': color?.value,
      'icon': icon?.codePoint,
      'sort_order': sortOrder,
      'account_ids': accountIds,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}