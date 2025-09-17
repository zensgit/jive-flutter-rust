/// Exchange rate model for currency conversion
class ExchangeRate {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime date;
  final String? source; // API source (e.g., 'coingecko', 'fixer', 'mock')

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.date,
    this.source,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      fromCurrency: json['from_currency'] as String,
      toCurrency: json['to_currency'] as String,
      rate: (json['rate'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        'rate': rate,
        'date': date.toIso8601String(),
        'source': source,
      };

  double convert(double amount) => amount * rate;

  ExchangeRate inverse() => ExchangeRate(
        fromCurrency: toCurrency,
        toCurrency: fromCurrency,
        rate: 1.0 / rate,
        date: date,
        source: source,
      );

  @override
  String toString() => '$fromCurrency→$toCurrency: $rate @ ${date.toLocal()}';
}

/// Mock exchange rates for development/testing
class MockExchangeRates {
  static final Map<String, double> _ratesAgainstUSD = {
    'USD': 1.0,
    'EUR': 0.85,
    'GBP': 0.73,
    'JPY': 110.0,
    'CNY': 6.45,
    'CHF': 0.92,
    'CAD': 1.25,
    'AUD': 1.35,
    'NZD': 1.42,
    'HKD': 7.78,
    'SGD': 1.35,
    'KRW': 1180.0,
    'SEK': 8.6,
    'NOK': 8.5,
    'DKK': 6.3,
    'PLN': 3.9,
    'CZK': 21.5,
    'HUF': 300.0,
    'RUB': 74.0,
    'INR': 74.5,
    'BRL': 5.2,
    'MXN': 20.0,
    'ZAR': 15.0,
    'TRY': 8.5,
    'AED': 3.67,
    'SAR': 3.75,
    'THB': 33.0,
    'MYR': 4.2,
    'IDR': 14350.0,
    'PHP': 50.0,
    'VND': 23000.0,
    'TWD': 28.0,
    'ILS': 3.2,
    'ARS': 98.0,
    'CLP': 800.0,
    'COP': 3800.0,
    'PEN': 4.0,
    'UAH': 27.0,
    'RON': 4.2,
    'BGN': 1.65,
    'ISK': 125.0,
    // Cryptocurrencies (approximate rates)
    'BTC': 0.000025, // 1 USD = 0.000025 BTC (BTC = 40,000 USD)
    'ETH': 0.0003, // 1 USD = 0.0003 ETH (ETH = 3,333 USD)
    'USDT': 1.0, // Pegged to USD
    'BNB': 0.003, // 1 USD = 0.003 BNB (BNB = 333 USD)
    'SOL': 0.01, // 1 USD = 0.01 SOL (SOL = 100 USD)
    'XRP': 1.67, // 1 USD = 1.67 XRP (XRP = 0.60 USD)
    'USDC': 1.0, // Pegged to USD
    'ADA': 1.72, // 1 USD = 1.72 ADA (ADA = 0.58 USD)
    'DOGE': 11.76, // 1 USD = 11.76 DOGE (DOGE = 0.085 USD)
    'AVAX': 0.027, // 1 USD = 0.027 AVAX (AVAX = 37 USD)
    'DOT': 0.14, // 1 USD = 0.14 DOT (DOT = 7 USD)
    'MATIC': 1.12, // 1 USD = 1.12 MATIC (MATIC = 0.89 USD)
    'LINK': 0.067, // 1 USD = 0.067 LINK (LINK = 15 USD)
    'LTC': 0.014, // 1 USD = 0.014 LTC (LTC = 71 USD)
    'BCH': 0.0038, // 1 USD = 0.0038 BCH (BCH = 263 USD)
    'UNI': 0.16, // 1 USD = 0.16 UNI (UNI = 6.25 USD)
    'XLM': 8.33, // 1 USD = 8.33 XLM (XLM = 0.12 USD)
    'ALGO': 10.0, // 1 USD = 10 ALGO (ALGO = 0.10 USD)
    'ATOM': 0.1, // 1 USD = 0.1 ATOM (ATOM = 10 USD)
    'FTM': 2.5, // 1 USD = 2.5 FTM (FTM = 0.40 USD)
  };

  static ExchangeRate? getRate(String from, String to) {
    if (from == to) {
      return ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: 1.0,
        date: DateTime.now(),
        source: 'identity',
      );
    }

    final fromRate = _ratesAgainstUSD[from];
    final toRate = _ratesAgainstUSD[to];

    if (fromRate == null || toRate == null) return null;

    // Calculate cross rate
    double rate;
    if (from == 'USD') {
      rate = toRate;
    } else if (to == 'USD') {
      rate = 1.0 / fromRate;
    } else {
      rate = toRate / fromRate;
    }

    return ExchangeRate(
      fromCurrency: from,
      toCurrency: to,
      rate: rate,
      date: DateTime.now(),
      source: 'mock',
    );
  }

  static Map<String, ExchangeRate> getAllRatesFrom(String baseCurrency) {
    final Map<String, ExchangeRate> rates = {};

    for (final currency in _ratesAgainstUSD.keys) {
      if (currency != baseCurrency) {
        final rate = getRate(baseCurrency, currency);
        if (rate != null) {
          rates[currency] = rate;
        }
      }
    }

    return rates;
  }
}
