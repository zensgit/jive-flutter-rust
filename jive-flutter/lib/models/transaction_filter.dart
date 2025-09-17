import 'transaction.dart';

/// 交易筛选数据
class TransactionFilterData {
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type;
  final List<TransactionType> types; // 多个类型筛选
  final String? category;
  final List<String> categories; // 多个分类筛选
  final String? accountId;
  final List<String> accounts; // 多个账户筛选
  final double? minAmount;
  final double? maxAmount;
  final String? searchText;
  final List<String> tags;
  final bool? isPending;
  final bool? isReconciled;
  final String? sortBy;
  final bool ascending;

  const TransactionFilterData({
    this.startDate,
    this.endDate,
    this.type,
    this.types = const [],
    this.category,
    this.categories = const [],
    this.accountId,
    this.accounts = const [],
    this.minAmount,
    this.maxAmount,
    this.searchText,
    this.tags = const [],
    this.isPending,
    this.isReconciled,
    this.sortBy = 'date',
    this.ascending = false,
  });

  TransactionFilterData copyWith({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    List<TransactionType>? types,
    String? category,
    List<String>? categories,
    String? accountId,
    List<String>? accounts,
    double? minAmount,
    double? maxAmount,
    String? searchText,
    List<String>? tags,
    bool? isPending,
    bool? isReconciled,
    String? sortBy,
    bool? ascending,
  }) {
    return TransactionFilterData(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      types: types ?? this.types,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      accountId: accountId ?? this.accountId,
      accounts: accounts ?? this.accounts,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchText: searchText ?? this.searchText,
      tags: tags ?? this.tags,
      isPending: isPending ?? this.isPending,
      isReconciled: isReconciled ?? this.isReconciled,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (type != null) 'type': type!.value,
      if (types.isNotEmpty) 'types': types.map((t) => t.value).toList(),
      if (category != null) 'category': category,
      if (categories.isNotEmpty) 'categories': categories,
      if (accountId != null) 'account_id': accountId,
      if (accounts.isNotEmpty) 'accounts': accounts,
      if (minAmount != null) 'min_amount': minAmount,
      if (maxAmount != null) 'max_amount': maxAmount,
      if (searchText != null) 'search': searchText,
      if (tags.isNotEmpty) 'tags': tags,
      if (isPending != null) 'is_pending': isPending,
      if (isReconciled != null) 'is_reconciled': isReconciled,
      'sort_by': sortBy,
      'ascending': ascending,
    };
  }

  factory TransactionFilterData.fromJson(Map<String, dynamic> json) {
    return TransactionFilterData(
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      type: json['type'] != null
          ? TransactionType.fromString(json['type'])
          : null,
      types: json['types'] != null
          ? (json['types'] as List)
              .map((t) => TransactionType.fromString(t))
              .toList()
          : const [],
      category: json['category'],
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : const [],
      accountId: json['account_id'],
      accounts: json['accounts'] != null
          ? List<String>.from(json['accounts'])
          : const [],
      minAmount: json['min_amount']?.toDouble(),
      maxAmount: json['max_amount']?.toDouble(),
      searchText: json['search'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : const [],
      isPending: json['is_pending'],
      isReconciled: json['is_reconciled'],
      sortBy: json['sort_by'] ?? 'date',
      ascending: json['ascending'] ?? false,
    );
  }
}
