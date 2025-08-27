import 'transaction.dart';

/// 交易筛选数据
class TransactionFilterData {
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type;
  final String? category;
  final String? accountId;
  final double? minAmount;
  final double? maxAmount;
  final String? searchText;
  final List<String>? tags;
  final bool? isPending;
  final bool? isReconciled;
  final String? sortBy;
  final bool ascending;
  
  const TransactionFilterData({
    this.startDate,
    this.endDate,
    this.type,
    this.category,
    this.accountId,
    this.minAmount,
    this.maxAmount,
    this.searchText,
    this.tags,
    this.isPending,
    this.isReconciled,
    this.sortBy = 'date',
    this.ascending = false,
  });
  
  TransactionFilterData copyWith({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    String? category,
    String? accountId,
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
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
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
      if (category != null) 'category': category,
      if (accountId != null) 'account_id': accountId,
      if (minAmount != null) 'min_amount': minAmount,
      if (maxAmount != null) 'max_amount': maxAmount,
      if (searchText != null) 'search': searchText,
      if (tags != null) 'tags': tags,
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
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      type: json['type'] != null 
          ? TransactionType.fromString(json['type']) 
          : null,
      category: json['category'],
      accountId: json['account_id'],
      minAmount: json['min_amount']?.toDouble(),
      maxAmount: json['max_amount']?.toDouble(),
      searchText: json['search'],
      tags: json['tags'] != null 
          ? List<String>.from(json['tags']) 
          : null,
      isPending: json['is_pending'],
      isReconciled: json['is_reconciled'],
      sortBy: json['sort_by'] ?? 'date',
      ascending: json['ascending'] ?? false,
    );
  }
}