import 'package:flutter/material.dart';

/// 交易类型枚举
enum TransactionType {
  income('income', '收入', Icons.arrow_downward, Colors.green),
  expense('expense', '支出', Icons.arrow_upward, Colors.red),
  transfer('transfer', '转账', Icons.swap_horiz, Colors.blue);
  
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  
  const TransactionType(this.value, this.label, this.icon, this.color);
  
  static TransactionType fromString(String? value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.expense,
    );
  }
}

/// 交易模型
class Transaction {
  final String? id;
  final TransactionType type;
  final double amount;
  final String description;
  final String? note;
  final String? category;
  final DateTime date;
  final String? accountId;
  final String? toAccountId; // 转账目标账户
  final String? ledgerId;
  final String? payee;
  final List<String>? tags;
  final List<TransactionAttachment>? attachments;
  final bool isRecurring;
  final String? recurringId;
  final bool isPending;
  final bool isReconciled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  
  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.note,
    this.category,
    required this.date,
    this.accountId,
    this.toAccountId,
    this.ledgerId,
    this.payee,
    this.tags,
    this.attachments,
    this.isRecurring = false,
    this.recurringId,
    this.isPending = false,
    this.isReconciled = false,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });
  
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString(),
      type: TransactionType.fromString(json['type']),
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      note: json['note'],
      category: json['category'],
      date: DateTime.parse(json['date']),
      accountId: json['account_id']?.toString(),
      toAccountId: json['to_account_id']?.toString(),
      ledgerId: json['ledger_id']?.toString(),
      payee: json['payee'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => TransactionAttachment.fromJson(a))
              .toList()
          : null,
      isRecurring: json['is_recurring'] ?? false,
      recurringId: json['recurring_id']?.toString(),
      isPending: json['is_pending'] ?? false,
      isReconciled: json['is_reconciled'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      metadata: json['metadata'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type.value,
      'amount': amount,
      'description': description,
      'note': note,
      'category': category,
      'date': date.toIso8601String(),
      'account_id': accountId,
      'to_account_id': toAccountId,
      'ledger_id': ledgerId,
      'payee': payee,
      'tags': tags,
      'attachments': attachments?.map((a) => a.toJson()).toList(),
      'is_recurring': isRecurring,
      'recurring_id': recurringId,
      'is_pending': isPending,
      'is_reconciled': isReconciled,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? description,
    String? note,
    String? category,
    DateTime? date,
    String? accountId,
    String? toAccountId,
    String? ledgerId,
    String? payee,
    List<String>? tags,
    List<TransactionAttachment>? attachments,
    bool? isRecurring,
    String? recurringId,
    bool? isPending,
    bool? isReconciled,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      note: note ?? this.note,
      category: category ?? this.category,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      ledgerId: ledgerId ?? this.ledgerId,
      payee: payee ?? this.payee,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
      isPending: isPending ?? this.isPending,
      isReconciled: isReconciled ?? this.isReconciled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// 获取显示金额（带符号）
  String get displayAmount {
    // Legacy helper; UI should prefer currencyProvider.formatCurrency
    final sign = type == TransactionType.expense ? '-' : type == TransactionType.income ? '+' : '';
    return '$sign${amount.toStringAsFixed(2)}';
  }
  
  /// 获取图标
  IconData get icon => type.icon;
  
  /// 获取颜色
  Color get color => type.color;
  
  /// 获取分类图标
  IconData getCategoryIcon() {
    if (category == null) return Icons.category;
    
    final lowerCategory = category!.toLowerCase();
    if (lowerCategory.contains('餐') || lowerCategory.contains('食')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('交通') || lowerCategory.contains('车')) {
      return Icons.directions_car;
    } else if (lowerCategory.contains('购物')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('娱乐')) {
      return Icons.movie;
    } else if (lowerCategory.contains('医')) {
      return Icons.medical_services;
    } else if (lowerCategory.contains('教育') || lowerCategory.contains('学')) {
      return Icons.school;
    } else if (lowerCategory.contains('住') || lowerCategory.contains('房')) {
      return Icons.home;
    } else if (lowerCategory.contains('工资') || lowerCategory.contains('薪')) {
      return Icons.account_balance_wallet;
    }
    
    return Icons.category;
  }
}

/// 交易附件
class TransactionAttachment {
  final String? id;
  final String fileName;
  final String fileType;
  final String? fileUrl;
  final int? fileSize;
  final DateTime? uploadedAt;
  
  TransactionAttachment({
    this.id,
    required this.fileName,
    required this.fileType,
    this.fileUrl,
    this.fileSize,
    this.uploadedAt,
  });
  
  factory TransactionAttachment.fromJson(Map<String, dynamic> json) {
    return TransactionAttachment(
      id: json['id']?.toString(),
      fileName: json['file_name'] ?? '',
      fileType: json['file_type'] ?? '',
      fileUrl: json['file_url'],
      fileSize: json['file_size'],
      uploadedAt: json['uploaded_at'] != null 
          ? DateTime.parse(json['uploaded_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'file_name': fileName,
      'file_type': fileType,
      'file_url': fileUrl,
      'file_size': fileSize,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }
}

/// 交易分类
class TransactionCategory {
  final String? id;
  final String name;
  final String? parentId;
  final IconData icon;
  final Color color;
  final TransactionType type;
  final int sortOrder;
  final bool isSystem;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  TransactionCategory({
    this.id,
    required this.name,
    this.parentId,
    required this.icon,
    required this.color,
    required this.type,
    this.sortOrder = 0,
    this.isSystem = false,
    this.createdAt,
    this.updatedAt,
  });
  
  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      parentId: json['parent_id']?.toString(),
      // 避免运行时根据 codePoint 构造 IconData，使用常量映射或默认常量
      icon: Icons.category,
      color: Color(json['color'] ?? Colors.grey.value),
      type: TransactionType.fromString(json['type']),
      sortOrder: json['sort_order'] ?? 0,
      isSystem: json['is_system'] ?? false,
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
      'parent_id': parentId,
      'icon': icon.codePoint,
      'color': color.value,
      'type': type.value,
      'sort_order': sortOrder,
      'is_system': isSystem,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// 定期交易
class ScheduledTransaction {
  final String? id;
  final Transaction template;
  final RecurrencePeriod period;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextRunDate;
  final int? occurrences;
  final int executedCount;
  final bool isActive;
  final bool autoConfirm;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  ScheduledTransaction({
    this.id,
    required this.template,
    required this.period,
    this.interval = 1,
    required this.startDate,
    this.endDate,
    this.nextRunDate,
    this.occurrences,
    this.executedCount = 0,
    this.isActive = true,
    this.autoConfirm = false,
    this.createdAt,
    this.updatedAt,
  });
  
  factory ScheduledTransaction.fromJson(Map<String, dynamic> json) {
    return ScheduledTransaction(
      id: json['id']?.toString(),
      template: Transaction.fromJson(json['template']),
      period: RecurrencePeriod.fromString(json['period']),
      interval: json['interval'] ?? 1,
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      nextRunDate: json['next_run_date'] != null 
          ? DateTime.parse(json['next_run_date']) 
          : null,
      occurrences: json['occurrences'],
      executedCount: json['executed_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      autoConfirm: json['auto_confirm'] ?? false,
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
      'template': template.toJson(),
      'period': period.value,
      'interval': interval,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_run_date': nextRunDate?.toIso8601String(),
      'occurrences': occurrences,
      'executed_count': executedCount,
      'is_active': isActive,
      'auto_confirm': autoConfirm,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// 重复周期
enum RecurrencePeriod {
  daily('daily', '每天'),
  weekly('weekly', '每周'),
  monthly('monthly', '每月'),
  yearly('yearly', '每年');
  
  final String value;
  final String label;
  
  const RecurrencePeriod(this.value, this.label);
  
  static RecurrencePeriod fromString(String? value) {
    return RecurrencePeriod.values.firstWhere(
      (period) => period.value == value,
      orElse: () => RecurrencePeriod.monthly,
    );
  }
}
