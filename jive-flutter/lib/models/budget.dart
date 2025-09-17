/// 预算模型
class Budget {
  final String id;
  final String name;
  final String? description;
  final double amount;
  final double spent;
  final String category;
  final DateTime startDate;
  final DateTime? endDate;
  final BudgetPeriod period;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.name,
    this.description,
    required this.amount,
    required this.spent,
    required this.category,
    required this.startDate,
    this.endDate,
    required this.period,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remaining => amount - spent;
  double get percentage => amount > 0 ? (spent / amount * 100) : 0;
  bool get isOverBudget => spent > amount;

  Budget copyWith({
    String? id,
    String? name,
    String? description,
    double? amount,
    double? spent,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    BudgetPeriod? period,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      period: period ?? this.period,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'amount': amount,
      'spent': spent,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'period': period.toJson(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      period: BudgetPeriod.fromJson(json['period'] as String),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// 预算周期
enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly,
  custom;

  String toJson() => name;

  static BudgetPeriod fromJson(String json) {
    return BudgetPeriod.values.firstWhere(
      (e) => e.name == json,
      orElse: () => BudgetPeriod.monthly,
    );
  }

  String get displayName {
    switch (this) {
      case BudgetPeriod.daily:
        return '每日';
      case BudgetPeriod.weekly:
        return '每周';
      case BudgetPeriod.monthly:
        return '每月';
      case BudgetPeriod.quarterly:
        return '每季度';
      case BudgetPeriod.yearly:
        return '每年';
      case BudgetPeriod.custom:
        return '自定义';
    }
  }
}
