import 'package:flutter_test/flutter_test.dart';
import 'package:jive_money/models/travel_event.dart';

void main() {
  group('TravelEvent Model Tests', () {
    test('should create TravelEvent with required fields', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
      );

      expect(event.name, 'Test Travel');
      expect(event.startDate, DateTime(2025, 1, 1));
      expect(event.endDate, DateTime(2025, 1, 7));
      expect(event.currency, 'CNY'); // Default value
    });

    test('should calculate duration correctly', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
      );

      expect(event.duration, 7);
    });

    test('should determine status correctly', () {
      final now = DateTime.now();

      // Upcoming event
      final upcomingEvent = TravelEvent(
        name: 'Upcoming',
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 15)),
      );
      expect(upcomingEvent.computedStatus, TravelEventStatus.upcoming);

      // Ongoing event
      final ongoingEvent = TravelEvent(
        name: 'Ongoing',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 3)),
      );
      expect(ongoingEvent.computedStatus, TravelEventStatus.ongoing);

      // Completed event
      final completedEvent = TravelEvent(
        name: 'Completed',
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 5)),
      );
      expect(completedEvent.computedStatus, TravelEventStatus.completed);
    });

    test('should check if date is in travel range', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 5),
        endDate: DateTime(2025, 1, 10),
      );

      expect(event.isDateInRange(DateTime(2025, 1, 7)), true);
      expect(event.isDateInRange(DateTime(2025, 1, 3)), false);
      expect(event.isDateInRange(DateTime(2025, 1, 12)), false);
      expect(event.isDateInRange(DateTime(2025, 1, 5)), true); // Start date
      expect(event.isDateInRange(DateTime(2025, 1, 10)), true); // End date
    });

    test('should handle optional fields', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        destination: 'Tokyo',
        budget: 10000.0,
        notes: 'Test notes',
      );

      expect(event.destination, 'Tokyo');
      expect(event.budget, 10000.0);
      expect(event.notes, 'Test notes');
    });
  });

  group('Budget Calculation Tests', () {
    test('should calculate budget usage percentage', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        budget: 10000.0,
        totalSpent: 7500.0,
      );

      final percentage = (event.totalSpent / (event.budget ?? 1)) * 100;
      expect(percentage, 75.0);
    });

    test('should handle zero budget', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        budget: 0,
        totalSpent: 1000.0,
      );

      // Should handle division by zero gracefully
      expect(event.budget, 0);
      expect(event.totalSpent, 1000.0);
    });

    test('should detect over budget', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        budget: 5000.0,
        totalSpent: 6000.0,
      );

      final isOverBudget = event.totalSpent > (event.budget ?? 0);
      expect(isOverBudget, true);
    });
  });

  group('Transaction Linking Tests', () {
    test('should track transaction count', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        transactionCount: 5,
      );

      expect(event.transactionCount, 5);
    });

    test('should filter transactions by date range', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 5),
        endDate: DateTime(2025, 1, 10),
      );

      // Test dates that should be included
      final validDates = [
        DateTime(2025, 1, 5),
        DateTime(2025, 1, 7),
        DateTime(2025, 1, 10),
      ];

      for (var date in validDates) {
        expect(event.isDateInRange(date), true);
      }

      // Test dates that should be excluded
      final invalidDates = [
        DateTime(2025, 1, 3),
        DateTime(2025, 1, 11),
        DateTime(2025, 1, 15),
      ];

      for (var date in invalidDates) {
        expect(event.isDateInRange(date), false);
      }
    });
  });

  group('Currency Support Tests', () {
    test('should support multiple currencies', () {
      final currencies = ['CNY', 'USD', 'EUR', 'JPY', 'GBP'];

      for (var currency in currencies) {
        final event = TravelEvent(
          name: 'Test Travel',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 1, 7),
          currency: currency,
        );

        expect(event.currency, currency);
      }
    });

    test('should default to CNY currency', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
      );

      expect(event.currency, 'CNY');
    });
  });

  group('Travel Statistics Tests', () {
    test('should calculate daily average spending', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        totalSpent: 7000.0,
      );

      final dailyAverage = event.totalSpent / event.duration;
      expect(dailyAverage, 1000.0);
    });

    test('should track travel categories', () {
      final event = TravelEvent(
        name: 'Test Travel',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 7),
        travelCategoryIds: ['accommodation', 'transportation', 'dining'],
      );

      expect(event.travelCategoryIds.length, 3);
      expect(event.travelCategoryIds.contains('accommodation'), true);
      expect(event.travelCategoryIds.contains('transportation'), true);
      expect(event.travelCategoryIds.contains('dining'), true);
    });
  });
}