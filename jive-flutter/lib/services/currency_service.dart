import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/core/network/api_readiness.dart';
import 'package:jive_money/core/storage/token_storage.dart';
import 'package:jive_money/models/currency.dart';
import 'package:jive_money/models/currency_api.dart';
import 'package:jive_money/models/global_market_stats.dart';
import 'package:jive_money/utils/constants.dart';

class CurrencyService {
  final String? token;
  final String baseUrl = ApiConstants.baseUrl; // 仍保留用于兼容旧逻辑的字段

  CurrencyService(this.token);

  Future<Map<String, String>> _headers() async {
    final t = token ?? await TokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// Result wrapper for currency catalog with ETag support
  Future<CurrencyCatalogResult> getSupportedCurrenciesWithEtag(
      {String? etag}) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.get('/currencies',
          options: Options(headers: {
            if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
          }));
      if (resp.statusCode == 200) {
        final data = resp.data;
        final List<dynamic> currencies = data['data'] ?? data;
        final items = currencies.map((json) {
          final apiCurrency = ApiCurrency.fromJson(json);
          // Map API currency to app Currency model
          return Currency(
            code: apiCurrency.code,
            name: apiCurrency.name,
            // 🔥 优先使用 API 的中文名，如果为空则使用英文名作为后备
            nameZh: apiCurrency.nameZh?.isNotEmpty == true
                ? apiCurrency.nameZh!
                : apiCurrency.name,
            symbol: apiCurrency.symbol,
            decimalPlaces: apiCurrency.decimalPlaces,
            isEnabled: apiCurrency.isActive,
            isCrypto: apiCurrency.isCrypto,
            // 🔥 优先使用 API 提供的 flag，如果为空则自动生成（法定货币）
            flag: apiCurrency.flag?.isNotEmpty == true
                ? apiCurrency.flag
                : _generateFlagEmoji(apiCurrency.code),
            // 🔥 优先使用 API 提供的 icon（加密货币）
            icon: apiCurrency.icon,
          );
        }).toList();
        final newEtag = resp.headers['etag']?.first;
        return CurrencyCatalogResult(items, newEtag, false);
      } else if (resp.statusCode == 304) {
        return CurrencyCatalogResult(const [], etag, true);
      } else {
        throw Exception('Failed to load currencies: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching currencies: $e');
      // On failure, signal fallback by returning empty and notModified=false
      return CurrencyCatalogResult(const [], etag, false, error: e.toString());
    }
  }

  /// Backward compatible simple fetch (no ETag)
  Future<List<Currency>> getSupportedCurrencies() async {
    final res = await getSupportedCurrenciesWithEtag();
    if (res.notModified || res.items.isEmpty) {
      // Fallback to bundled list
      return CurrencyDefaults.fiatCurrencies;
    }
    return res.items;
  }

  /// Get user currency preferences
  Future<List<CurrencyPreference>> getUserCurrencyPreferences() async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.get('/currencies/preferences');
      if (resp.statusCode == 200) {
        final data = resp.data;
        final List<dynamic> preferences = data['data'] ?? data;
        return preferences
            .map((json) => CurrencyPreference.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load preferences: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching preferences: $e');
      return [];
    }
  }

