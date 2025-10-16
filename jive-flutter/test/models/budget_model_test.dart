import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/models/budget.dart';

void main() {
  test('BudgetReport parses money as string', () {
    final json = {
      'period': '2025-01',
      'total_budgeted': '2000.00',
      'total_spent': '500.00',
      'total_remaining': '1500.00',
      'overall_percentage': 25.0,
      'unbudgeted_spending': '50.00',
      'budget_summaries': [
        {
          'budget_name': 'Groceries',
          'budgeted': '1000.00',
          'spent': '200.00',
          'remaining': '800.00',
          'percentage': 20.0,
        }
      ],
      'generated_at': '2025-01-31T23:59:59Z'
    };

    final report = BudgetReport.fromJson(json);
    expect(report.totalBudgeted, 2000.0);
    expect(report.totalSpent, 500.0);
    expect(report.totalRemaining, 1500.0);
    expect(report.unbudgetedSpending, 50.0);
    expect(report.budgetSummaries.first.budgeted, 1000.0);
    expect(report.overallPercentage, 25.0);
  });

  test('BudgetProgressModel parses money as string', () {
    final json = {
      'budget_id': '00000000-0000-0000-0000-000000000000',
      'budget_name': 'Groceries',
      'period': '2025-01-01 - 2025-01-31',
      'budgeted_amount': '1000.00',
      'spent_amount': '123.45',
      'remaining_amount': '876.55',
      'percentage_used': 12.345,
      'days_remaining': 10,
      'average_daily_spend': '4.00',
      'projected_overspend': '0.00',
      'categories': [
        {
          'category_id': '11111111-1111-1111-1111-111111111111',
          'category_name': 'Food',
          'amount_spent': '100.00',
          'transaction_count': 3
        }
      ]
    };

    final progress = BudgetProgressModel.fromJson(json);
    expect(progress.budgetedAmount, 1000.0);
    expect(progress.spentAmount, 123.45);
    expect(progress.remainingAmount, 876.55);
    expect(progress.averageDailySpend, 4.0);
    expect(progress.projectedOverspend, 0.0);
    expect(progress.categories.first.amountSpent, 100.0);
  });
}

