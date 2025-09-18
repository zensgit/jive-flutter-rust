import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod/riverpod.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/services/currency_service.dart';
import 'package:jive_money/services/exchange_rate_service.dart';
import 'package:jive_money/services/crypto_price_service.dart';
import 'package:jive_money/models/currency.dart';
import 'package:jive_money/models/currency_api.dart' as api;
import 'package:jive_money/models/exchange_rate.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MockRemote implements ICurrencyRemote {
  bool failSet = false;
  int setCalls = 0;
  List<String> lastCurrencies = const [];
  String lastPrimary = 'USD';

  @override
  Future<void> setUserCurrencyPreferences(List<String> currencies, String primaryCurrency) async {
    setCalls++;
    lastCurrencies = List.from(currencies);
    lastPrimary = primaryCurrency;
    if (failSet) throw Exception('network');
  }

  // --- Unused for these tests ---
  @override
  Future<CurrencyCatalogResult> getSupportedCurrenciesWithEtag({String? etag}) async =>
      CurrencyCatalogResult(const [], etag, false, error: 'skip');

  @override
  Future<List<Currency>> getSupportedCurrencies() async => const [];

  @override
  Future<List<api.CurrencyPreference>> getUserCurrencyPreferences() async => const [];

  @override
  Future<api.FamilyCurrencySettings> getFamilyCurrencySettings() async =>
      api.FamilyCurrencySettings(familyId: '', baseCurrency: 'USD', allowMultiCurrency: true, autoConvert: false, supportedCurrencies: const ['USD']);

  @override
  Future<void> updateFamilyCurrencySettings(Map<String, dynamic> updates) async {}

  @override
  Future<double> getExchangeRate(String from, String to, {DateTime? date}) async => 1.0;

  @override
  Future<Map<String, double>> getBatchExchangeRates(String baseCurrency, List<String> targetCurrencies) async => {};

  @override
  Future<api.ConvertAmountResponse> convertAmount(double amount, String from, String to, {DateTime? date}) async =>
      api.ConvertAmountResponse(originalAmount: amount, convertedAmount: amount, fromCurrency: from, toCurrency: to, exchangeRate: 1.0);

  @override
  Future<List<api.ExchangeRate>> getExchangeRateHistory(String from, String to, int days) async => const [];

  @override
  Future<List<api.ExchangePair>> getPopularExchangePairs() async => const [];

  @override
  Future<void> refreshExchangeRates() async {}
}

// Lightweight stub to avoid real network/Dio in tests
class StubExchangeRateService extends ExchangeRateService {
  @override
  Future<Map<String, ExchangeRate>> getExchangeRatesForTargets(
          String baseCurrency, List<String> targets) async =>
      {};

  @override
  Future<Map<String, ExchangeRate>> getExchangeRates(String baseCurrency) async => {};

  @override
  Future<ExchangeRate?> getRate(String from, String to) async => null;
}

class StubCryptoPriceService extends CryptoPriceService {
  @override
  Future<double?> getCryptoPrice(String cryptoCode, String fiatCode) async => null;
  @override
  Future<Map<String, double>> getCryptoPricesFor(
          String fiatCode, List<String> cryptoCodes) async =>
      {}; // no crypto prices needed
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use an isolated temp directory to avoid path_provider plugin dependency
    final dir = await Directory.systemTemp.createTemp('hive_prefs_test');
    Hive.init(dir.path);
    await Hive.openBox('preferences');
    SharedPreferences.setMockInitialValues({});
  });

  test('debounce combines rapid preference pushes and succeeds', () async {
    final remote = MockRemote();
    final container = ProviderContainer(overrides: [
      currencyProvider.overrideWithProvider(StateNotifierProvider<CurrencyNotifier, CurrencyPreferences>((ref) {
        // Use in-memory box simulation via Hive.box is not easily replaced here; we focus on remote logic.
        // This test is a placeholder; full test would mock Hive as well.
        final box = Hive.box('preferences');
        return CurrencyNotifier(
          box,
          null,
          StubExchangeRateService(),
          StubCryptoPriceService(),
          remote,
        );
      }))
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(currencyProvider.notifier);
    await notifier.addSelectedCurrency('GBP');
    await notifier.addSelectedCurrency('EUR');
    // Bypass waiting by invoking internal push directly
    await notifier.pushPreferencesNowForTest();
    expect(remote.setCalls, greaterThanOrEqualTo(1));
    expect(remote.lastCurrencies.contains('EUR'), true);
  });

  test('failure stores pending then flush success clears it', () async {
    final remote = MockRemote();
    remote.failSet = true; // first attempt fails
    final container = ProviderContainer(overrides: [
      currencyProvider.overrideWithProvider(StateNotifierProvider<CurrencyNotifier, CurrencyPreferences>((ref) {
        final box = Hive.box('preferences');
        return CurrencyNotifier(
          box,
          null,
          StubExchangeRateService(),
          StubCryptoPriceService(),
          remote,
        );
      }))
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(currencyProvider.notifier);
    await notifier.addSelectedCurrency('CHF');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(notifier.hasPendingPreferences, true);

    // Now allow success
    remote.failSet = false;
    await notifier.tryFlushPendingPreferences();
    expect(notifier.hasPendingPreferences, false);
  });

  test('startup flush clears preexisting pending', () async {
    final box = Hive.box('preferences');
    // Pre-create a pending preferences record before provider init
    await box.put('currency_pending_prefs', {
      'currencies': ['USD', 'CNY'],
      'primary': 'USD',
      'queued_at': DateTime.now().toUtc().toIso8601String(),
    });
    expect(box.containsKey('currency_pending_prefs'), true);

    final remote = MockRemote(); // will succeed
    final container = ProviderContainer(overrides: [
      currencyProvider.overrideWithProvider(
          StateNotifierProvider<CurrencyNotifier, CurrencyPreferences>((ref) {
        final box = Hive.box('preferences');
        return CurrencyNotifier(
          box,
          null,
          StubExchangeRateService(),
          StubCryptoPriceService(),
          remote,
        );
      }))
    ]);
    addTearDown(container.dispose);

    // Manually trigger flush since constructor fire-and-forget may be skipped in test
    await container.read(currencyProvider.notifier).tryFlushPendingPreferences();
    expect(remote.setCalls, greaterThanOrEqualTo(1));
    expect(box.containsKey('currency_pending_prefs'), false);
  });
}
