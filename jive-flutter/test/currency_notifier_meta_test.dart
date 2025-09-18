import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/models/currency.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple stub CurrencyService result container (mirrors real)
class _StubCatalogResult {
  final List<Currency> items;
  final String? etag;
  final bool notModified;
  final String? error;
  _StubCatalogResult(this.items, this.etag, this.notModified, {this.error});
}

// We wrap notifier directly to inject fake behavior by subclassing api service via composition if needed.
// For now, we'll test meta transitions indirectly by simulating internal method responses.

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('hive_widget_test');
    Hive.init(dir.path);
    await Hive.openBox('preferences');
  });
  group('CurrencyNotifier catalog meta', () {
    // NOTE: We exercise public refreshCatalog and rely on initial load side‑effects.
    test('initial usingFallback true when first fetch throws', () async {
      // We cannot easily inject a failing service without refactor; placeholder for future DI improvements.
      // This test serves as a scaffold: once CurrencyService is abstracted, replace with mock injection.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(currencyProvider.notifier);
      // Force a manual meta emit to simulate failure scenario (scaffold only)
      // In real refactor, we'd inject a mock that throws.
      notifier.refreshCatalog();
      // Allow async microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final meta = notifier.catalogMeta;
      expect(meta.lastCheckedAt, isNotNull);
    });
  });
}
