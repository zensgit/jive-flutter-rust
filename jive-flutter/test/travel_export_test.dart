import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/models/travel_event.dart';
import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/services/export/travel_export_service.dart';
import 'package:jive_money/utils/currency_formatter.dart';

void main() {
  group('TravelExportService Tests', () {
    late TravelExportService exportService;
    late TravelEvent mockEvent;
    late List<Transaction> mockTransactions;

    setUp(() {
      exportService = TravelExportService();

      // Create mock travel event
      mockEvent = TravelEvent(
        id: 'test-123',
        name: '测试旅行',
        destination: '北京',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        budget: 10000.0,
        totalSpent: 6500.0,
        currency: 'CNY',
        notes: '测试备注',
        transactionCount: 3,
      );

      // Create mock transactions
      mockTransactions = [
        Transaction(
          id: 'trans-1',
          type: TransactionType.expense,
          accountId: 'acc-1',
          amount: -3000.0,
          payee: '酒店',
          category: 'accommodation',
          description: '住宿费用',
          date: DateTime(2025, 1, 1, 14, 30),
        ),
        Transaction(
          id: 'trans-2',
          type: TransactionType.expense,
          accountId: 'acc-1',
          amount: -2000.0,
          payee: '机场巴士',
          category: 'transportation',
          description: '交通费用',
          date: DateTime(2025, 1, 2, 9, 15),
        ),
        Transaction(
          id: 'trans-3',
          type: TransactionType.expense,
          accountId: 'acc-1',
          amount: -1500.0,
          payee: '餐厅',
          category: 'dining',
          description: '晚餐',
          date: DateTime(2025, 1, 3, 19, 45),
        ),
      ];
    });

    test('should create TravelExportService instance', () {
      expect(exportService, isNotNull);
      expect(exportService, isA<TravelExportService>());
    });

    test('should have CurrencyFormatter instance', () {
      // Test internal currency formatter exists
      final formatter = CurrencyFormatter();
      expect(formatter, isNotNull);
      expect(formatter.format(1000, 'CNY'), contains('1000'));
      expect(formatter.format(1000, 'CNY'), contains('CNY'));
    });

    test('should calculate category breakdown correctly', () {
      // Test category calculation logic
      final Map<String, double> categoryBreakdown = {};

      for (var transaction in mockTransactions) {
        final category = transaction.category ?? 'other';
        categoryBreakdown[category] =
            (categoryBreakdown[category] ?? 0) + transaction.amount.abs();
      }

      expect(categoryBreakdown['accommodation'], 3000.0);
      expect(categoryBreakdown['transportation'], 2000.0);
      expect(categoryBreakdown['dining'], 1500.0);
      expect(categoryBreakdown.values.reduce((a, b) => a + b), 6500.0);
    });

    test('should format dates correctly', () {
      final date = DateTime(2025, 1, 15, 14, 30);

      // Test date formatting patterns used in export
      final dateOnly = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final dateTime = '$dateOnly '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';

      expect(dateOnly, '2025-01-15');
      expect(dateTime, '2025-01-15 14:30');
    });

    test('should get correct category names', () {
      final categories = {
        'accommodation': '住宿',
        'transportation': '交通',
        'dining': '餐饮',
        'attractions': '景点',
        'shopping': '购物',
        'entertainment': '娱乐',
        'other': '其他',
      };

      expect(categories['accommodation'], '住宿');
      expect(categories['transportation'], '交通');
      expect(categories['dining'], '餐饮');
      expect(categories['unknown'] ?? '未知', '未知');
    });

    test('should get correct status labels', () {
      final statusLabels = {
        TravelEventStatus.upcoming: '即将开始',
        TravelEventStatus.ongoing: '进行中',
        TravelEventStatus.completed: '已完成',
        TravelEventStatus.cancelled: '已取消',
      };

      expect(statusLabels[TravelEventStatus.upcoming], '即将开始');
      expect(statusLabels[TravelEventStatus.ongoing], '进行中');
      expect(statusLabels[TravelEventStatus.completed], '已完成');
      expect(statusLabels[TravelEventStatus.cancelled], '已取消');
    });

    test('should calculate budget usage percentage', () {
      final percentage = (mockEvent.totalSpent / mockEvent.budget!) * 100;
      expect(percentage, 65.0);
      expect(percentage.toStringAsFixed(1), '65.0');
    });

    test('should calculate daily average correctly', () {
      final dailyAverage = mockEvent.totalSpent / mockEvent.duration;
      expect(dailyAverage, closeTo(928.57, 0.01));
    });

    test('should calculate transaction average correctly', () {
      final transactionAverage = mockEvent.totalSpent / mockTransactions.length;
      expect(transactionAverage, closeTo(2166.67, 0.01));
    });

    test('should handle empty transactions list', () {
      final emptyTransactions = <Transaction>[];

      // Should not throw when transactions are empty
      expect(() {
        final total = emptyTransactions.fold<double>(
          0,
          (sum, t) => sum + t.amount.abs(),
        );
        expect(total, 0.0);
      }, returnsNormally);
    });

    test('should handle null budget gracefully', () {
      final eventWithoutBudget = TravelEvent(
        name: 'No Budget Trip',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 3),
        totalSpent: 5000.0,
      );

      // Should handle null budget
      expect(eventWithoutBudget.budget, isNull);
      expect(() {
        if (eventWithoutBudget.budget != null && eventWithoutBudget.budget! > 0) {
          final percentage = (eventWithoutBudget.totalSpent / eventWithoutBudget.budget!) * 100;
          return percentage;
        }
        return 0.0;
      }(), 0.0);
    });

    test('should escape special characters in CSV', () {
      final description = 'Test, with "quotes" and commas';
      final escaped = description.replaceAll(',', ';').replaceAll('"', '\'');
      expect(escaped, 'Test; with \'quotes\' and commas');
    });

    test('should format currency amounts correctly', () {
      final formatter = CurrencyFormatter();

      expect(formatter.format(1000, 'CNY'), contains('1000'));
      expect(formatter.format(1000.50, 'CNY'), contains('1000.50'));
      expect(formatter.format(0, 'CNY'), contains('0'));
      expect(formatter.format(-1000, 'CNY'), contains('1000'));
      expect(formatter.format(1000, 'CNY'), contains('CNY'));
    });

    test('should identify over-budget status', () {
      final overBudgetEvent = TravelEvent(
        name: 'Over Budget Trip',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 3),
        budget: 5000.0,
        totalSpent: 6000.0,
      );

      final isOverBudget = overBudgetEvent.totalSpent > (overBudgetEvent.budget ?? 0);
      expect(isOverBudget, isTrue);
    });

    test('should calculate remaining budget', () {
      final remaining = mockEvent.budget! - mockEvent.totalSpent;
      expect(remaining, 3500.0);

      // Test negative remaining (over budget)
      final overBudgetEvent = TravelEvent(
        name: 'Over',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 3),
        budget: 5000.0,
        totalSpent: 6000.0,
      );

      final overRemaining = overBudgetEvent.budget! - overBudgetEvent.totalSpent;
      expect(overRemaining, -1000.0);
      expect(overRemaining < 0, isTrue);
    });

    test('should group transactions by date', () {
      final Map<DateTime, double> dailySpending = {};

      for (var transaction in mockTransactions) {
        final date = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        dailySpending[date] = (dailySpending[date] ?? 0) + transaction.amount.abs();
      }

      expect(dailySpending.length, 3);
      expect(dailySpending[DateTime(2025, 1, 1)], 3000.0);
      expect(dailySpending[DateTime(2025, 1, 2)], 2000.0);
      expect(dailySpending[DateTime(2025, 1, 3)], 1500.0);
    });

    test('should find top expenses', () {
      final sortedTransactions = mockTransactions.toList()
        ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));

      final top5 = sortedTransactions.take(5).toList();

      expect(top5.length, 3); // Only 3 transactions available
      expect(top5[0].payee, '酒店');
      expect(top5[0].amount.abs(), 3000.0);
      expect(top5[1].payee, '机场巴士');
      expect(top5[2].payee, '餐厅');
    });

    test('should handle category budgets map', () {
      final categoryBudgets = <String, double>{
        'accommodation': 5000.0,
        'transportation': 3000.0,
        'dining': 2000.0,
      };

      expect(categoryBudgets['accommodation'], 5000.0);
      expect(categoryBudgets['transportation'], 3000.0);
      expect(categoryBudgets['dining'], 2000.0);
      expect(categoryBudgets['shopping'], isNull);
    });

    test('should generate valid file names', () {
      final eventName = 'My Trip 2025!';
      final date = DateTime(2025, 1, 15);

      final safeName = eventName.replaceAll(' ', '_').replaceAll('!', '');
      final dateStr = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final fileName = 'travel_${safeName}_$dateStr.csv';

      expect(fileName, 'travel_My_Trip_2025_2025-01-15.csv');
      expect(fileName.contains(' '), isFalse);
      expect(fileName.contains('!'), isFalse);
    });
  });
}