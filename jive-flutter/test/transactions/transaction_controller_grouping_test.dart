
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/providers/transaction_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/services/api/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dummy service – will never be used because we override loadTransactions.
class _DummyTransactionService extends TransactionService {}

/// Test controller that skips network loading on init.
class _TestTransactionController extends TransactionController {
  _TestTransactionController(Ref ref) : super(ref, _DummyTransactionService());

  @override
  Future<void> loadTransactions() async {
    // Immediately set an empty, non-loading state to avoid network calls.
    state = state.copyWith(
      transactions: const [],
      filteredTransactions: const [],
      isLoading: false,
      error: null,
      totalCount: 0,
      totalIncome: 0.0,
      totalExpense: 0.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionController grouping & collapse persistence', () {
    setUp(() async {
      // Clear any previous mock values before each test.
      SharedPreferences.setMockInitialValues({});
    });

    test('setGrouping persists to SharedPreferences', () async {
      final container = ProviderContainer(overrides: [
        transactionControllerProvider.overrideWith((ref) => _TestTransactionController(ref)),
      ]);
      final controller = container.read(transactionControllerProvider.notifier);

      // Default should be date
      expect(controller.state.grouping, TransactionGrouping.date);

      controller.setGrouping(TransactionGrouping.category);

      // Allow async persistence to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tx_grouping'), 'category');
      expect(controller.state.grouping, TransactionGrouping.category);
    });

    test('toggleGroupCollapse persists collapsed keys', () async {
      final container = ProviderContainer(overrides: [
        transactionControllerProvider.overrideWith((ref) => _TestTransactionController(ref)),
      ]);
      final controller = container.read(transactionControllerProvider.notifier);
      const key = 'category:未分类';

      // Toggle on (collapse)
      controller.toggleGroupCollapse(key);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.groupCollapse.contains(key), isTrue);

      var prefs = await SharedPreferences.getInstance();
      final stored1 = prefs.getStringList('tx_group_collapse') ?? <String>[];
      expect(stored1.contains(key), isTrue);

      // Toggle off (expand)
      controller.toggleGroupCollapse(key);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.state.groupCollapse.contains(key), isFalse);

      prefs = await SharedPreferences.getInstance();
      final stored2 = prefs.getStringList('tx_group_collapse') ?? <String>[];
      expect(stored2.contains(key), isFalse);
    });
  });
}
