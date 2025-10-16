import 'package:jive_money/utils/json_number.dart';

class BudgetSummary {
  final String budgetName;
  final double budgeted;
  final double spent;
  final double remaining;
  final double percentage;

  const BudgetSummary({
    required this.budgetName,
    required this.budgeted,
    required this.spent,
    required this.remaining,
    required this.percentage,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      budgetName: json['budget_name'] ?? json['budgetName'] ?? '',
      budgeted: asDoubleOrZero(json['budgeted']),
      spent: asDoubleOrZero(json['spent']),
      remaining: asDoubleOrZero(json['remaining']),
      percentage: asDouble(json['percentage']) ?? 0.0,
    );
  }
}

class BudgetReport {
  final String period;
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;
  final double overallPercentage;
  final List<BudgetSummary> budgetSummaries;
  final double unbudgetedSpending;
  final DateTime? generatedAt;

  const BudgetReport({
    required this.period,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overallPercentage,
    required this.budgetSummaries,
    required this.unbudgetedSpending,
    required this.generatedAt,
  });

  factory BudgetReport.fromJson(Map<String, dynamic> json) {
    final summaries = (json['budget_summaries'] ?? json['budgetSummaries'] ?? []) as List;
    return BudgetReport(
      period: json['period'] ?? '',
      totalBudgeted: asDoubleOrZero(json['total_budgeted'] ?? json['totalBudgeted']),
      totalSpent: asDoubleOrZero(json['total_spent'] ?? json['totalSpent']),
      totalRemaining: asDoubleOrZero(json['total_remaining'] ?? json['totalRemaining']),
      overallPercentage: asDouble(json['overall_percentage'] ?? json['overallPercentage']) ?? 0.0,
      budgetSummaries: summaries.map((e) => BudgetSummary.fromJson(e as Map<String, dynamic>)).toList(),
      unbudgetedSpending: asDoubleOrZero(json['unbudgeted_spending'] ?? json['unbudgetedSpending']),
      generatedAt: _parseDateTime(json['generated_at'] ?? json['generatedAt']),
    );
  }
}

class CategorySpending {
  final String categoryId;
  final String categoryName;
  final double amountSpent;
  final int transactionCount;

  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amountSpent,
    required this.transactionCount,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) {
    return CategorySpending(
      categoryId: (json['category_id'] ?? json['categoryId'] ?? '').toString(),
      categoryName: json['category_name'] ?? json['categoryName'] ?? '',
      amountSpent: asDoubleOrZero(json['amount_spent'] ?? json['amountSpent']),
      transactionCount: asInt(json['transaction_count'] ?? json['transactionCount']) ?? 0,
    );
  }
}

class BudgetProgressModel {
  final String budgetId;
  final String budgetName;
  final String period;
  final double budgetedAmount;
  final double spentAmount;
  final double remainingAmount;
  final double percentageUsed;
  final int daysRemaining;
  final double averageDailySpend;
  final double? projectedOverspend;
  final List<CategorySpending> categories;

  const BudgetProgressModel({
    required this.budgetId,
    required this.budgetName,
    required this.period,
    required this.budgetedAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.daysRemaining,
    required this.averageDailySpend,
    required this.projectedOverspend,
    required this.categories,
  });

  factory BudgetProgressModel.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] ?? []) as List;
    return BudgetProgressModel(
      budgetId: (json['budget_id'] ?? json['budgetId'] ?? '').toString(),
      budgetName: json['budget_name'] ?? json['budgetName'] ?? '',
      period: json['period'] ?? '',
      budgetedAmount: asDoubleOrZero(json['budgeted_amount'] ?? json['budgetedAmount']),
      spentAmount: asDoubleOrZero(json['spent_amount'] ?? json['spentAmount']),
      remainingAmount: asDoubleOrZero(json['remaining_amount'] ?? json['remainingAmount']),
      percentageUsed: asDouble(json['percentage_used'] ?? json['percentageUsed']) ?? 0.0,
      daysRemaining: asInt(json['days_remaining'] ?? json['daysRemaining']) ?? 0,
      averageDailySpend: asDoubleOrZero(json['average_daily_spend'] ?? json['averageDailySpend']),
      projectedOverspend: asDouble(json['projected_overspend'] ?? json['projectedOverspend']),
      categories: cats.map((e) => CategorySpending.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    return DateTime.tryParse(v);
  }
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v);
  }
  return null;
}

