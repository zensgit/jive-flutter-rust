
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
  _TestController(Ref ref, {
    TransactionGrouping grouping = TransactionGrouping.category,
    Set<String> collapsed = const {},
  }) : super(ref, _DummyTransactionService()) {
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
            transactionControllerProvider.overrideWith((ref) => _TestController(ref, grouping: grouping, collapsed: {})),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TransactionList(
                transactions: transactions,
                showSearchBar: false,
                // Inject a simple formatter to avoid provider dependencies
                formatAmount: (v) => v.toStringAsFixed(2),
                transactionItemBuilder: (t) => ListTile(
                  title: Text(t.description),
                  subtitle: Text(t.category ?? '未分类'),
                ),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Should render group headers that include 餐饮 and 工资
      expect(find.text('餐饮'), findsWidgets);
      expect(find.text('工资'), findsWidgets);

      // Our test injects a ListTile as item widget; initially three items are visible
      expect(find.byType(ListTile), findsNWidgets(3));

      // Tap to collapse 餐饮 组（点击其 InkWell 头部）
      final headerTapTarget = find
          .ancestor(of: find.text('餐饮'), matching: find.byType(InkWell))
          .first;
      await tester.tap(headerTapTarget);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Now only 工资那组的 1 条应可见
      expect(find.byType(ListTile), findsNWidgets(1));
    });
  });
}
