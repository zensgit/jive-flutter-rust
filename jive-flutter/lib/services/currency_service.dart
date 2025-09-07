import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/currency.dart';
import '../models/currency_api.dart';
import '../utils/constants.dart';

class CurrencyService {
  final String? token;
  final String baseUrl = ApiConstants.baseUrl;
  
  CurrencyService(this.token);
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  
  /// Get all supported currencies from the API
  Future<List<Currency>> getSupportedCurrencies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/currencies'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> currencies = data['data'] ?? data;
        
        return currencies.map((json) {
          final apiCurrency = ApiCurrency.fromJson(json);
          // Map API currency to app Currency model
          return Currency(
            code: apiCurrency.code,
            name: apiCurrency.name,
            nameZh: _getChineseName(apiCurrency.code),
            symbol: apiCurrency.symbol,
            decimalPlaces: apiCurrency.decimalPlaces,
            isEnabled: apiCurrency.isActive,
            flag: _getFlag(apiCurrency.code),
          );
        }).toList();
      } else {
        throw Exception('Failed to load currencies: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching currencies: $e');
      // Return default currencies as fallback
      return CurrencyDefaults.fiatCurrencies;
    }
  }
  
  /// Get user currency preferences
  Future<List<CurrencyPreference>> getUserCurrencyPreferences() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/currencies/preferences'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> preferences = data['data'] ?? data;
        return preferences.map((json) => CurrencyPreference.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load preferences: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching preferences: $e');
      return [];
    }
  }
  
  /// Set user currency preferences
  Future<void> setUserCurrencyPreferences(List<String> currencies, String primaryCurrency) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/currencies/preferences'),
        headers: _headers,
        body: json.encode({
          'currencies': currencies,
          'primary_currency': primaryCurrency,
        }),
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to set preferences: ${response.statusCode}');
      }
    } catch (e) {
      print('Error setting preferences: $e');
      rethrow;
    }
  }
  
  /// Get family currency settings
  Future<FamilyCurrencySettings> getFamilyCurrencySettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/family/currency-settings'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FamilyCurrencySettings.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Failed to load family settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching family settings: $e');
      // Return default settings
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
  Future<void> updateFamilyCurrencySettings(Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/family/currency-settings'),
        headers: _headers,
        body: json.encode(updates),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update settings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating family settings: $e');
      rethrow;
    }
  }
  
  /// Get exchange rate
  Future<double> getExchangeRate(String from, String to, {DateTime? date}) async {
    try {
      final queryParams = {
        'from': from,
        'to': to,
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      };
      
      final uri = Uri.parse('$baseUrl/currencies/rate')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
        throw Exception('Failed to get exchange rate: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting exchange rate: $e');
      // Return 1.0 as fallback for same currency
      if (from == to) return 1.0;
      // Return approximate rates as fallback
      return _getApproximateRate(from, to);
    }
  }
  
  /// Get batch exchange rates
  Future<Map<String, double>> getBatchExchangeRates(String baseCurrency, List<String> targetCurrencies) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/currencies/rates'),
        headers: _headers,
        body: json.encode({
          'base_currency': baseCurrency,
          'target_currencies': targetCurrencies,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ratesData = data['data'] ?? data;
        
        final Map<String, double> rates = {};
        ratesData.forEach((key, value) {
          rates[key] = (value is String) ? double.parse(value) : value.toDouble();
        });
        
        return rates;
      } else {
        throw Exception('Failed to get batch rates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting batch rates: $e');
      // Return approximate rates as fallback
      final Map<String, double> rates = {};
      for (final target in targetCurrencies) {
        rates[target] = _getApproximateRate(baseCurrency, target);
      }
      return rates;
    }
  }
  
  /// Convert amount between currencies
  Future<ConvertAmountResponse> convertAmount(double amount, String from, String to, {DateTime? date}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/currencies/convert'),
        headers: _headers,
        body: json.encode({
          'amount': amount,
          'from_currency': from,
          'to_currency': to,
          if (date != null) 'date': date.toIso8601String().substring(0, 10),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConvertAmountResponse.fromJson(data['data'] ?? data);
      } else {
        throw Exception('Failed to convert amount: ${response.statusCode}');
      }
    } catch (e) {
      print('Error converting amount: $e');
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
  Future<List<ExchangeRate>> getExchangeRateHistory(String from, String to, int days) async {
    try {
      final queryParams = {
        'from': from,
        'to': to,
        'days': days.toString(),
      };
      
      final uri = Uri.parse('$baseUrl/currencies/history')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['data'] ?? data;
        return history.map((json) => ExchangeRate.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get history: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting rate history: $e');
      return [];
    }
  }
  
  /// Get popular exchange pairs
  Future<List<ExchangePair>> getPopularExchangePairs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/currencies/popular-pairs'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> pairs = data['data'] ?? data;
        return pairs.map((json) => ExchangePair.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get popular pairs: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting popular pairs: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/currencies/refresh'),
        headers: _headers,
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to refresh rates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing rates: $e');
      rethrow;
    }
  }
  
  // Helper methods
  
  String _getChineseName(String code) {
    final currency = CurrencyDefaults.getAllCurrencies()
        .firstWhere((c) => c.code == code, 
            orElse: () => Currency(
              code: code,
              name: code,
              nameZh: code,
              symbol: '',
              decimalPlaces: 2,
            ));
    return currency.nameZh;
  }
  
  String? _getFlag(String code) {
    final currency = CurrencyDefaults.getAllCurrencies()
        .firstWhere((c) => c.code == code,
            orElse: () => Currency(
              code: code,
              name: code,
              nameZh: code,
              symbol: '',
              decimalPlaces: 2,
            ));
    return currency.flag;
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