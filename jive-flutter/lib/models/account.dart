import 'package:flutter/material.dart';

/// 账户主类型枚举
enum AccountMainType {
  asset('asset', '资产'),
  liability('liability', '负债');

  final String value;
  final String label;

  const AccountMainType(this.value, this.label);

  static AccountMainType fromString(String? value) {
    return AccountMainType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AccountMainType.asset,
    );
  }
}

/// 账户子类型枚举
enum AccountSubType {
  cash('cash', '现金', Icons.account_balance_wallet, AccountMainType.asset),
  debitCard('debit_card', '借记卡', Icons.credit_card, AccountMainType.asset),
  savingsAccount('savings_account', '储蓄账户', Icons.savings, AccountMainType.asset),
  checking('checking', '支票账户', Icons.account_balance, AccountMainType.asset),
  investment('investment', '投资账户', Icons.trending_up, AccountMainType.asset),
  prepaidCard('prepaid_card', '预付卡', Icons.card_giftcard, AccountMainType.asset),
  digitalWallet('digital_wallet', '数字钱包', Icons.account_balance_wallet, AccountMainType.asset),

  wechat('wechat', '微信', Icons.chat_bubble, AccountMainType.asset),
  wechatChange('wechat_change', '微信零钱通', Icons.currency_exchange, AccountMainType.asset),
  alipay('alipay', '支付宝', Icons.payment, AccountMainType.asset),
  yuebao('yuebao', '余额宝', Icons.account_balance, AccountMainType.asset),
  unionPay('union_pay', '云闪付', Icons.contactless, AccountMainType.asset),
  bankCard('bank_card', '银行卡', Icons.credit_card, AccountMainType.asset),
  providentFund('provident_fund', '公积金', Icons.work, AccountMainType.asset),
  qqWallet('qq_wallet', 'QQ钱包', Icons.wallet, AccountMainType.asset),
  jdWallet('jd_wallet', '京东金融', Icons.shopping_cart, AccountMainType.asset),
  medicalInsurance('medical_insurance', '医保', Icons.local_hospital, AccountMainType.asset),
  digitalRMB('digital_rmb', '数字人民币', Icons.currency_yuan, AccountMainType.asset),
  huaweiWallet('huawei_wallet', '华为钱包', Icons.phone_android, AccountMainType.asset),
  pinduoduoWallet('pinduoduo_wallet', '多多钱包', Icons.shopping_bag, AccountMainType.asset),
  paypal('paypal', 'PayPal', Icons.payment, AccountMainType.asset),

  creditCard('credit_card', '信用卡', Icons.credit_card, AccountMainType.liability),
  huabei('huabei', '花呗', Icons.credit_score, AccountMainType.liability),
  jiebei('jiebei', '借呗', Icons.request_quote, AccountMainType.liability),
  jdWhiteBar('jd_white_bar', '京东白条', Icons.receipt_long, AccountMainType.liability),
  meituanMonthly('meituan_monthly', '美团月付', Icons.restaurant, AccountMainType.liability),
  douyinMonthly('douyin_monthly', '抖音月付', Icons.video_library, AccountMainType.liability),
  wechatInstallment('wechat_installment', '微信分付', Icons.splitscreen, AccountMainType.liability),
  loan('loan', '贷款', Icons.money_off, AccountMainType.liability),
  mortgage('mortgage', '房贷', Icons.home, AccountMainType.liability),

  phoneCredit('phone_credit', '话费', Icons.phone, AccountMainType.asset),
  utilities('utilities', '水电', Icons.bolt, AccountMainType.asset),
  mealCard('meal_card', '饭卡', Icons.restaurant_menu, AccountMainType.asset),
  deposit('deposit', '押金', Icons.lock, AccountMainType.asset),
  transitCard('transit_card', '公交卡', Icons.directions_bus, AccountMainType.asset),
  membershipCard('membership_card', '会员卡', Icons.card_membership, AccountMainType.asset),
  gasCard('gas_card', '加油卡', Icons.local_gas_station, AccountMainType.asset),
  sinopecWallet('sinopec_wallet', '石化钱包', Icons.oil_barrel, AccountMainType.asset),
  appleAccount('apple_account', 'Apple', Icons.apple, AccountMainType.asset),

  stock('stock', '股票', Icons.show_chart, AccountMainType.asset),
  fund('fund', '基金', Icons.pie_chart, AccountMainType.asset),
  gold('gold', '黄金', Icons.diamond, AccountMainType.asset),
  forex('forex', '外汇', Icons.currency_exchange, AccountMainType.asset),
  futures('futures', '期货', Icons.candlestick_chart, AccountMainType.asset),
  bond('bond', '债券', Icons.assignment, AccountMainType.asset),
  fixedIncome('fixed_income', '固定收益', Icons.savings, AccountMainType.asset),
  crypto('crypto', '加密货币', Icons.currency_bitcoin, AccountMainType.asset),