  /// Set user currency preferences
  Future<void> setUserCurrencyPreferences(
      List<String> currencies, String primaryCurrency) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.post('/currencies/preferences', data: {
        'currencies': currencies,
        'primary_currency': primaryCurrency,
      });
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception('Failed to set preferences: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error setting preferences: $e');
      rethrow;
    }
  }

  /// Get family currency settings
  Future<FamilyCurrencySettings> getFamilyCurrencySettings() async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.get('/family/currency-settings');
      if (resp.statusCode == 200) {
        final data = resp.data;
        return FamilyCurrencySettings.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Failed to load family settings: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching family settings: $e');
      return FamilyCurrencySettings(
        familyId: '',
        baseCurrency: 'CNY',
        allowMultiCurrency: true,
        autoConvert: false,
        supportedCurrencies: ['CNY', 'USD'],
      );
    }
  }

  /// Update family currency settings
  Future<void> updateFamilyCurrencySettings(
      Map<String, dynamic> updates) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.put('/family/currency-settings', data: updates);
      if (resp.statusCode != 200) {
        throw Exception('Failed to update settings: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating family settings: $e');
      rethrow;
    }
  }

  /// Get exchange rate
  Future<double> getExchangeRate(String from, String to,
      {DateTime? date}) async {
    try {
      final queryParams = {
        'from': from,
        'to': to,
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      };

      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp =
          await dio.get('/currencies/rate', queryParameters: queryParams);
      if (resp.statusCode == 200) {
        final data = resp.data;
        final rateData = data['data'] ?? data;

        if (rateData is Map && rateData.containsKey('rate')) {
          return (rateData['rate'] is String)
              ? double.parse(rateData['rate'])
              : rateData['rate'].toDouble();
        } else if (rateData is num) {
          return rateData.toDouble();
        } else {
          throw Exception('Invalid rate format');
        }
      } else {
        throw Exception('Failed to get exchange rate: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting exchange rate: $e');
      // Return 1.0 as fallback for same currency
      if (from == to) return 1.0;
      // Return approximate rates as fallback
      return _getApproximateRate(from, to);
    }
  }

  /// Get batch exchange rates
  Future<Map<String, double>> getBatchExchangeRates(
      String baseCurrency, List<String> targetCurrencies) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.post('/currencies/rates', data: {
        'base_currency': baseCurrency,
        'target_currencies': targetCurrencies,
      });
      if (resp.statusCode == 200) {
        final data = resp.data;
        final ratesData = data['data'] ?? data;

        final Map<String, double> rates = {};
        ratesData.forEach((key, value) {
          rates[key] =
              (value is String) ? double.parse(value) : value.toDouble();
        });

        return rates;
      } else {
        throw Exception('Failed to get batch rates: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting batch rates: $e');
      // Return approximate rates as fallback
      final Map<String, double> rates = {};
      for (final target in targetCurrencies) {
        rates[target] = _getApproximateRate(baseCurrency, target);
      }
      return rates;
    }
  }

  /// Convert amount between currencies
  Future<ConvertAmountResponse> convertAmount(
      double amount, String from, String to,
      {DateTime? date}) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.post('/currencies/convert', data: {
        'amount': amount,
        'from_currency': from,
        'to_currency': to,
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      });
      if (resp.statusCode == 200) {
        final data = resp.data;
        return ConvertAmountResponse.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Failed to convert amount: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error converting amount: $e');
      // Fallback to simple conversion
      final rate = await getExchangeRate(from, to, date: date);
      return ConvertAmountResponse(
        originalAmount: amount,
        convertedAmount: amount * rate,
        fromCurrency: from,
        toCurrency: to,
        exchangeRate: rate,
      );
    }
  }

  /// Get exchange rate history
  Future<List<ExchangeRate>> getExchangeRateHistory(
      String from, String to, int days) async {
    try {
      final queryParams = {
        'from': from,
        'to': to,
        'days': days.toString(),
      };

      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp =
          await dio.get('/currencies/history', queryParameters: queryParams);
      if (resp.statusCode == 200) {
        final data = resp.data;
        final List<dynamic> history = data['data'] ?? data;
        return history.map((json) => ExchangeRate.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get history: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting rate history: $e');
      return [];
    }
  }

  /// Get popular exchange pairs
  Future<List<ExchangePair>> getPopularExchangePairs() async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.get('/currencies/popular-pairs');
      if (resp.statusCode == 200) {
        final data = resp.data;
        final List<dynamic> pairs = data['data'] ?? data;
        return pairs.map((json) => ExchangePair.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get popular pairs: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting popular pairs: $e');
      // Return default pairs
      return [
        ExchangePair(from: 'CNY', to: 'USD', name: '人民币/美元'),
        ExchangePair(from: 'CNY', to: 'EUR', name: '人民币/欧元'),
        ExchangePair(from: 'CNY', to: 'JPY', name: '人民币/日元'),
        ExchangePair(from: 'CNY', to: 'HKD', name: '人民币/港币'),
        ExchangePair(from: 'USD', to: 'EUR', name: '美元/欧元'),
        ExchangePair(from: 'USD', to: 'JPY', name: '美元/日元'),
      ];
    }
  }

  /// Refresh exchange rates
  Future<void> refreshExchangeRates() async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.post('/currencies/refresh');
      if (resp.statusCode != 200) {
        throw Exception('Failed to refresh rates: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error refreshing rates: $e');
      rethrow;
    }
  }

  /// Get global cryptocurrency market statistics
  Future<GlobalMarketStats?> getGlobalMarketStats() async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.get('/currencies/global-market-stats');
      if (resp.statusCode == 200) {
        final data = resp.data;
        final statsData = data['data'] ?? data;
        return GlobalMarketStats.fromJson(statsData);
      } else {
        throw Exception('Failed to get global market stats: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting global market stats: $e');
      return null;
    }
  }

  // Helper methods

  /// 自动生成国旗 emoji（基于货币代码的国家部分）
  /// 例如: USD → 🇺🇸, EUR → 🇪🇺, CNY → 🇨🇳
  String? _generateFlagEmoji(String currencyCode) {
    if (currencyCode.length < 2) return null;

    // 特殊货币代码映射（没有直接对应国家代码的）
    const specialCurrencies = {
      'EUR': '🇪🇺', // 欧元 → 欧盟旗
      'XAF': '🏛️', // 中非法郎 → 中央银行符号
      'XOF': '🏛️', // 西非法郎
      'XPF': '🇫🇷', // 太平洋法郎 → 法国
      'XCD': '🏝️', // 东加勒比元 → 岛屿
    };

    if (specialCurrencies.containsKey(currencyCode)) {
      return specialCurrencies[currencyCode];
    }

    // 大多数货币代码的前两位是 ISO 3166-1 alpha-2 国家代码
    // 将国家代码转换为国旗 emoji
    final countryCode = currencyCode.substring(0, 2).toUpperCase();

    // 国旗 emoji 由两个区域指示符号组成
    // A-Z (0x41-0x5A) 映射到 🇦-🇿 (0x1F1E6-0x1F1FF)
    final firstChar = countryCode.codeUnitAt(0);
    final secondChar = countryCode.codeUnitAt(1);

    if (firstChar < 0x41 || firstChar > 0x5A || secondChar < 0x41 || secondChar > 0x5A) {
      return null; // 非有效国家代码
    }

    final regionalIndicatorOffset = 0x1F1E6 - 0x41;
    final flag = String.fromCharCodes([
      firstChar + regionalIndicatorOffset,
      secondChar + regionalIndicatorOffset,
    ]);

    return flag;
  }

  double _getApproximateRate(String from, String to) {
    // Approximate exchange rates for fallback
    final rates = {
      'CNY-USD': 0.138,
      'USD-CNY': 7.25,
      'CNY-EUR': 0.127,
      'EUR-CNY': 7.90,
      'CNY-JPY': 20.36,
      'JPY-CNY': 0.049,
      'CNY-HKD': 1.08,
      'HKD-CNY': 0.93,
      'USD-EUR': 0.92,
      'EUR-USD': 1.09,
      'USD-JPY': 147.5,
      'JPY-USD': 0.0068,
    };

    final key = '$from-$to';
    return rates[key] ?? 1.0;
  }
}

class CurrencyCatalogResult {
  final List<Currency> items;
  final String? etag;
  final bool notModified;
  final String? error;
  CurrencyCatalogResult(this.items, this.etag, this.notModified, {this.error});
}
