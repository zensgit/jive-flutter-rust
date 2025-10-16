import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/ui/components/budget/budget_progress.dart';

void main() {
  testWidgets('BudgetProgress displays amounts and percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BudgetProgress(
            category: 'Groceries',
            budgeted: 1000.0,
            spent: 250.0,
          ),
        ),
      ),
    );

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('¥250.00 / ¥1000.00'), findsOneWidget);
    // Percentage 25%
    expect(find.text('25%'), findsOneWidget);
  });
}