  other('other', '其它', Icons.more_horiz, AccountMainType.asset);

  final String value;
  final String label;
  final IconData icon;
  final AccountMainType mainType;

  const AccountSubType(this.value, this.label, this.icon, this.mainType);

  static AccountSubType fromString(String? value) {
    if (value == null) return AccountSubType.cash;
    return AccountSubType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AccountSubType.other,
    );
  }

  bool get isAsset => mainType == AccountMainType.asset;
  bool get isLiability => mainType == AccountMainType.liability;
}

/// 账户类型枚举(已废弃,保留用于向后兼容)
@Deprecated('Use AccountSubType instead')
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

  AccountSubType toSubType() {
    switch (this) {
      case AccountType.checking:
        return AccountSubType.checking;
      case AccountType.savings:
        return AccountSubType.savingsAccount;
      case AccountType.creditCard:
        return AccountSubType.creditCard;
      case AccountType.cash:
        return AccountSubType.cash;
      case AccountType.investment:
        return AccountSubType.investment;
      case AccountType.loan:
        return AccountSubType.loan;
      case AccountType.other:
        return AccountSubType.cash;
    }
  }
}

/// 账户模型
class Account {
  final String? id;
  final String name;
  final AccountMainType mainType;
  final AccountSubType subType;
  @Deprecated('Use subType instead')
  final AccountType? legacyType;
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
    required this.mainType,
    required this.subType,
    @Deprecated('Use subType instead') this.legacyType,
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
    final subType = json['account_sub_type'] != null
        ? AccountSubType.fromString(json['account_sub_type'])
        : (json['type'] != null
            ? AccountType.fromString(json['type']).toSubType()
            : AccountSubType.cash);
    final mainType = json['account_main_type'] != null
        ? AccountMainType.fromString(json['account_main_type'])
        : subType.mainType;

    return Account(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      mainType: mainType,
      subType: subType,
      legacyType: json['type'] != null ? AccountType.fromString(json['type']) : null,
      balance: (json['balance'] ?? json['current_balance'] ?? 0).toDouble(),
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
      'account_main_type': mainType.value,
      'account_sub_type': subType.value,
      'type': subType.value,
      'balance': balance,
      'currency': currency,
      'account_number': accountNumber,
      'description': description,
      'color': color?.toARGB32(),
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
    AccountMainType? mainType,
    AccountSubType? subType,
    AccountType? legacyType,
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
      mainType: mainType ?? this.mainType,
      subType: subType ?? this.subType,
      legacyType: legacyType ?? this.legacyType,
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
  IconData get icon => subType.icon;

  /// 获取账户颜色
  Color get displayColor => color ?? _getDefaultColor();

  /// 获取默认颜色
  Color _getDefaultColor() {
    switch (subType) {
      case AccountSubType.cash:
        return Colors.teal;
      case AccountSubType.debitCard:
      case AccountSubType.bankCard:
        return Colors.blue;
      case AccountSubType.savingsAccount:
      case AccountSubType.yuebao:
        return Colors.green;
      case AccountSubType.checking:
        return Colors.blue;
      case AccountSubType.investment:
      case AccountSubType.stock:
      case AccountSubType.fund:
      case AccountSubType.bond:
        return Colors.purple;
      case AccountSubType.prepaidCard:
      case AccountSubType.phoneCredit:
      case AccountSubType.mealCard:
      case AccountSubType.gasCard:
        return Colors.amber;
      case AccountSubType.digitalWallet:
        return Colors.cyan;
      case AccountSubType.wechat:
      case AccountSubType.wechatChange:
        return Colors.green;
      case AccountSubType.alipay:
        return Colors.blue;
      case AccountSubType.unionPay:
        return Colors.red;
      case AccountSubType.creditCard:
      case AccountSubType.huabei:
      case AccountSubType.jiebei:
        return Colors.orange;
      case AccountSubType.loan:
        return Colors.red;
      case AccountSubType.mortgage:
        return Colors.deepOrange;
      case AccountSubType.gold:
        return Colors.yellow;
      case AccountSubType.crypto:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  /// 是否是负债账户
  bool get isLiability => subType.isLiability;

  /// 是否是资产账户
  bool get isAsset => subType.isAsset;

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
      // 避免运行时创建 IconData 以支持 web 图标 tree-shaking
      // 保留一个稳定的常量作为默认图标
      icon: json['icon'] != null ? Icons.folder : null,
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
      'color': color?.toARGB32(),
      'icon': icon?.codePoint,
      'sort_order': sortOrder,
      'account_ids': accountIds,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
