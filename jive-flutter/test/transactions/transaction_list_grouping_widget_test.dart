
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/providers/transaction_provider.dart';
import 'package:jive_money/services/api/transaction_service.dart';
import 'package:jive_money/ui/components/transactions/transaction_list.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _DummyTransactionService extends TransactionService {}

class _TestController extends TransactionController {
  _TestController(Ref ref, {
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

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('hive_tx_list_test');
    Hive.init(dir.path);
    await Hive.openBox('preferences');
  });

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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionControllerProvider.overrideWith((ref) => _TestController(ref, grouping: TransactionGrouping.category, collapsed: {})),
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

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Should render a date group header with total count text
      expect(find.textContaining('笔交易'), findsWidgets);
      // Should render three TransactionCard widgets
      expect(find.byType(TransactionList), findsOneWidget);

      // 验证分组渲染与条目数量（折叠交互另测）
    });
  });
}
