class AdminCurrency {
  final String code;
  final String name;
  final String nameZh;
  final String symbol;
  final int decimalPlaces;
  final bool isCrypto;
  final bool isActive;
  final String? flag; // emoji or short code
  // Optional provider mappings for crypto
  final String? coingeckoId;
  final String? coincapSymbol;
  final String? binanceSymbol;
  final DateTime? updatedAt;
  final DateTime? lastRefreshedAt;

  const AdminCurrency({
    required this.code,
    required this.name,
    required this.nameZh,
    required this.symbol,
    required this.decimalPlaces,
    required this.isCrypto,
    required this.isActive,
    this.flag,
    this.coingeckoId,
    this.coincapSymbol,
    this.binanceSymbol,
    this.updatedAt,
    this.lastRefreshedAt,
  });

  factory AdminCurrency.fromJson(Map<String, dynamic> json) {
    return AdminCurrency(
      code: json['code'],
      name: json['name'] ?? json['name_en'] ?? json['code'],
      nameZh: json['name_zh'] ?? json['name_cn'] ?? json['code'],
      symbol: json['symbol'] ?? '',
      decimalPlaces: json['decimal_places'] ?? 2,
      isCrypto: json['is_crypto'] ?? false,
      isActive: json['is_active'] ?? true,
      flag: json['flag'],
      coingeckoId: json['providers']?['coingecko_id'] ?? json['coingecko_id'],
      coincapSymbol: json['providers']?['coincap_symbol'] ?? json['coincap_symbol'],
      binanceSymbol: json['providers']?['binance_symbol'] ?? json['binance_symbol'],
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      lastRefreshedAt: json['last_refreshed_at'] != null ? DateTime.tryParse(json['last_refreshed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'name_zh': nameZh,
      'symbol': symbol,
      'decimal_places': decimalPlaces,
      'is_crypto': isCrypto,
      'is_active': isActive,
      if (flag != null) 'flag': flag,
      'providers': {
        if (coingeckoId != null) 'coingecko_id': coingeckoId,
        if (coincapSymbol != null) 'coincap_symbol': coincapSymbol,
        if (binanceSymbol != null) 'binance_symbol': binanceSymbol,
      }
    };
  }

  AdminCurrency copyWith({
    String? code,
    String? name,
    String? nameZh,
    String? symbol,
    int? decimalPlaces,
    bool? isCrypto,
    bool? isActive,
    String? flag,
    String? coingeckoId,
    String? coincapSymbol,
    String? binanceSymbol,
  }) {
    return AdminCurrency(
      code: code ?? this.code,
      name: name ?? this.name,
      nameZh: nameZh ?? this.nameZh,
      symbol: symbol ?? this.symbol,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      isCrypto: isCrypto ?? this.isCrypto,
      isActive: isActive ?? this.isActive,
      flag: flag ?? this.flag,
      coingeckoId: coingeckoId ?? this.coingeckoId,
      coincapSymbol: coincapSymbol ?? this.coincapSymbol,
      binanceSymbol: binanceSymbol ?? this.binanceSymbol,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }
}

class CurrencyAliasDto {
  final String oldCode;
  final String newCode;
  final DateTime? validUntil;

  CurrencyAliasDto({required this.oldCode, required this.newCode, this.validUntil});

  Map<String, dynamic> toJson() => {
    'old_code': oldCode,
    'new_code': newCode,
    if (validUntil != null) 'valid_until': validUntil!.toIso8601String(),
  };
}
