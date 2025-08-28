/// Currency model for multi-currency support
class Currency {
  final String code;        // ISO 4217 code (e.g., USD, CNY, BTC)
  final String name;         // English name
  final String nameZh;       // Chinese name
  final String symbol;       // Currency symbol (e.g., $, ¥, ₿)
  final int decimalPlaces;  // Number of decimal places
  final bool isEnabled;     // Whether currency is enabled
  final bool isCrypto;      // Whether it's a cryptocurrency
  final String? flag;        // Emoji flag for display
  final double? exchangeRate; // Exchange rate to base currency

  const Currency({
    required this.code,
    required this.name,
    required this.nameZh,
    required this.symbol,
    required this.decimalPlaces,
    this.isEnabled = true,
    this.isCrypto = false,
    this.flag,
    this.exchangeRate,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'] as String,
      name: json['name'] as String,
      nameZh: json['name_zh'] as String,
      symbol: json['symbol'] as String,
      decimalPlaces: json['decimal_places'] as int,
      isEnabled: json['is_enabled'] ?? true,
      isCrypto: json['is_crypto'] ?? false,
      flag: json['flag'] as String?,
      exchangeRate: json['exchange_rate']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'name_zh': nameZh,
    'symbol': symbol,
    'decimal_places': decimalPlaces,
    'is_enabled': isEnabled,
    'is_crypto': isCrypto,
    'flag': flag,
    'exchange_rate': exchangeRate,
  };

  Currency copyWith({
    String? code,
    String? name,
    String? nameZh,
    String? symbol,
    int? decimalPlaces,
    bool? isEnabled,
    bool? isCrypto,
    String? flag,
    double? exchangeRate,
  }) {
    return Currency(
      code: code ?? this.code,
      name: name ?? this.name,
      nameZh: nameZh ?? this.nameZh,
      symbol: symbol ?? this.symbol,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      isEnabled: isEnabled ?? this.isEnabled,
      isCrypto: isCrypto ?? this.isCrypto,
      flag: flag ?? this.flag,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  String get displayName => '$name ($nameZh)';
  
  String formatAmount(double amount) {
    return amount.toStringAsFixed(decimalPlaces);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Default currencies including fiat and crypto
class CurrencyDefaults {
  static const List<Currency> fiatCurrencies = [
    // Major currencies
    Currency(code: 'USD', name: 'US Dollar', nameZh: '美元', symbol: '\$', decimalPlaces: 2, flag: '🇺🇸'),
    Currency(code: 'EUR', name: 'Euro', nameZh: '欧元', symbol: '€', decimalPlaces: 2, flag: '🇪🇺'),
    Currency(code: 'GBP', name: 'British Pound', nameZh: '英镑', symbol: '£', decimalPlaces: 2, flag: '🇬🇧'),
    Currency(code: 'JPY', name: 'Japanese Yen', nameZh: '日元', symbol: '¥', decimalPlaces: 0, flag: '🇯🇵'),
    Currency(code: 'CNY', name: 'Chinese Yuan', nameZh: '人民币', symbol: '¥', decimalPlaces: 2, flag: '🇨🇳'),
    Currency(code: 'CHF', name: 'Swiss Franc', nameZh: '瑞士法郎', symbol: 'CHF', decimalPlaces: 2, flag: '🇨🇭'),
    Currency(code: 'CAD', name: 'Canadian Dollar', nameZh: '加拿大元', symbol: '\$', decimalPlaces: 2, flag: '🇨🇦'),
    Currency(code: 'AUD', name: 'Australian Dollar', nameZh: '澳大利亚元', symbol: '\$', decimalPlaces: 2, flag: '🇦🇺'),
    Currency(code: 'NZD', name: 'New Zealand Dollar', nameZh: '新西兰元', symbol: '\$', decimalPlaces: 2, flag: '🇳🇿'),
    Currency(code: 'HKD', name: 'Hong Kong Dollar', nameZh: '港元', symbol: '\$', decimalPlaces: 2, flag: '🇭🇰'),
    Currency(code: 'SGD', name: 'Singapore Dollar', nameZh: '新加坡元', symbol: '\$', decimalPlaces: 2, flag: '🇸🇬'),
    Currency(code: 'KRW', name: 'South Korean Won', nameZh: '韩元', symbol: '₩', decimalPlaces: 0, flag: '🇰🇷'),
    Currency(code: 'SEK', name: 'Swedish Krona', nameZh: '瑞典克朗', symbol: 'kr', decimalPlaces: 2, flag: '🇸🇪'),
    Currency(code: 'NOK', name: 'Norwegian Krone', nameZh: '挪威克朗', symbol: 'kr', decimalPlaces: 2, flag: '🇳🇴'),
    Currency(code: 'DKK', name: 'Danish Krone', nameZh: '丹麦克朗', symbol: 'kr', decimalPlaces: 2, flag: '🇩🇰'),
    Currency(code: 'PLN', name: 'Polish Zloty', nameZh: '波兰兹罗提', symbol: 'zł', decimalPlaces: 2, flag: '🇵🇱'),
    Currency(code: 'CZK', name: 'Czech Koruna', nameZh: '捷克克朗', symbol: 'Kč', decimalPlaces: 2, flag: '🇨🇿'),
    Currency(code: 'HUF', name: 'Hungarian Forint', nameZh: '匈牙利福林', symbol: 'Ft', decimalPlaces: 2, flag: '🇭🇺'),
    Currency(code: 'RUB', name: 'Russian Ruble', nameZh: '俄罗斯卢布', symbol: '₽', decimalPlaces: 2, flag: '🇷🇺'),
    Currency(code: 'INR', name: 'Indian Rupee', nameZh: '印度卢比', symbol: '₹', decimalPlaces: 2, flag: '🇮🇳'),
    Currency(code: 'BRL', name: 'Brazilian Real', nameZh: '巴西雷亚尔', symbol: 'R\$', decimalPlaces: 2, flag: '🇧🇷'),
    Currency(code: 'MXN', name: 'Mexican Peso', nameZh: '墨西哥比索', symbol: '\$', decimalPlaces: 2, flag: '🇲🇽'),
    Currency(code: 'ZAR', name: 'South African Rand', nameZh: '南非兰特', symbol: 'R', decimalPlaces: 2, flag: '🇿🇦'),
    Currency(code: 'TRY', name: 'Turkish Lira', nameZh: '土耳其里拉', symbol: '₺', decimalPlaces: 2, flag: '🇹🇷'),
    Currency(code: 'AED', name: 'UAE Dirham', nameZh: '阿联酋迪拉姆', symbol: 'د.إ', decimalPlaces: 2, flag: '🇦🇪'),
    Currency(code: 'SAR', name: 'Saudi Riyal', nameZh: '沙特里亚尔', symbol: '﷼', decimalPlaces: 2, flag: '🇸🇦'),
    Currency(code: 'THB', name: 'Thai Baht', nameZh: '泰铢', symbol: '฿', decimalPlaces: 2, flag: '🇹🇭'),
    Currency(code: 'MYR', name: 'Malaysian Ringgit', nameZh: '马来西亚林吉特', symbol: 'RM', decimalPlaces: 2, flag: '🇲🇾'),
    Currency(code: 'IDR', name: 'Indonesian Rupiah', nameZh: '印尼盾', symbol: 'Rp', decimalPlaces: 2, flag: '🇮🇩'),
    Currency(code: 'PHP', name: 'Philippine Peso', nameZh: '菲律宾比索', symbol: '₱', decimalPlaces: 2, flag: '🇵🇭'),
    Currency(code: 'VND', name: 'Vietnamese Dong', nameZh: '越南盾', symbol: '₫', decimalPlaces: 0, flag: '🇻🇳'),
    Currency(code: 'TWD', name: 'Taiwan Dollar', nameZh: '新台币', symbol: 'NT\$', decimalPlaces: 2, flag: '🇹🇼'),
    Currency(code: 'ILS', name: 'Israeli Shekel', nameZh: '以色列谢克尔', symbol: '₪', decimalPlaces: 2, flag: '🇮🇱'),
    Currency(code: 'ARS', name: 'Argentine Peso', nameZh: '阿根廷比索', symbol: '\$', decimalPlaces: 2, flag: '🇦🇷'),
    Currency(code: 'CLP', name: 'Chilean Peso', nameZh: '智利比索', symbol: '\$', decimalPlaces: 0, flag: '🇨🇱'),
    Currency(code: 'COP', name: 'Colombian Peso', nameZh: '哥伦比亚比索', symbol: '\$', decimalPlaces: 2, flag: '🇨🇴'),
    Currency(code: 'PEN', name: 'Peruvian Sol', nameZh: '秘鲁索尔', symbol: 'S/', decimalPlaces: 2, flag: '🇵🇪'),
    Currency(code: 'UAH', name: 'Ukrainian Hryvnia', nameZh: '乌克兰格里夫纳', symbol: '₴', decimalPlaces: 2, flag: '🇺🇦'),
    Currency(code: 'RON', name: 'Romanian Leu', nameZh: '罗马尼亚列伊', symbol: 'lei', decimalPlaces: 2, flag: '🇷🇴'),
    Currency(code: 'BGN', name: 'Bulgarian Lev', nameZh: '保加利亚列弗', symbol: 'лв', decimalPlaces: 2, flag: '🇧🇬'),
    Currency(code: 'ISK', name: 'Icelandic Krona', nameZh: '冰岛克朗', symbol: 'kr', decimalPlaces: 0, flag: '🇮🇸'),
  ];

  static const List<Currency> cryptoCurrencies = [
    Currency(code: 'BTC', name: 'Bitcoin', nameZh: '比特币', symbol: '₿', decimalPlaces: 8, isCrypto: true, flag: '₿'),
    Currency(code: 'ETH', name: 'Ethereum', nameZh: '以太坊', symbol: 'Ξ', decimalPlaces: 8, isCrypto: true, flag: 'Ξ'),
    Currency(code: 'USDT', name: 'Tether', nameZh: '泰达币', symbol: '₮', decimalPlaces: 6, isCrypto: true, flag: '₮'),
    Currency(code: 'BNB', name: 'Binance Coin', nameZh: '币安币', symbol: 'BNB', decimalPlaces: 8, isCrypto: true, flag: '🔸'),
    Currency(code: 'SOL', name: 'Solana', nameZh: 'Solana', symbol: 'SOL', decimalPlaces: 6, isCrypto: true, flag: '◎'),
    Currency(code: 'XRP', name: 'XRP', nameZh: '瑞波币', symbol: 'XRP', decimalPlaces: 6, isCrypto: true, flag: '✕'),
    Currency(code: 'USDC', name: 'USD Coin', nameZh: 'USD币', symbol: 'USDC', decimalPlaces: 6, isCrypto: true, flag: '💵'),
    Currency(code: 'ADA', name: 'Cardano', nameZh: '卡尔达诺', symbol: '₳', decimalPlaces: 6, isCrypto: true, flag: '₳'),
    Currency(code: 'AVAX', name: 'Avalanche', nameZh: '雪崩', symbol: 'AVAX', decimalPlaces: 8, isCrypto: true, flag: '🔺'),
    Currency(code: 'DOGE', name: 'Dogecoin', nameZh: '狗狗币', symbol: 'DOGE', decimalPlaces: 8, isCrypto: true, flag: '🐕'),
    Currency(code: 'DOT', name: 'Polkadot', nameZh: '波卡', symbol: 'DOT', decimalPlaces: 8, isCrypto: true, flag: '⚫'),
    Currency(code: 'MATIC', name: 'Polygon', nameZh: 'Polygon', symbol: 'MATIC', decimalPlaces: 8, isCrypto: true, flag: '🔷'),
    Currency(code: 'LINK', name: 'Chainlink', nameZh: 'Chainlink', symbol: 'LINK', decimalPlaces: 8, isCrypto: true, flag: '🔗'),
    Currency(code: 'LTC', name: 'Litecoin', nameZh: '莱特币', symbol: 'Ł', decimalPlaces: 8, isCrypto: true, flag: 'Ł'),
    Currency(code: 'BCH', name: 'Bitcoin Cash', nameZh: '比特币现金', symbol: 'BCH', decimalPlaces: 8, isCrypto: true, flag: '💰'),
    Currency(code: 'UNI', name: 'Uniswap', nameZh: 'Uniswap', symbol: 'UNI', decimalPlaces: 8, isCrypto: true, flag: '🦄'),
    Currency(code: 'XLM', name: 'Stellar', nameZh: '恒星币', symbol: 'XLM', decimalPlaces: 7, isCrypto: true, flag: '🌟'),
    Currency(code: 'ALGO', name: 'Algorand', nameZh: 'Algorand', symbol: 'ALGO', decimalPlaces: 6, isCrypto: true, flag: 'A'),
    Currency(code: 'ATOM', name: 'Cosmos', nameZh: 'Cosmos', symbol: 'ATOM', decimalPlaces: 6, isCrypto: true, flag: '⚛️'),
    Currency(code: 'FTM', name: 'Fantom', nameZh: 'Fantom', symbol: 'FTM', decimalPlaces: 8, isCrypto: true, flag: '👻'),
  ];

  static List<Currency> getAllCurrencies() {
    return [...fiatCurrencies, ...cryptoCurrencies];
  }

  static Currency? findByCode(String code) {
    return getAllCurrencies().firstWhere(
      (c) => c.code == code,
      orElse: () => const Currency(
        code: 'USD',
        name: 'US Dollar',
        nameZh: '美元',
        symbol: '\$',
        decimalPlaces: 2,
        flag: '🇺🇸',
      ),
    );
  }

  // Countries that restrict cryptocurrency
  static const List<String> cryptoRestrictedCountries = [
    'CN', 'IN', 'BD', 'EG', 'ID', 'IQ', 'MR', 'MA', 'NP', 'TN', 'VN',
    'AF', 'DZ', 'AO', 'BO', 'KH', 'CM', 'DO', 'EC', 'GH', 'GT', 'JO',
    'KZ', 'KW', 'LB', 'LY', 'ML', 'NE', 'NG', 'PK', 'QA', 'SA', 'SY',
    'TZ', 'TD', 'UZ', 'ZW'
  ];

  static bool isCryptoSupportedInCountry(String? countryCode) {
    if (countryCode == null) return true;
    return !cryptoRestrictedCountries.contains(countryCode.toUpperCase());
  }
}