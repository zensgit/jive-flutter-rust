
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/providers/transaction_provider.dart';
import 'package:jive_money/services/api/transaction_service.dart';
import 'package:jive_money/ui/components/transactions/transaction_list.dart';
import 'package:jive_money/ui/components/cards/transaction_card.dart';

class _DummyTransactionService extends TransactionService {}

class _TestController extends TransactionController {
  _TestController({
    TransactionGrouping grouping = TransactionGrouping.category,
    Set<String> collapsed = const {},
  }) : super(_DummyTransactionService()) {
    // Skip network on init
    state = state.copyWith(
      transactions: const [],
      filteredTransactions: const [],
      isLoading: false,
      error: null,
      totalCount: 0,
      totalIncome: 0.0,
      totalExpense: 0.0,
      grouping: grouping,
      groupCollapse: collapsed,
    );
  }

  @override
  Future<void> loadTransactions() async {
    // no-op in tests
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionList grouping widget', () {
    testWidgets('category grouping renders and collapses', (tester) async {
      final transactions = <Transaction>[
        Transaction(
          id: 't1',
          type: TransactionType.expense,
          amount: 12.34,
          description: 'Lunch',
          category: '餐饮',
          date: DateTime.now(),
        ),
        Transaction(
          id: 't2',
          type: TransactionType.expense,
          amount: 20,
          description: 'Dinner',
          category: '餐饮',
          date: DateTime.now(),
        ),
        Transaction(
          id: 't3',
          type: TransactionType.income,
          amount: 100,
          description: 'Salary',
          category: '工资',
          date: DateTime.now(),
        ),
      ];

      final controller = _TestController(
        grouping: TransactionGrouping.category,
        collapsed: {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionControllerProvider
                .overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TransactionList(
                transactions: transactions,
                showSearchBar: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render two group headers: 餐饮 and 工资
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('工资'), findsOneWidget);

      // Count rendered TransactionCard tiles initially (3)
      expect(find.byType(TransactionCard), findsNWidgets(3));

      // Tap to collapse 食品组 (餐饮)
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      // Now only 工资那组的 1 条应可见
      expect(find.byType(TransactionCard), findsNWidgets(1));
    });
  });
}
