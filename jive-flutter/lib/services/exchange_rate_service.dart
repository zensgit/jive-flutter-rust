import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exchange_rate.dart';

/// Service for fetching real exchange rates from various APIs
class ExchangeRateService {
  // Free tier APIs that don't require API keys for basic usage
  static const String _exchangeRateApiUrl = 'https://api.exchangerate-api.com/v4/latest/';
  static const String _frankfurterApiUrl = 'https://api.frankfurter.app/latest';
  static const String _fxRatesApiUrl = 'https://api.fxratesapi.com/latest';
  
  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 15);
  
  // Cache storage
  final Map<String, CachedExchangeRates> _cache = {};

  /// Get exchange rates for a base currency
  Future<Map<String, ExchangeRate>> getExchangeRates(String baseCurrency) async {
    // Check cache first
    final cacheKey = baseCurrency.toUpperCase();
    final cached = _cache[cacheKey];
    
    if (cached != null && !cached.isExpired) {
      return cached.rates;
    }

    // Try to fetch from multiple sources for reliability
    Map<String, ExchangeRate>? rates;
    
    // Try primary API
    rates = await _fetchFromExchangeRateApi(baseCurrency);
    
    // Fallback to secondary API if primary fails
    if (rates == null || rates.isEmpty) {
      rates = await _fetchFromFrankfurterApi(baseCurrency);
    }
    
    // Fallback to tertiary API
    if (rates == null || rates.isEmpty) {
      rates = await _fetchFromFxRatesApi(baseCurrency);
    }
    
    // If all APIs fail, use fallback rates
    if (rates == null || rates.isEmpty) {
      rates = _getFallbackRates(baseCurrency);
    }
    
    // Cache the results
    _cache[cacheKey] = CachedExchangeRates(
      rates: rates,
      timestamp: DateTime.now(),
    );
    
    return rates;
  }

  /// Fetch from exchangerate-api.com (no API key needed for basic usage)
  Future<Map<String, ExchangeRate>?> _fetchFromExchangeRateApi(String baseCurrency) async {
    try {
      final response = await http
          .get(Uri.parse('$_exchangeRateApiUrl$baseCurrency'))
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
            source: 'exchangerate-api',
          );
        }
        
        return exchangeRates;
      }
    } catch (e) {
      print('Error fetching from exchangerate-api: $e');
    }
    
    return null;
  }

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
      print('Error fetching from frankfurter: $e');
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
      print('Error fetching from fxratesapi: $e');
    }
    
    return null;
  }

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