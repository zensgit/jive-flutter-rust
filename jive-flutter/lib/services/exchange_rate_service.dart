import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/exchange_rate.dart';
import '../utils/constants.dart';
import '../core/network/http_client.dart';
import '../core/network/api_readiness.dart';
import '../core/storage/token_storage.dart';

/// Service for fetching real exchange rates from backend API
class ExchangeRateService {
  
  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 15);
  
  // Cache storage
  final Map<String, CachedExchangeRates> _cache = {};
  bool _lastWasFallback = false;

  bool get lastWasFallback => _lastWasFallback;

  /// Get exchange rates for a base currency
  Future<Map<String, ExchangeRate>> getExchangeRates(String baseCurrency) async {
    // Check cache first
    final cacheKey = baseCurrency.toUpperCase();
    final cached = _cache[cacheKey];
    
    if (cached != null && !cached.isExpired) {
      return cached.rates;
    }

    // Fetch from backend API
    Map<String, ExchangeRate>? rates;
    
    // Try backend API
    rates = await _fetchFromBackendApi(baseCurrency);
    bool usedFallback = false;
    if (rates == null || rates.isEmpty) {
      usedFallback = true;
      rates = _getFallbackRates(baseCurrency);
      _lastWasFallback = true;
      debugPrint('⚠️ Using fallback exchange rates (backend unavailable)');
    } else {
      _lastWasFallback = false;
      debugPrint('✅ Live exchange rates fetched');
    }
    _cache[cacheKey] = CachedExchangeRates(rates: rates, timestamp: DateTime.now());
    return rates;
  }

  /// Get exchange rates for a base currency with explicit targets (server-detailed, includes source)
  Future<Map<String, ExchangeRate>> getExchangeRatesForTargets(
    String baseCurrency,
    List<String> targets,
  ) async {
    final cacheKey = '${baseCurrency.toUpperCase()}::${targets.map((e)=>e.toUpperCase()).toList()..sort()}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) return cached.rates;

    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final resp = await dio.post(
        '/currencies/rates-detailed',
        data: {
          'base_currency': baseCurrency,
          'target_currencies': targets,
        },
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        final payload = data['data'] ?? data;
        final ratesMap = payload['rates'] as Map<String, dynamic>?;
        if (ratesMap == null) throw Exception('Invalid response format');
        final now = DateTime.now();
        final Map<String, ExchangeRate> result = {};
        ratesMap.forEach((code, item) {
          if (item is Map && item['rate'] != null) {
            final rate = (item['rate'] is num)
                ? (item['rate'] as num).toDouble()
                : double.tryParse(item['rate'].toString()) ?? 0.0;
            final source = item['source']?.toString();
            result[code] = ExchangeRate(
              fromCurrency: baseCurrency,
              toCurrency: code,
              rate: rate,
              date: now,
              source: source,
            );
          }
        });
        _lastWasFallback = false;
        _cache[cacheKey] = CachedExchangeRates(rates: result, timestamp: now);
        return result;
      }
      throw Exception('Server returned ${resp.statusCode}');
    } catch (e) {
      // If server fails, do not fabricate mock here; let UI indicate missing
      _lastWasFallback = true;
      return {};
    }
  }

  /// Fetch from backend API
  Future<Map<String, ExchangeRate>?> _fetchFromBackendApi(
    String baseCurrency, { List<String>? targets }
  ) async {
    final dio = HttpClient.instance.dio;
    await ApiReadiness.ensureReady(dio);
    final targetCurrencies = (targets == null || targets.isEmpty)
        ? ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'HKD', 'AUD', 'CAD', 'SGD', 'CHF']
        : targets.map((e) => e.toUpperCase()).toSet().toList();
    int attempt = 0;
    while (attempt < 2) {
      try {
        final token = await TokenStorage.getAccessToken();
        final resp = await dio.post(
          '/currencies/rates',
          data: {
            'base_currency': baseCurrency,
            'target_currencies': targetCurrencies,
          },
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          }),
        );
        if (resp.statusCode == 200 && resp.data != null) {
          final data = resp.data;
          final ratesMap = (data['data'] ?? data) as Map<String, dynamic>;
          final now = DateTime.now();
          final Map<String, ExchangeRate> result = {};
          for (final e in ratesMap.entries) {
            final v = e.value;
            final rate = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
            result[e.key] = ExchangeRate(
              fromCurrency: baseCurrency,
              toCurrency: e.key,
              rate: rate,
              date: now,
              source: 'backend-api',
            );
          }
          return result;
        }
        break; // 非 200 不重复重试
      } catch (e) {
        if (e is DioException && (e.error is SocketException)) {
          // backoff
          await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
          attempt++;
          continue;
        }
        debugPrint('Error fetching from backend API: $e');
        break;
      }
    }
    return null;
  }

  // The following methods are kept for reference but not used anymore
  // as we now use the backend API
  
  /*
  /// Fetch from frankfurter.app (European Central Bank data, completely free) 
  Future<Map<String, ExchangeRate>?> _fetchFromFrankfurterApi(String baseCurrency) async {
    try {
      final uri = Uri.parse(_frankfurterApiUrl).replace(
        queryParameters: {'from': baseCurrency},
      );
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        final date = DateTime.parse(data['date']);
        
        final Map<String, ExchangeRate> exchangeRates = {};
        
        // Add the base currency itself
        exchangeRates[baseCurrency] = ExchangeRate(
          fromCurrency: baseCurrency,
          toCurrency: baseCurrency,
          rate: 1.0,
          date: date,
          source: 'frankfurter',
        );
        
        for (final entry in rates.entries) {
          exchangeRates[entry.key] = ExchangeRate(
            fromCurrency: baseCurrency,
            toCurrency: entry.key,
            rate: (entry.value as num).toDouble(),
            date: date,
            source: 'frankfurter',
          );
        }
        
        return exchangeRates;
      }
    } catch (e) {
      debugPrint('Error fetching from frankfurter: $e');
    }
    
    return null;
  }

  /// Fetch from fxratesapi.com
  Future<Map<String, ExchangeRate>?> _fetchFromFxRatesApi(String baseCurrency) async {
    try {
      final uri = Uri.parse(_fxRatesApiUrl).replace(
        queryParameters: {'base': baseCurrency},
      );
      
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        final date = DateTime.parse(data['date']);
        
        final Map<String, ExchangeRate> exchangeRates = {};
        
        for (final entry in rates.entries) {
          exchangeRates[entry.key] = ExchangeRate(
            fromCurrency: baseCurrency,
            toCurrency: entry.key,
            rate: (entry.value as num).toDouble(),
            date: date,
            source: 'fxratesapi',
          );
        }
        
        return exchangeRates;
      }
    } catch (e) {
      debugPrint('Error fetching from fxratesapi: $e');
    }
    
    return null;
  }
  */

  /// Get fallback rates when APIs are unavailable
  Map<String, ExchangeRate> _getFallbackRates(String baseCurrency) {
    // Use MockExchangeRates as fallback
    return MockExchangeRates.getAllRatesFrom(baseCurrency);
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }

  /// Get a single exchange rate
  Future<ExchangeRate?> getRate(String from, String to) async {
    if (from == to) {
      return ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: 1.0,
        date: DateTime.now(),
        source: 'identity',
      );
    }

    final rates = await getExchangeRates(from);
    return rates[to];
  }

  /// Convert an amount between currencies
  Future<double?> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    final rate = await getRate(from, to);
    return rate?.convert(amount);
  }
}

/// Cached exchange rates with expiration
class CachedExchangeRates {
  final Map<String, ExchangeRate> rates;
  final DateTime timestamp;

  CachedExchangeRates({
    required this.rates,
    required this.timestamp,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > ExchangeRateService._cacheDuration;
  }
}
