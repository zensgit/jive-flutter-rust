import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exchange_rate.dart';
import '../utils/constants.dart';

/// Service for fetching cryptocurrency prices
/// Now uses backend API instead of direct external calls
class CryptoPriceService {
  // Backend base URL getter (align with ApiConstants dynamic getter)
  String get _baseUrl => ApiConstants.baseUrl;

  // Cache duration for crypto prices (shorter due to volatility)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cache storage
  final Map<String, CachedCryptoPrice> _cache = {};

  // Currency code to CoinGecko ID mapping
  static const Map<String, String> _coinGeckoIds = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'USDT': 'tether',
    'BNB': 'binancecoin',
    'SOL': 'solana',
    'XRP': 'ripple',
    'USDC': 'usd-coin',
    'ADA': 'cardano',
    'AVAX': 'avalanche-2',
    'DOGE': 'dogecoin',
    'DOT': 'polkadot',
    'MATIC': 'matic-network',
    'LINK': 'chainlink',
    'LTC': 'litecoin',
    'BCH': 'bitcoin-cash',
    'UNI': 'uniswap',
    'XLM': 'stellar',
    'ALGO': 'algorand',
    'ATOM': 'cosmos',
    'FTM': 'fantom',
  };

  // Currency code to CoinCap ID mapping
  static const Map<String, String> _coincapIds = {
    'BTC': 'bitcoin',
    'ETH': 'ethereum',
    'USDT': 'tether',
    'BNB': 'binance-coin',
    'SOL': 'solana',
    'XRP': 'xrp',
    'USDC': 'usd-coin',
    'ADA': 'cardano',
    'AVAX': 'avalanche',
    'DOGE': 'dogecoin',
    'DOT': 'polkadot',
    'MATIC': 'polygon',
    'LINK': 'chainlink',
    'LTC': 'litecoin',
    'BCH': 'bitcoin-cash',
    'UNI': 'uniswap',
    'XLM': 'stellar',
    'ALGO': 'algorand',
    'ATOM': 'cosmos',
    'FTM': 'fantom',
  };

  /// Get crypto price in a specific fiat currency
  Future<double?> getCryptoPrice(String cryptoCode, String fiatCode) async {
    // Check cache first
    final cacheKey = '${cryptoCode}_$fiatCode';
    final cached = _cache[cacheKey];

    if (cached != null && !cached.isExpired) {
      return cached.price;
    }

    // Try to fetch from multiple sources
    double? price;

    // Try CoinGecko first (most comprehensive)
    price = await _fetchFromCoinGecko(cryptoCode, fiatCode);

    // Fallback to CoinCap
    if (price == null && fiatCode == 'USD') {
      price = await _fetchFromCoinCap(cryptoCode);
    }

    // Fallback to Binance (limited pairs)
    if (price == null) {
      price = await _fetchFromBinance(cryptoCode, fiatCode);
    }

    // Cache the result if successful
    if (price != null) {
      _cache[cacheKey] = CachedCryptoPrice(
        price: price,
        timestamp: DateTime.now(),
      );
    }

    return price;
  }

  /// Fetch from CoinGecko API via backend
  Future<double?> _fetchFromCoinGecko(
      String cryptoCode, String fiatCode) async {
    try {
      // 后端只提供 GET /currencies/crypto-prices 批量接口
      final uri = Uri.parse('$_baseUrl/currencies/crypto-prices').replace(
        queryParameters: {
          'fiat_currency': fiatCode,
          'crypto_codes': cryptoCode,
        },
      );
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pricesData = data['prices'] as Map<String, dynamic>?;
        final price = pricesData?[cryptoCode];
        if (price != null) return (price as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching crypto price from backend (GET prices): $e');
    }
    return null;
  }

  /// Fetch from CoinCap API (USD only) - using backend
  Future<double?> _fetchFromCoinCap(String cryptoCode) async {
    // Use backend API for USD prices
    return _fetchFromCoinGecko(cryptoCode, 'USD');
  }

  /// Fetch from Binance API - using backend
  Future<double?> _fetchFromBinance(String cryptoCode, String fiatCode) async {
    // Use backend API instead
    return _fetchFromCoinGecko(cryptoCode, fiatCode);
  }

  /// Get prices for specific cryptos in a fiat currency
  Future<Map<String, double>> getCryptoPricesFor(
      String fiatCode, List<String> cryptoCodes) async {
    final Map<String, double> prices = {};
    if (cryptoCodes.isEmpty) return prices;

    // Use backend API for batch prices
    try {
      final codes = cryptoCodes.map((e) => e.toUpperCase()).toSet().join(',');
      final uri = Uri.parse('$_baseUrl/currencies/crypto-prices').replace(
        queryParameters: {
          'fiat_currency': fiatCode,
          'crypto_codes': codes,
        },
      );
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pricesData = data['prices'] as Map<String, dynamic>?;
        if (pricesData != null) {
          for (final entry in pricesData.entries) {
            final price = entry.value;
            if (price != null) {
              prices[entry.key.toString().toUpperCase()] =
                  (price as num).toDouble();
              final cacheKey =
                  '${entry.key.toString().toUpperCase()}_${fiatCode.toUpperCase()}';
              _cache[cacheKey] = CachedCryptoPrice(
                price: prices[entry.key.toString().toUpperCase()]!,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching selected crypto prices from backend: $e');
    }

    return prices;
  }

  /// Get all crypto prices in a specific fiat currency (top subset)
  Future<Map<String, double>> getAllCryptoPrices(String fiatCode) async {
    final Map<String, double> prices = {};

    // Use backend API for batch prices
    try {
      final codes = _coinGeckoIds.keys.take(20).join(',');
      final uri = Uri.parse('$_baseUrl/currencies/crypto-prices').replace(
        queryParameters: {
          'fiat_currency': fiatCode,
          'crypto_codes': codes,
        },
      );
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pricesData = data['prices'] as Map<String, dynamic>?;
        if (pricesData != null) {
          for (final entry in pricesData.entries) {
            final price = entry.value;
            if (price != null) {
              prices[entry.key] = (price as num).toDouble();
              final cacheKey = '${entry.key}_$fiatCode';
              _cache[cacheKey] = CachedCryptoPrice(
                price: prices[entry.key]!,
                timestamp: DateTime.now(),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching batch prices from backend: $e');
    }

    return prices;
  }

  /// Convert between crypto and fiat or between two cryptos
  Future<double?> convert({
    required double amount,
    required String from,
    required String to,
  }) async {
    // Check if both are crypto
    final fromIsCrypto = _coinGeckoIds.containsKey(from);
    final toIsCrypto = _coinGeckoIds.containsKey(to);

    if (fromIsCrypto && toIsCrypto) {
      // Crypto to crypto conversion (through USD)
      final fromPriceUsd = await getCryptoPrice(from, 'USD');
      final toPriceUsd = await getCryptoPrice(to, 'USD');

      if (fromPriceUsd != null && toPriceUsd != null) {
        return amount * fromPriceUsd / toPriceUsd;
      }
    } else if (fromIsCrypto) {
      // Crypto to fiat
      final price = await getCryptoPrice(from, to);
      if (price != null) {
        return amount * price;
      }
    } else if (toIsCrypto) {
      // Fiat to crypto
      final price = await getCryptoPrice(to, from);
      if (price != null) {
        return amount / price;
      }
    }

    return null;
  }

  /// Get exchange rate for crypto
  Future<ExchangeRate?> getCryptoExchangeRate(String from, String to) async {
    final price = await getCryptoPrice(from, to);

    if (price != null) {
      return ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: price,
        date: DateTime.now(),
        source: 'coingecko',
      );
    }

    return null;
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }
}

/// Cached crypto price with expiration
class CachedCryptoPrice {
  final double price;
  final DateTime timestamp;

  CachedCryptoPrice({
    required this.price,
    required this.timestamp,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        CryptoPriceService._cacheDuration;
  }
}
