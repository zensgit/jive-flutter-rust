// 账本类型枚举
enum LedgerType {
  personal('personal', '个人'),
  family('family', '家庭'),
  business('business', '商业'),
  project('project', '项目'),
  travel('travel', '旅行'),
  investment('investment', '投资');

  final String value;
  final String label;

  const LedgerType(this.value, this.label);

  static LedgerType fromString(String value) {
    return LedgerType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LedgerType.personal,
    );
  }
}

// 账本模型
class Ledger {
  final String? id;
  final String name;
  final LedgerType type;
  final String? description;
  final String currency;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? settings;
  final List<String>? memberIds;
  final String? ownerId;

  Ledger({
    this.id,
    required this.name,
    required this.type,
    this.description,
    this.currency = 'CNY',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
    this.settings,
    this.memberIds,
    this.ownerId,
  });

  factory Ledger.fromJson(Map<String, dynamic> json) {
    return Ledger(
      id: json['id'],
      name: json['name'],
      type: LedgerType.fromString(json['type']),
      description: json['description'],
      currency: json['currency'] ?? 'CNY',
      isDefault: json['is_default'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      settings: json['settings'],
      memberIds: json['member_ids'] != null 
          ? List<String>.from(json['member_ids']) 
          : null,
      ownerId: json['owner_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.value,
      'description': description,
      'currency': currency,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'settings': settings,
      'member_ids': memberIds,
      'owner_id': ownerId,
    };
  }

  Ledger copyWith({
    String? id,
    String? name,
    LedgerType? type,
    String? description,
    String? currency,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
    List<String>? memberIds,
    String? ownerId,
  }) {
    return Ledger(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      memberIds: memberIds ?? this.memberIds,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}

// 账本角色枚举
enum LedgerRole {
  owner('owner', '所有者'),
  admin('admin', '管理员'),
  editor('editor', '编辑者'),
  viewer('viewer', '查看者');
  
  final String value;
  final String label;
  
  const LedgerRole(this.value, this.label);
  
  static LedgerRole fromString(String? value) {
    return LedgerRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => LedgerRole.viewer,
    );
  }
}

// 账本统计信息
class LedgerStatistics {
  final String ledgerId;
  final int accountCount;
  final int transactionCount;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> accountTypeBreakdown;
  final Map<String, double> monthlyTrend;
  final Map<String, double>? categoryBreakdown;
  final DateTime? lastTransactionDate;
  
  LedgerStatistics({
    required this.ledgerId,
    required this.accountCount,
    required this.transactionCount,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.accountTypeBreakdown,
    required this.monthlyTrend,
    this.categoryBreakdown,
    this.lastTransactionDate,
  });
  
  factory LedgerStatistics.fromJson(Map<String, dynamic> json) {
    return LedgerStatistics(
      ledgerId: json['ledger_id'],
      accountCount: json['account_count'] ?? 0,
      transactionCount: json['transaction_count'] ?? 0,
      totalAssets: (json['total_assets'] ?? 0).toDouble(),
      totalLiabilities: (json['total_liabilities'] ?? 0).toDouble(),
      netWorth: (json['net_worth'] ?? 0).toDouble(),
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      accountTypeBreakdown: Map<String, double>.from(json['account_type_breakdown'] ?? {}),
      monthlyTrend: Map<String, double>.from(json['monthly_trend'] ?? {}),
      categoryBreakdown: json['category_breakdown'] != null
          ? Map<String, double>.from(json['category_breakdown'])
          : null,
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
    );
  }
}

// 账本成员
class LedgerMember {
  final String userId;
  final String name;
  final String email;
  final String? avatar;
  final LedgerRole role;
  final Map<String, bool> permissions;
  final DateTime joinedAt;
  final DateTime? lastAccessedAt;
  
  // 兼容旧版本的别名getters
  String get userName => name;
  String? get userEmail => email;
  String? get userAvatar => avatar;
  
  LedgerMember({
    required this.userId,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    this.lastAccessedAt,
  });
  
  factory LedgerMember.fromJson(Map<String, dynamic> json) {
    return LedgerMember(
      userId: json['user_id'],
      name: json['name'] ?? json['user_name'] ?? '',
      email: json['email'] ?? json['user_email'] ?? '',
      avatar: json['avatar'] ?? json['user_avatar'],
      role: LedgerRole.fromString(json['role']),
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
      joinedAt: DateTime.parse(json['joined_at']),
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'avatar': avatar,
      'role': role.value,
      'permissions': permissions,
      'joined_at': joinedAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
    };
  }
}