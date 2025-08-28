import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/currency.dart';
import '../models/exchange_rate.dart';
import '../services/exchange_rate_service.dart';
import '../services/crypto_price_service.dart';

/// Currency preferences stored in Hive
class CurrencyPreferences {
  final bool multiCurrencyEnabled;
  final bool cryptoEnabled;
  final String baseCurrency;
  final List<String> selectedCurrencies;
  final bool showCurrencyCode;
  final bool showCurrencySymbol;

  const CurrencyPreferences({
    required this.multiCurrencyEnabled,
    required this.cryptoEnabled,
    required this.baseCurrency,
    required this.selectedCurrencies,
    required this.showCurrencyCode,
    required this.showCurrencySymbol,
  });

  factory CurrencyPreferences.fromJson(Map<String, dynamic> json) {
    return CurrencyPreferences(
      multiCurrencyEnabled: json['multi_currency_enabled'] ?? false,
      cryptoEnabled: json['crypto_enabled'] ?? false,
      baseCurrency: json['base_currency'] ?? 'USD',
      selectedCurrencies: List<String>.from(json['selected_currencies'] ?? ['USD', 'CNY', 'EUR']),
      showCurrencyCode: json['show_currency_code'] ?? true,
      showCurrencySymbol: json['show_currency_symbol'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'multi_currency_enabled': multiCurrencyEnabled,
    'crypto_enabled': cryptoEnabled,
    'base_currency': baseCurrency,
    'selected_currencies': selectedCurrencies,
    'show_currency_code': showCurrencyCode,
    'show_currency_symbol': showCurrencySymbol,
  };

  CurrencyPreferences copyWith({
    bool? multiCurrencyEnabled,
    bool? cryptoEnabled,
    String? baseCurrency,
    List<String>? selectedCurrencies,
    bool? showCurrencyCode,
    bool? showCurrencySymbol,
  }) {
    return CurrencyPreferences(
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
      cryptoEnabled: cryptoEnabled ?? this.cryptoEnabled,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      showCurrencyCode: showCurrencyCode ?? this.showCurrencyCode,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
    );
  }
}

/// Currency state management
class CurrencyNotifier extends StateNotifier<CurrencyPreferences> {
  final Box _prefsBox;
  final String? _userCountry;
  final ExchangeRateService _exchangeRateService;
  final CryptoPriceService _cryptoPriceService;
  Map<String, Currency> _currencyCache = {};
  Map<String, ExchangeRate> _exchangeRates = {};
  bool _isLoadingRates = false;
  DateTime? _lastRateUpdate;
  Future<void>? _pendingRateUpdate;

  CurrencyNotifier(
    this._prefsBox, 
    this._userCountry,
    this._exchangeRateService,
    this._cryptoPriceService,
  ) : super(_loadPreferences(_prefsBox, _userCountry)) {
    _initializeCurrencyCache();
    _loadExchangeRates();
  }

  static CurrencyPreferences _loadPreferences(Box box, String? userCountry) {
    final prefs = box.get('currency_preferences');
    if (prefs != null && prefs is Map) {
      final loadedPrefs = CurrencyPreferences.fromJson(Map<String, dynamic>.from(prefs));
      
      // Check if crypto should be disabled based on country
      if (!CurrencyDefaults.isCryptoSupportedInCountry(userCountry)) {
        return loadedPrefs.copyWith(cryptoEnabled: false);
      }
      return loadedPrefs;
    }
    
    // Default preferences
    final cryptoSupported = CurrencyDefaults.isCryptoSupportedInCountry(userCountry);
    return CurrencyPreferences(
      multiCurrencyEnabled: false,
      cryptoEnabled: cryptoSupported,
      baseCurrency: 'USD',
      selectedCurrencies: ['USD', 'CNY', 'EUR', 'GBP', 'JPY'],
      showCurrencyCode: true,
      showCurrencySymbol: false,
    );
  }

  void _initializeCurrencyCache() {
    for (final currency in CurrencyDefaults.getAllCurrencies()) {
      _currencyCache[currency.code] = currency;
    }
  }

  Future<void> _loadExchangeRates() async {
    // Return existing pending update if one is in progress
    if (_pendingRateUpdate != null) {
      return _pendingRateUpdate;
    }
    
    // Create new update future
    _pendingRateUpdate = _performRateUpdate();
    
    try {
      await _pendingRateUpdate;
    } finally {
      _pendingRateUpdate = null;
    }
  }
  
  Future<void> _performRateUpdate() async {
    if (_isLoadingRates) return;
    
    _isLoadingRates = true;
    
    try {
      // Fetch real exchange rates from API
      final rates = await _exchangeRateService.getExchangeRates(state.baseCurrency);
      _exchangeRates = rates;
      _lastRateUpdate = DateTime.now();
      
      // Also fetch crypto prices if crypto is enabled
      if (state.cryptoEnabled) {
        await _loadCryptoPrices();
      }
    } catch (e) {
      print('Error loading exchange rates: $e');
      // Fallback to mock rates if API fails
      _exchangeRates = MockExchangeRates.getAllRatesFrom(state.baseCurrency);
      _lastRateUpdate = DateTime.now(); // Mark as updated even with mock data
    } finally {
      _isLoadingRates = false;
    }
  }
  
  Future<void> _loadCryptoPrices() async {
    try {
      // Get crypto prices in base currency
      final cryptoPrices = await _cryptoPriceService.getAllCryptoPrices(state.baseCurrency);
      
      // Convert to ExchangeRate objects and add to _exchangeRates
      for (final entry in cryptoPrices.entries) {
        _exchangeRates[entry.key] = ExchangeRate(
          fromCurrency: state.baseCurrency,
          toCurrency: entry.key,
          rate: 1.0 / entry.value, // Invert because price is crypto->fiat
          date: DateTime.now(),
          source: 'coingecko',
        );
      }
    } catch (e) {
      print('Error loading crypto prices: $e');
    }
  }
  
  /// Refresh exchange rates from API
  Future<void> refreshExchangeRates() async {
    await _loadExchangeRates();
  }
  
  /// Check if rates need update (older than 15 minutes)
  bool get ratesNeedUpdate {
    if (_lastRateUpdate == null) return true;
    return DateTime.now().difference(_lastRateUpdate!) > const Duration(minutes: 15);
  }

  /// Get all available currencies based on settings
  List<Currency> getAvailableCurrencies() {
    final List<Currency> currencies = [];
    
    // Add fiat currencies
    currencies.addAll(CurrencyDefaults.fiatCurrencies);
    
    // Add crypto currencies if enabled
    if (state.cryptoEnabled) {
      currencies.addAll(CurrencyDefaults.cryptoCurrencies);
    }
    
    return currencies;
  }

  /// Get selected currencies
  List<Currency> getSelectedCurrencies() {
    return state.selectedCurrencies
        .map((code) => _currencyCache[code])
        .where((c) => c != null)
        .cast<Currency>()
        .toList();
  }

  /// Get base currency
  Currency getBaseCurrency() {
    return _currencyCache[state.baseCurrency] ?? CurrencyDefaults.findByCode('USD')!;
  }

  /// Get currency by code
  Currency? getCurrencyByCode(String code) {
    return _currencyCache[code];
  }

  /// Toggle multi-currency mode
  Future<void> setMultiCurrencyMode(bool enabled) async {
    if (enabled) {
      state = state.copyWith(multiCurrencyEnabled: true);
    } else {
      // When disabling multi-currency, keep only base currency
      state = state.copyWith(
        multiCurrencyEnabled: false,
        selectedCurrencies: [state.baseCurrency],
      );
    }
    await _savePreferences();
  }

  /// Toggle crypto mode
  Future<void> setCryptoMode(bool enabled) async {
    // Check if crypto is supported in user's country
    if (enabled && !CurrencyDefaults.isCryptoSupportedInCountry(_userCountry)) {
      return; // Cannot enable crypto in restricted countries
    }
    
    if (!enabled) {
      // Remove all crypto currencies from selected list
      final nonCryptoCurrencies = state.selectedCurrencies
          .where((code) => !(_currencyCache[code]?.isCrypto ?? false))
          .toList();
      
      state = state.copyWith(
        cryptoEnabled: false,
        selectedCurrencies: nonCryptoCurrencies.isEmpty 
            ? [state.baseCurrency] 
            : nonCryptoCurrencies,
      );
    } else {
      state = state.copyWith(cryptoEnabled: true);
    }
    
    await _savePreferences();
  }

  /// Change base currency
  Future<void> setBaseCurrency(String currencyCode) async {
    if (_currencyCache[currencyCode] == null) return;
    
    // Add to selected currencies if not already there
    final selectedCurrencies = state.selectedCurrencies.toList();
    if (!selectedCurrencies.contains(currencyCode)) {
      selectedCurrencies.add(currencyCode);
    }
    
    state = state.copyWith(
      baseCurrency: currencyCode,
      selectedCurrencies: selectedCurrencies,
    );
    
    // Save preferences first
    await _savePreferences();
    
    // Then reload exchange rates with new base currency (auto-fetch from network)
    _lastRateUpdate = null; // Force refresh when base currency changes
    await _loadExchangeRates();
  }

  /// Toggle currency selection
  Future<void> toggleCurrency(String currencyCode) async {
    final selectedCurrencies = state.selectedCurrencies.toList();
    
    if (selectedCurrencies.contains(currencyCode)) {
      // Cannot remove base currency
      if (currencyCode == state.baseCurrency) return;
      
      selectedCurrencies.remove(currencyCode);
    } else {
      if (state.multiCurrencyEnabled) {
        selectedCurrencies.add(currencyCode);
      } else {
        // In single currency mode, replace the selection
        selectedCurrencies.clear();
        selectedCurrencies.add(currencyCode);
        
        // Also update base currency in single currency mode
        state = state.copyWith(baseCurrency: currencyCode);
      }
    }
    
    state = state.copyWith(selectedCurrencies: selectedCurrencies);
    await _savePreferences();
  }

  /// Get exchange rate between two currencies
  Future<ExchangeRate?> getExchangeRate(String from, String to) async {
    if (from == to) {
      return ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: 1.0,
        date: DateTime.now(),
        source: 'identity',
      );
    }
    
    // Check if we need to refresh rates
    if (ratesNeedUpdate) {
      await refreshExchangeRates();
    }
    
    // Check if either is crypto
    final fromIsCrypto = CurrencyDefaults.cryptoCurrencies.any((c) => c.code == from);
    final toIsCrypto = CurrencyDefaults.cryptoCurrencies.any((c) => c.code == to);
    
    if (fromIsCrypto || toIsCrypto) {
      // Use crypto price service for crypto conversions
      if (fromIsCrypto && !toIsCrypto) {
        // Crypto to fiat
        final price = await _cryptoPriceService.getCryptoPrice(from, to);
        if (price != null) {
          return ExchangeRate(
            fromCurrency: from,
            toCurrency: to,
            rate: price,
            date: DateTime.now(),
            source: 'coingecko',
          );
        }
      } else if (!fromIsCrypto && toIsCrypto) {
        // Fiat to crypto
        final price = await _cryptoPriceService.getCryptoPrice(to, from);
        if (price != null) {
          return ExchangeRate(
            fromCurrency: from,
            toCurrency: to,
            rate: 1.0 / price,
            date: DateTime.now(),
            source: 'coingecko',
          );
        }
      } else {
        // Crypto to crypto
        final converted = await _cryptoPriceService.convert(
          amount: 1.0,
          from: from,
          to: to,
        );
        if (converted != null) {
          return ExchangeRate(
            fromCurrency: from,
            toCurrency: to,
            rate: converted,
            date: DateTime.now(),
            source: 'coingecko',
          );
        }
      }
    }
    
    // For fiat currencies, try direct rate
    if (from == state.baseCurrency) {
      return _exchangeRates[to];
    }
    
    // Try inverse rate
    if (to == state.baseCurrency) {
      return _exchangeRates[from]?.inverse();
    }
    
    // Try to fetch specific rate from API
    final rate = await _exchangeRateService.getRate(from, to);
    if (rate != null) {
      return rate;
    }
    
    // Last resort: use mock rates
    return MockExchangeRates.getRate(from, to);
  }

  /// Convert amount between currencies
  Future<double?> convertAmount(double amount, String from, String to) async {
    final rate = await getExchangeRate(from, to);
    return rate?.convert(amount);
  }

  /// Format amount with currency
  String formatCurrency(double amount, String currencyCode) {
    final currency = _currencyCache[currencyCode];
    if (currency == null) return amount.toStringAsFixed(2);
    
    final formatted = currency.formatAmount(amount);
    return '${currency.symbol}$formatted';
  }

  /// Check if crypto is supported
  bool isCryptoSupported() {
    return CurrencyDefaults.isCryptoSupportedInCountry(_userCountry);
  }
  
  /// Set display format preferences
  Future<void> setDisplayFormat(bool showCode, bool showSymbol) async {
    // Ensure at least one is selected
    if (!showCode && !showSymbol) {
      showCode = true;
    }
    
    state = state.copyWith(
      showCurrencyCode: showCode,
      showCurrencySymbol: showSymbol,
    );
    await _savePreferences();
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    await _prefsBox.put('currency_preferences', state.toJson());
  }
}

/// Provider for currency management
final currencyProvider = StateNotifierProvider<CurrencyNotifier, CurrencyPreferences>((ref) {
  // Get user's country from settings or detect from locale
  // For now, we'll assume null (no restrictions)
  const String? userCountry = null; // TODO: Get from user settings or IP geolocation
  
  // Get or create Hive box for preferences
  final box = Hive.box('preferences');
  
  // Create service instances
  final exchangeRateService = ExchangeRateService();
  final cryptoPriceService = CryptoPriceService();
  
  return CurrencyNotifier(box, userCountry, exchangeRateService, cryptoPriceService);
});

/// Convenient providers for common currency operations
final availableCurrenciesProvider = Provider<List<Currency>>((ref) {
  return ref.watch(currencyProvider.notifier).getAvailableCurrencies();
});

final selectedCurrenciesProvider = Provider<List<Currency>>((ref) {
  ref.watch(currencyProvider);
  return ref.read(currencyProvider.notifier).getSelectedCurrencies();
});

final baseCurrencyProvider = Provider<Currency>((ref) {
  ref.watch(currencyProvider);
  return ref.read(currencyProvider.notifier).getBaseCurrency();
});

final isCryptoSupportedProvider = Provider<bool>((ref) {
  return ref.read(currencyProvider.notifier).isCryptoSupported();
});