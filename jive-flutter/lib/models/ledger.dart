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

// 账本统计信息
class LedgerStatistics {
  final String ledgerId;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int transactionCount;
  final int accountCount;
  final DateTime? lastTransactionDate;
  final Map<String, double>? categoryBreakdown;

  LedgerStatistics({
    required this.ledgerId,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.transactionCount,
    required this.accountCount,
    this.lastTransactionDate,
    this.categoryBreakdown,
  });

  factory LedgerStatistics.fromJson(Map<String, dynamic> json) {
    return LedgerStatistics(
      ledgerId: json['ledger_id'],
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      accountCount: json['account_count'] ?? 0,
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
      categoryBreakdown: json['category_breakdown'] != null
          ? Map<String, double>.from(json['category_breakdown'])
          : null,
    );
  }
}

// 账本成员
class LedgerMember {
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userAvatar;
  final String role; // owner, editor, viewer
  final DateTime joinedAt;

  LedgerMember({
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userAvatar,
    required this.role,
    required this.joinedAt,
  });

  factory LedgerMember.fromJson(Map<String, dynamic> json) {
    return LedgerMember(
      userId: json['user_id'],
      userName: json['user_name'],
      userEmail: json['user_email'],
      userAvatar: json['user_avatar'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}