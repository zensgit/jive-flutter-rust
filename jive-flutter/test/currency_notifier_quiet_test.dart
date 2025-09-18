import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/services/exchange_rate_service.dart';
import 'package:jive_money/services/crypto_price_service.dart';
import 'package:jive_money/services/currency_service.dart' as api;
import 'package:jive_money/models/currency_api.dart' as api_models;
import 'package:jive_money/models/exchange_rate.dart';

class _FakeExchangeRateService extends ExchangeRateService {
  int calls = 0;
  @override
  Future<Map<String, ExchangeRate>> getExchangeRatesForTargets(
      String base, List<String> targets) async {
    calls++;
    return {};
  }
}

class _FakeCryptoPriceService extends CryptoPriceService {
  int calls = 0;
  @override
  Future<Map<String, double>> getCryptoPricesFor(
      String vsCurrency, List<String> codes) async {
    calls++;
    return {};
  }
}

class _FakeCurrencyService extends api.CurrencyService {
  _FakeCurrencyService() : super(null);
  int catalogCalls = 0;
  int prefsCalls = 0;

  @override
  Future<api.CurrencyCatalogResult> getSupportedCurrenciesWithEtag({String? etag}) async {
    catalogCalls++;
    // Return empty catalog (forces fallback path inside notifier logic)
    return api.CurrencyCatalogResult(const [], null, false);
  }

  @override
  Future<List<api_models.CurrencyPreference>> getUserCurrencyPreferences() async {
    return [];
  }

  @override
  Future<void> setUserCurrencyPreferences(List<String> currencies, String primary) async {
    prefsCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box prefsBox;
  late _FakeExchangeRateService exchange;
  late _FakeCryptoPriceService crypto;
  late _FakeCurrencyService remote;
  late CurrencyNotifier notifier;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('hive_currency_quiet');
    Hive.init(dir.path);
    prefsBox = await Hive.openBox('preferences');
  });

  setUp(() {
    prefsBox.clear();
    exchange = _FakeExchangeRateService();
    crypto = _FakeCryptoPriceService();
    remote = _FakeCurrencyService();
    notifier = CurrencyNotifier(
      prefsBox,
      null,
      exchange,
      crypto,
      remote,
      suppressAutoInit: true, // 关键：不自动加载
    );
  });

  test('quiet mode: no calls before initialize; initialize triggers first load; explicit refresh triggers second', () async {
    expect(exchange.calls, 0);
    expect(crypto.calls, 0);
    expect(remote.catalogCalls, 0);

    await notifier.initialize();
    // Wait a short duration to allow async initial load to finish
    await Future.delayed(const Duration(milliseconds: 10));

    expect(remote.catalogCalls, 1, reason: 'Catalog should load once during initialize');
    expect(exchange.calls, 1, reason: 'Exchange rates load once during initialize');

    await notifier.refreshExchangeRates();
    expect(exchange.calls, 2, reason: 'Explicit refresh increments call count');
  });

  test('initialize() is idempotent', () async {
    await notifier.initialize();
    await Future.delayed(const Duration(milliseconds: 10));
    final firstExchangeCalls = exchange.calls;
    await notifier.initialize();
    await Future.delayed(const Duration(milliseconds: 10));
    expect(exchange.calls, firstExchangeCalls, reason: 'Second initialize should not reload');
    expect(remote.catalogCalls, 1, reason: 'Catalog fetch should only occur once');
  });
}
