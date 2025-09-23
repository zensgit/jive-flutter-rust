// API-specific currency models that work with the backend

class ExchangeRate {
  final String id;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final String source;
  final DateTime effectiveDate;
  final DateTime createdAt;

  ExchangeRate({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.source,
    required this.effectiveDate,
    required this.createdAt,
  });

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      id: json['id'],
      fromCurrency: json['from_currency'],
      toCurrency: json['to_currency'],
      rate: (json['rate'] is String)
          ? double.parse(json['rate'])
          : json['rate'].toDouble(),
      source: json['source'],
      effectiveDate: DateTime.parse(json['effective_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class CurrencyPreference {
  final String currencyCode;
  final bool isPrimary;
  final int displayOrder;

  CurrencyPreference({
    required this.currencyCode,
    required this.isPrimary,
    required this.displayOrder,
  });

  factory CurrencyPreference.fromJson(Map<String, dynamic> json) {
    return CurrencyPreference(
      currencyCode: json['currency_code'],
      isPrimary: json['is_primary'] ?? false,
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency_code': currencyCode,
        'is_primary': isPrimary,
        'display_order': displayOrder,
      };
}

class FamilyCurrencySettings {
  final String familyId;
  final String baseCurrency;
  final bool allowMultiCurrency;
  final bool autoConvert;
  final List<String> supportedCurrencies;

  FamilyCurrencySettings({
    required this.familyId,
    required this.baseCurrency,
    required this.allowMultiCurrency,
    required this.autoConvert,
    required this.supportedCurrencies,
  });

  factory FamilyCurrencySettings.fromJson(Map<String, dynamic> json) {
    return FamilyCurrencySettings(
      familyId: json['family_id'],
      baseCurrency: json['base_currency'],
      allowMultiCurrency: json['allow_multi_currency'] ?? true,
      autoConvert: json['auto_convert'] ?? false,
      supportedCurrencies:
          List<String>.from(json['supported_currencies'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'family_id': familyId,
        'base_currency': baseCurrency,
        'allow_multi_currency': allowMultiCurrency,
        'auto_convert': autoConvert,
        'supported_currencies': supportedCurrencies,
      };
}

class ExchangePair {
  final String from;
  final String to;
  final String name;

  ExchangePair({
    required this.from,
    required this.to,
    required this.name,
  });

  factory ExchangePair.fromJson(Map<String, dynamic> json) {
    return ExchangePair(
      from: json['from'],
      to: json['to'],
      name: json['name'],
    );
  }
}

class ConvertAmountRequest {
  final double amount;
  final String fromCurrency;
  final String toCurrency;
  final DateTime? date;

  ConvertAmountRequest({
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
    this.date,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'from_currency': fromCurrency,
        'to_currency': toCurrency,
        if (date != null) 'date': date!.toIso8601String().substring(0, 10),
      };
}

class ConvertAmountResponse {
  final double originalAmount;
  final double convertedAmount;
  final String fromCurrency;
  final String toCurrency;
  final double exchangeRate;

  ConvertAmountResponse({
    required this.originalAmount,
    required this.convertedAmount,
    required this.fromCurrency,
    required this.toCurrency,
    required this.exchangeRate,
  });

  factory ConvertAmountResponse.fromJson(Map<String, dynamic> json) {
    return ConvertAmountResponse(
      originalAmount: (json['original_amount'] is String)
          ? double.parse(json['original_amount'])
          : json['original_amount'].toDouble(),
      convertedAmount: (json['converted_amount'] is String)
          ? double.parse(json['converted_amount'])
          : json['converted_amount'].toDouble(),
      fromCurrency: json['from_currency'],
      toCurrency: json['to_currency'],
      exchangeRate: (json['exchange_rate'] is String)
          ? double.parse(json['exchange_rate'])
          : json['exchange_rate'].toDouble(),
    );
  }
}

class UpdateCurrencySettingsRequest {
  final String? baseCurrency;
  final bool? allowMultiCurrency;
  final bool? autoConvert;
  final List<String>? supportedCurrencies;

  UpdateCurrencySettingsRequest({
    this.baseCurrency,
    this.allowMultiCurrency,
    this.autoConvert,
    this.supportedCurrencies,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (baseCurrency != null) json['base_currency'] = baseCurrency;
    if (allowMultiCurrency != null) {
      json['allow_multi_currency'] = allowMultiCurrency;
    }
    if (autoConvert != null) json['auto_convert'] = autoConvert;
    if (supportedCurrencies != null) {
      json['supported_currencies'] = supportedCurrencies;
    }
    return json;
  }
}

class ApiCurrency {
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final bool isActive;

  ApiCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.isActive,
  });

  factory ApiCurrency.fromJson(Map<String, dynamic> json) {
    return ApiCurrency(
      code: json['code'],
      name: json['name'],
      symbol: json['symbol'],
      decimalPlaces: json['decimal_places'] ?? 2,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'symbol': symbol,
      'decimal_places': decimalPlaces,
      'is_active': isActive,
    };
  }
}
