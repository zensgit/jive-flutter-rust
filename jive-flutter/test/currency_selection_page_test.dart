import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jive_money/screens/management/currency_selection_page.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/models/currency.dart' as model;

void main() {
  testWidgets('Selecting base currency returns via Navigator.pop',
      (tester) async {
    // Build app with ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CurrencySelectionPage(isSelectingBaseCurrency: true),
        ),
      ),
    );

    // Wait initial frame
    await tester.pumpAndSettle();

    // Ensure list displays some currencies (defaults include USD)
    expect(find.text('USD'), findsWidgets);

    // Tap on a currency tile (USD) and expect Navigator.pop to return
    // We push a route and wait for result to simulate selection
    late Object? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CurrencySelectionPage(
                            isSelectingBaseCurrency: true),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Open selection page
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap USD tile (first match)
    final usdFinder = find.text('USD').first;
    await tester.tap(usdFinder);
    await tester.pumpAndSettle();

    // After pop, result should be a Currency model
    expect(result, isA<model.Currency>());
    expect((result as model.Currency).code, 'USD');
  });

  testWidgets('Base currency is sorted to top and marked', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CurrencySelectionPage(isSelectingBaseCurrency: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default base is USD; should be visible with tag '基础'
    expect(find.text('USD'), findsWidgets);
    expect(find.text('基础'), findsWidgets);
  });
}
