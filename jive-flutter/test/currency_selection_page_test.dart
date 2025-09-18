import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jive_money/screens/management/currency_selection_page.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/models/currency.dart' as model;
import 'package:jive_money/models/currency_api.dart' as api;
import 'package:jive_money/services/currency_service.dart';
import 'package:jive_money/services/exchange_rate_service.dart';
import 'package:jive_money/services/crypto_price_service.dart';

class _FakeRemote extends CurrencyService {
  _FakeRemote(): super(null);
  static const _usd = model.Currency(
      code: 'USD',
      name: 'US Dollar',
      nameZh: '美元',
      symbol: r'$',
      decimalPlaces: 2,
      flag: '🇺🇸',
      isCrypto: false);
  static const _cny = model.Currency(
      code: 'CNY',
      name: 'Chinese Yuan',
      nameZh: '人民币',
      symbol: '¥',
      decimalPlaces: 2,
      flag: '🇨🇳',
      isCrypto: false);
  @override
  @override
  Future<List<model.Currency>> getSupportedCurrencies() async => const [_usd,_cny];
  @override
  Future<CurrencyCatalogResult> getSupportedCurrenciesWithEtag({String? etag}) async => CurrencyCatalogResult(await getSupportedCurrencies(), null, false);
  @override
  Future<List<api.CurrencyPreference>> getUserCurrencyPreferences() async => const [];
  @override
  Future<void> setUserCurrencyPreferences(List<String> currencies, String primaryCurrency) async {}
  @override
  Future<api.FamilyCurrencySettings> getFamilyCurrencySettings() async => api.FamilyCurrencySettings(
      familyId: '', baseCurrency: 'USD', allowMultiCurrency: true, autoConvert: false, supportedCurrencies: const ['USD']);
  @override
  Future<void> updateFamilyCurrencySettings(Map<String, dynamic> updates) async {}
  @override
  Future<double> getExchangeRate(String from, String to, {DateTime? date}) async => 1.0;
  @override
  Future<Map<String,double>> getBatchExchangeRates(String baseCurrency, List<String> targetCurrencies) async => {};
  @override
  Future<api.ConvertAmountResponse> convertAmount(double amount, String from, String to, {DateTime? date}) async => api.ConvertAmountResponse(originalAmount: amount, convertedAmount: amount, fromCurrency: from, toCurrency: to, exchangeRate: 1.0);
  @override
  Future<List<api.ExchangeRate>> getExchangeRateHistory(String from, String to, int days) async => const [];
  @override
  Future<List<api.ExchangePair>> getPopularExchangePairs() async => const [];
  @override
  Future<void> refreshExchangeRates() async {}
}
class _NoopExchangeRateService extends ExchangeRateService {}
class _NoopCryptoService extends CryptoPriceService {}
class _FakeNotifier extends CurrencyNotifier {
  _FakeNotifier()
      : super(
          Hive.box('preferences'),
          null,
          _NoopExchangeRateService(),
          _NoopCryptoService(),
          _FakeRemote(),
          suppressAutoInit: true,
        ) {
    state = const CurrencyPreferences(multiCurrencyEnabled:false, cryptoEnabled:false, baseCurrency:'USD', selectedCurrencies:['USD','CNY'], showCurrencyCode:true, showCurrencySymbol:false);
  }
  @override
  Future<void> refreshExchangeRates() async {}
}
void main(){
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final dir = await Directory.systemTemp.createTemp('hive_widget_test');
    Hive.init(dir.path);
    await Hive.openBox('preferences');
  });
  testWidgets('Selecting base currency returns via Navigator.pop', (tester) async {
    final overrides=[currencyProvider.overrideWithProvider(StateNotifierProvider<CurrencyNotifier,CurrencyPreferences>((ref)=>_FakeNotifier()))];
    late Object? result;
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CurrencySelectionPage(isSelectingBaseCurrency: true),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    // Allow several short pumps until USD appears or timeout
    for (int i = 0; i < 6 && find.text('USD').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('USD'), findsWidgets, reason: 'USD should be listed');
    await tester.tap(find.text('USD').first);
    await tester.pump(const Duration(milliseconds: 60));
    expect(result, isA<model.Currency>());
    expect((result as model.Currency).code,'USD');
  });
  testWidgets('Base currency is sorted to top and marked', (tester) async {
    final overrides=[currencyProvider.overrideWithProvider(StateNotifierProvider<CurrencyNotifier,CurrencyPreferences>((ref)=>_FakeNotifier()))];
    await tester.pumpWidget(ProviderScope(overrides:overrides, child: const MaterialApp(home: CurrencySelectionPage(isSelectingBaseCurrency:false))));
    await tester.pump(const Duration(milliseconds:60));
    expect(find.text('USD'), findsWidgets);
    expect(find.text('基础'), findsWidgets);
  });
}
