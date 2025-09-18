import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/currency.dart';
import '../models/exchange_rate.dart';
import '../services/exchange_rate_service.dart';
import '../services/crypto_price_service.dart';
import '../services/currency_service.dart' as api;
import '../services/currency_service.dart';

// --- PR1: Currency catalog meta state (fallback / errors / sync times) ---
class CurrencyCatalogMeta {
  final bool usingFallback; // true = currently showing built-in list (server unavailable / empty)
  final String? lastError; // last error message from catalog fetch
  final DateTime? lastSyncAt; // last time a 200 response successfully refreshed catalog
  final DateTime? lastCheckedAt; // last time we attempted any catalog request (incl. 304)
  final String? etag; // last known ETag

  const CurrencyCatalogMeta({
    required this.usingFallback,
    this.lastError,
    this.lastSyncAt,
    this.lastCheckedAt,
    this.etag,
  });

  CurrencyCatalogMeta copyWith({
    bool? usingFallback,
    String? lastError,
    DateTime? lastSyncAt,
    DateTime? lastCheckedAt,
    String? etag,
  }) {
    return CurrencyCatalogMeta(
      usingFallback: usingFallback ?? this.usingFallback,
      lastError: lastError ?? this.lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      etag: etag ?? this.etag,
    );
  }
}

/// Currency preferences stored in Hive
class CurrencyPreferences {
  final bool multiCurrencyEnabled;
  final bool cryptoEnabled;
  final String baseCurrency;
  final List<String> selectedCurrencies;
  final bool showCurrencyCode;
  final bool showCurrencySymbol;
  final bool? isFallback; // null = 未知；true = 当前显示为备用汇率

  const CurrencyPreferences({
    required this.multiCurrencyEnabled,
    required this.cryptoEnabled,
    required this.baseCurrency,
    required this.selectedCurrencies,
    required this.showCurrencyCode,
    required this.showCurrencySymbol,
    this.isFallback,
  });

  factory CurrencyPreferences.fromJson(Map<String, dynamic> json) {
    return CurrencyPreferences(
      multiCurrencyEnabled: json['multi_currency_enabled'] ?? false,
      cryptoEnabled: json['crypto_enabled'] ?? false,
      baseCurrency: json['base_currency'] ?? 'USD',
      selectedCurrencies: List<String>.from(
          json['selected_currencies'] ?? ['USD', 'CNY', 'EUR']),
      showCurrencyCode: json['show_currency_code'] ?? true,
      showCurrencySymbol: json['show_currency_symbol'] ?? false,
      isFallback: json['is_fallback'],
    );
  }

  Map<String, dynamic> toJson() => {
        'multi_currency_enabled': multiCurrencyEnabled,
        'crypto_enabled': cryptoEnabled,
        'base_currency': baseCurrency,
        'selected_currencies': selectedCurrencies,
        'show_currency_code': showCurrencyCode,
        'show_currency_symbol': showCurrencySymbol,
        if (isFallback != null) 'is_fallback': isFallback,
      };

  CurrencyPreferences copyWith({
    bool? multiCurrencyEnabled,
    bool? cryptoEnabled,
    String? baseCurrency,
    List<String>? selectedCurrencies,
    bool? showCurrencyCode,
    bool? showCurrencySymbol,
    bool? isFallback,
  }) {
    return CurrencyPreferences(
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
      cryptoEnabled: cryptoEnabled ?? this.cryptoEnabled,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      selectedCurrencies: selectedCurrencies ?? this.selectedCurrencies,
      showCurrencyCode: showCurrencyCode ?? this.showCurrencyCode,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}

/// Currency state management
class CurrencyNotifier extends StateNotifier<CurrencyPreferences> {
  final Box _prefsBox;
  final String? _userCountry;
  final ExchangeRateService _exchangeRateService;
  final CryptoPriceService _cryptoPriceService;
  final CurrencyService _currencyService;
  Map<String, Currency> _currencyCache = {};
  // Server-provided currency catalog
  List<Currency> _serverCurrencies = [];
  String? _catalogEtag;
  CurrencyCatalogMeta _catalogMeta = const CurrencyCatalogMeta(usingFallback: false);
  Map<String, ExchangeRate> _exchangeRates = {};
  bool _isLoadingRates = false;
  DateTime? _lastRateUpdate;
  Future<void>? _pendingRateUpdate;
  // Manual override rates and expiry
  final Map<String, double> _manualRates = {};
  DateTime? _manualRatesExpiryUtc; // Global expiry (legacy)
  final Map<String, DateTime> _manualRatesExpiryByCurrency =
      {}; // Per-currency expiry
  static const String _kManualRatesKey = 'manual_rates';
  static const String _kManualRatesExpiryKey = 'manual_rates_expiry_utc';
  static const String _kManualRatesExpiryMapKey = 'manual_rates_expiry_map';

  bool _initialized = false;
  final bool _suppressAutoInit;

  CurrencyNotifier(
    this._prefsBox,
    this._userCountry,
    this._exchangeRateService,
    this._cryptoPriceService,
    this._currencyService, {
    bool suppressAutoInit = false,
  })  : _suppressAutoInit = suppressAutoInit,
        super(_loadPreferences(_prefsBox, _userCountry)) {
    if (!_suppressAutoInit) {
      _runInitialLoad();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await _runInitialLoad();
  }

  Future<void>? _initialLoadFuture;

  Future<void> _runInitialLoad() {
    if (_initialLoadFuture != null) return _initialLoadFuture!; // already running
    final completer = Completer<void>();
    _initialLoadFuture = completer.future;
    // Mark initialized immediately so public methods can proceed after await initialize
    _initialized = true;
    () async {
      try {
        _initializeCurrencyCache();
        await _loadSupportedCurrencies();
        _loadManualRates();
        await _loadExchangeRates();
      } finally {
        completer.complete();
      }
    }();
    return _initialLoadFuture!;
  }

  CurrencyCatalogMeta get catalogMeta => _catalogMeta;

  void _emitMetaChanged() {
    // Trigger dependents (meta not part of state object)
    state = state.copyWith();
  }

  /// Public method to trigger catalog refresh (UI can call)
  Future<void> refreshCatalog({bool force = true}) async {
    await _loadSupportedCurrencies();
  }

  // Expose last successful rate update time (for UI footer)
  DateTime? get lastUpdate => _lastRateUpdate;

  static CurrencyPreferences _loadPreferences(Box box, String? userCountry) {
    final prefs = box.get('currency_preferences');
    if (prefs != null && prefs is Map) {
      final loadedPrefs =
          CurrencyPreferences.fromJson(Map<String, dynamic>.from(prefs));

      // Check if crypto should be disabled based on country
      if (!CurrencyDefaults.isCryptoSupportedInCountry(userCountry)) {
        return loadedPrefs.copyWith(cryptoEnabled: false);
      }
      return loadedPrefs;
    }

    // Default preferences
    final cryptoSupported =
        CurrencyDefaults.isCryptoSupportedInCountry(userCountry);
    return CurrencyPreferences(
      multiCurrencyEnabled: false,
      cryptoEnabled: cryptoSupported,
      baseCurrency: 'USD',
      selectedCurrencies: ['USD', 'CNY', 'EUR', 'GBP', 'JPY'],
      showCurrencyCode: true,
      showCurrencySymbol: false,
    );
  }

  void _loadManualRates() {
    try {
      final saved = _prefsBox.get(_kManualRatesKey);
      if (saved is Map) {
        _manualRates
          ..clear()
          ..addAll(saved
              .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())));
      }
      // Load per-currency expiry map first (new schema)
      final expiryMap = _prefsBox.get(_kManualRatesExpiryMapKey);
      _manualRatesExpiryByCurrency.clear();
      if (expiryMap is Map) {
        expiryMap.forEach((k, v) {
          final dt = v is String ? DateTime.tryParse(v) : null;
          if (dt != null) {
            _manualRatesExpiryByCurrency[k.toString()] = dt.toUtc();
          }
        });
      }
      // Fallback to global expiry (legacy)
      final expiryStr = _prefsBox.get(_kManualRatesExpiryKey);
      if (expiryStr is String) {
        _manualRatesExpiryUtc = DateTime.tryParse(expiryStr)?.toUtc();
      }
    } catch (e) {
      // Ignore corrupt data
      _manualRates.clear();
      _manualRatesExpiryUtc = null;
      _manualRatesExpiryByCurrency.clear();
    }
  }

  void _initializeCurrencyCache() {
    for (final currency in CurrencyDefaults.getAllCurrencies()) {
      _currencyCache[currency.code] = currency;
    }
    // Attempt to flush any previously pending preferences early
    // (does not await to avoid slowing startup; fire-and-forget)
    tryFlushPendingPreferences();
  }

  /// Load supported currencies from server and merge into cache.
  Future<void> _loadSupportedCurrencies() async {
    final now = DateTime.now();
    _catalogMeta = _catalogMeta.copyWith(lastCheckedAt: now);
    try {
      final res = await _currencyService.getSupportedCurrenciesWithEtag(
          etag: _catalogEtag);
      if (res.notModified) {
        // 304 - catalog unchanged
        _catalogMeta = _catalogMeta.copyWith(
          lastCheckedAt: now,
          etag: res.etag ?? _catalogMeta.etag,
          usingFallback: _serverCurrencies.isEmpty, // only fallback if never loaded
        );
        _emitMetaChanged();
        return;
      }
      if (res.items.isNotEmpty) {
        // Successful refresh (200)
        _serverCurrencies = res.items.map((c) {
          final isCrypto =
              CurrencyDefaults.cryptoCurrencies.any((x) => x.code == c.code) ||
                  c.isCrypto;
          final updated = c.copyWith(isCrypto: isCrypto);
          _currencyCache[updated.code] = updated;
          return updated;
        }).toList();
        _catalogEtag = res.etag ?? _catalogEtag;
        _catalogMeta = _catalogMeta.copyWith(
          lastSyncAt: now,
          lastCheckedAt: now,
          etag: _catalogEtag,
          lastError: null,
          usingFallback: false,
        );
        await _applyServerPreferencesIfAvailable();
        // On successful catalog refresh, attempt to flush any pending preferences
        await tryFlushPendingPreferences();
        _emitMetaChanged();
      } else {
        // Empty list (possible error path) -> fallback
        _catalogMeta = _catalogMeta.copyWith(
          lastCheckedAt: now,
          lastError: res.error ?? 'Empty currency list',
          usingFallback: true,
        );
        _emitMetaChanged();
      }
    } catch (e) {
      debugPrint('Failed to load supported currencies from server: $e');
      _catalogMeta = _catalogMeta.copyWith(
        lastCheckedAt: now,
        lastError: e.toString(),
        usingFallback: true,
      );
      _emitMetaChanged();
      // Even if catalog fails, we can still try flushing pending (maybe network partially available)
      await tryFlushPendingPreferences();
    }
  }

  /// Merge server-stored user currency preferences into local state.
  Future<void> _applyServerPreferencesIfAvailable() async {
    try {
      final prefs = await _currencyService.getUserCurrencyPreferences();
      if (prefs.isEmpty) return;
      String? base;
      final List<String> selected = [];
      for (final p in prefs) {
        if (p.isPrimary) base = p.currencyCode;
        selected.add(p.currencyCode);
      }
      base ??= state.baseCurrency;
      final merged = <String>{...selected, base}.toList();
      state = state.copyWith(baseCurrency: base, selectedCurrencies: merged);
      await _savePreferences();
    } catch (e) {
      debugPrint('Failed to load user currency preferences from server: $e');
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
      // Always fetch live rates first for selected targets (no mock)
      final targets = state.selectedCurrencies
          .where((c) => c != state.baseCurrency)
          .toList();
      final rates = await _exchangeRateService.getExchangeRatesForTargets(
          state.baseCurrency, targets);
      _exchangeRates =
          rates; // may be partially empty if server missing some pairs
      // Overlay valid manual rates so they take precedence until expiry
      final nowUtc = DateTime.now().toUtc();
      if (_manualRates.isNotEmpty) {
        for (final entry in _manualRates.entries) {
          final code = entry.key;
          final value = entry.value;
          final perExpiry = _manualRatesExpiryByCurrency[code];
          final isValid = perExpiry != null
              ? nowUtc.isBefore(perExpiry)
              : (_manualRatesExpiryUtc != null &&
                  nowUtc.isBefore(_manualRatesExpiryUtc!));
          if (isValid) {
            _exchangeRates[code] = ExchangeRate(
              fromCurrency: state.baseCurrency,
              toCurrency: code,
              rate: value,
              date: DateTime.now(),
              source: 'manual',
            );
          }
        }
      }
      // Do not auto-fill missing with mock; let UI reflect missing to avoid confusion
      _lastRateUpdate = DateTime.now();
      state = state.copyWith(isFallback: _exchangeRateService.lastWasFallback);
      if (state.cryptoEnabled) {
        await _loadCryptoPrices();
      }
    } catch (e) {
      debugPrint('Error loading exchange rates: $e');
      _exchangeRates = MockExchangeRates.getAllRatesFrom(state.baseCurrency);
      _lastRateUpdate = DateTime.now();
      state = state.copyWith(isFallback: true);
    } finally {
      _isLoadingRates = false;
    }
  }

  /// Set manual fiat rates with expiry (UTC). Map keys are toCurrency codes.
  Future<void> setManualRates(
      Map<String, double> toCurrencyRates, DateTime expiryUtc) async {
    _manualRates
      ..clear()
      ..addAll(toCurrencyRates);
    _manualRatesExpiryUtc = expiryUtc.toUtc();
    await _prefsBox.put(_kManualRatesKey, _manualRates);
    await _prefsBox.put(
        _kManualRatesExpiryKey, _manualRatesExpiryUtc!.toIso8601String());
    // Clear per-currency map to use global
    await _prefsBox.delete(_kManualRatesExpiryMapKey);
    _manualRatesExpiryByCurrency.clear();
    await _savePreferences();
    // Do not fetch live immediately; keep manual active until expiry
  }

  /// Set manual rates with per-currency expiries
  Future<void> setManualRatesWithExpiries(
    Map<String, double> toCurrencyRates,
    Map<String, DateTime> expiriesUtc,
  ) async {
    _manualRates
      ..clear()
      ..addAll(toCurrencyRates);
    _manualRatesExpiryUtc = null; // use per-currency expiries
    _manualRatesExpiryByCurrency
      ..clear()
      ..addAll(expiriesUtc.map((k, v) => MapEntry(k, v.toUtc())));
    await _prefsBox.put(_kManualRatesKey, _manualRates);
    await _prefsBox.put(
      _kManualRatesExpiryMapKey,
      _manualRatesExpiryByCurrency
          .map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await _prefsBox.delete(_kManualRatesExpiryKey);
    await _savePreferences();
  }

  /// Clear manual rates (revert to automatic)
  Future<void> clearManualRates() async {
    _manualRates.clear();
    _manualRatesExpiryUtc = null;
    _manualRatesExpiryByCurrency.clear();
    await _prefsBox.delete(_kManualRatesKey);
    await _prefsBox.delete(_kManualRatesExpiryKey);
    await _prefsBox.delete(_kManualRatesExpiryMapKey);
    await _savePreferences();
    await _loadExchangeRates();
  }

  /// Clear manual rate for a single currency (revert that currency to automatic)
  Future<void> clearManualRate(String toCurrencyCode) async {
    _manualRates.remove(toCurrencyCode);
    _manualRatesExpiryByCurrency.remove(toCurrencyCode);
    await _prefsBox.put(_kManualRatesKey, _manualRates);
    await _prefsBox.put(
      _kManualRatesExpiryMapKey,
      _manualRatesExpiryByCurrency
          .map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    // If no manual entries left, clear global keys
    if (_manualRates.isEmpty && _manualRatesExpiryByCurrency.isEmpty) {
      await _prefsBox.delete(_kManualRatesKey);
      await _prefsBox.delete(_kManualRatesExpiryKey);
      await _prefsBox.delete(_kManualRatesExpiryMapKey);
    }
    await _savePreferences();
    await _loadExchangeRates();
  }

  /// Upsert a single manual rate with per-currency expiry
  Future<void> upsertManualRate(
      String toCurrencyCode, double rate, DateTime expiryUtc) async {
    _manualRates[toCurrencyCode] = rate;
    _manualRatesExpiryByCurrency[toCurrencyCode] = expiryUtc.toUtc();
    await _prefsBox.put(_kManualRatesKey, _manualRates);
    await _prefsBox.put(
      _kManualRatesExpiryMapKey,
      _manualRatesExpiryByCurrency
          .map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await _savePreferences();
    await _loadExchangeRates();
  }

  /// Expose whether manual rates are active
  bool get manualRatesActive {
    final nowUtc = DateTime.now().toUtc();
    // Active if any per-currency expiry is valid or global expiry is valid
    final anyPerActive =
        _manualRatesExpiryByCurrency.values.any((dt) => nowUtc.isBefore(dt));
    final globalActive = _manualRatesExpiryUtc != null &&
        nowUtc.isBefore(_manualRatesExpiryUtc!);
    return anyPerActive || globalActive;
  }

  /// Earliest non-expired expiry for banner display
  DateTime? get manualRatesExpiryUtc {
    final nowUtc = DateTime.now().toUtc();
    final validExpiries = _manualRatesExpiryByCurrency.values
        .where((dt) => nowUtc.isBefore(dt))
        .toList();
    validExpiries.sort();
    if (validExpiries.isNotEmpty) {
      return validExpiries.first;
    }
    return _manualRatesExpiryUtc;
  }

  Future<void> _loadCryptoPrices() async {
    try {
      // Skip if crypto is not enabled
      if (!state.cryptoEnabled) {
        return;
      }

      // Only fetch prices for selected cryptos to avoid noise
      final selectedCryptoCodes = state.selectedCurrencies
          .where((code) =>
              CurrencyDefaults.cryptoCurrencies.any((c) => c.code == code))
          .toList();

      // Get crypto prices in base currency with timeout
      final cryptoPrices = await _cryptoPriceService
          .getCryptoPricesFor(state.baseCurrency, selectedCryptoCodes)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Crypto price fetch timed out, using cached values');
        return {};
      });

      // Convert to ExchangeRate objects and add to _exchangeRates
      if (cryptoPrices.isNotEmpty) {
        final nowUtc = DateTime.now().toUtc();
        for (final entry in cryptoPrices.entries) {
          final code = entry.key;
          final price = entry.value; // crypto->fiat price
          if (price <= 0) continue;
          final manual = _manualRates[code];
          final perExpiry = _manualRatesExpiryByCurrency[code];
          final manualValid = manual != null &&
              (perExpiry != null
                  ? nowUtc.isBefore(perExpiry)
                  : (_manualRatesExpiryUtc != null &&
                      nowUtc.isBefore(_manualRatesExpiryUtc!)));
          if (manualValid) {
            // Respect manual override for crypto; do not overwrite with live price
            _exchangeRates[code] = ExchangeRate(
              fromCurrency: state.baseCurrency,
              toCurrency: code,
              rate: manual,
              date: DateTime.now(),
              source: 'manual',
            );
            continue;
          }
          _exchangeRates[code] = ExchangeRate(
            fromCurrency: state.baseCurrency,
            toCurrency: code,
            rate: 1.0 / price, // Invert because price is crypto->fiat
            date: DateTime.now(),
            source: 'coingecko',
          );
        }
      }
    } catch (e) {
      // Fail silently, crypto prices are optional
      debugPrint('Error loading crypto prices from CoinGecko: $e');
    }
  }

  /// Refresh exchange rates from API
  /// Called when:
  /// 1. App starts up
  /// 2. User opens currency/exchange rate page
  /// 3. User performs currency conversion in transaction
  Future<void> refreshExchangeRates() async {
    assert(_initialized || _suppressAutoInit,
        'CurrencyNotifier used before initialize(); call initialize() first or disable auto-init in tests.');
    await _loadExchangeRates();
  }

  /// Public: refresh only crypto prices (used by crypto selection page)
  Future<void> refreshCryptoPrices() async {
    assert(_initialized || _suppressAutoInit,
        'CurrencyNotifier used before initialize(); call initialize() first or disable auto-init in tests.');
    await _loadCryptoPrices();
  }

  /// Get all available currencies based on settings
  List<Currency> getAvailableCurrencies() {
    final List<Currency> currencies = [];
    // Prefer server catalog (fiat)
    final serverFiat = _serverCurrencies.where((c) => !c.isCrypto).toList();
    if (serverFiat.isNotEmpty) {
      currencies.addAll(serverFiat);
    } else {
      currencies.addAll(CurrencyDefaults.fiatCurrencies);
    }

    // Cryptos
    if (state.cryptoEnabled) {
      final serverCrypto = _serverCurrencies.where((c) => c.isCrypto).toList();
      if (serverCrypto.isNotEmpty) {
        currencies.addAll(serverCrypto);
      } else {
        currencies.addAll(CurrencyDefaults.cryptoCurrencies);
      }
    }

    // Ensure already-selected codes appear even if not in server list
    for (final code in state.selectedCurrencies) {
      if (!currencies.any((c) => c.code == code)) {
        final cached = _currencyCache[code];
        if (cached != null) currencies.add(cached);
      }
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

  /// Add a currency to the selected list
  Future<void> addSelectedCurrency(String currencyCode) async {
    if (!state.selectedCurrencies.contains(currencyCode)) {
      final updated = List<String>.from(state.selectedCurrencies)
        ..add(currencyCode);
      state = state.copyWith(selectedCurrencies: updated);
      await _savePreferences();
      _schedulePreferencePush();
      // Immediately fetch rates for the newly added currency
      await _loadExchangeRates();
    }
  }

  /// Remove a currency from the selected list
  Future<void> removeSelectedCurrency(String currencyCode) async {
    if (state.selectedCurrencies.contains(currencyCode)) {
      final updated = List<String>.from(state.selectedCurrencies)
        ..remove(currencyCode);
      // Ensure base currency remains in list
      if (!updated.contains(state.baseCurrency)) {
        updated.insert(0, state.baseCurrency);
      }
      state = state.copyWith(selectedCurrencies: updated);
      await _savePreferences();
      _schedulePreferencePush();
      // Refresh rates after removal to keep targets in sync
      await _loadExchangeRates();
    }
  }

  /// Get base currency
  Currency getBaseCurrency() {
    return _currencyCache[state.baseCurrency] ??
        CurrencyDefaults.findByCode('USD')!;
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
    // Reload server catalog (may include/exclude cryptos)
    await _loadSupportedCurrencies();
    // Refresh exchange rates/prices to reflect crypto mode change
    await _loadExchangeRates();
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
    _schedulePreferencePush();

    // Then reload exchange rates with new base currency
    await _loadExchangeRates();
  }

  /// Push user currency preferences to server (best-effort)
  // --- Preference sync debounce & pending retry ---
  static const _kPendingPrefsKey = 'currency_pending_prefs';
  Timer? _prefsDebounce;

  bool get hasPendingPreferences => _prefsBox.containsKey(_kPendingPrefsKey);

  void _schedulePreferencePush() {
    _prefsDebounce?.cancel();
    _prefsDebounce = Timer(const Duration(milliseconds: 500), () {
      _attemptPushPreferences();
    });
  }

  Future<void> _attemptPushPreferences() async {
    final currencies = state.selectedCurrencies;
    final primary = state.baseCurrency;
    try {
      await _currencyService.setUserCurrencyPreferences(currencies, primary);
      // Success: clear pending if present
      if (hasPendingPreferences) {
        await _prefsBox.delete(_kPendingPrefsKey);
      }
    } catch (e) {
      debugPrint('Failed to push currency preferences (will persist pending): $e');
      final pending = {
        'currencies': currencies,
        'primary': primary,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _prefsBox.put(_kPendingPrefsKey, pending);
    }
  }

  // Test-only helper to bypass debounce in unit tests
  @visibleForTesting
  Future<void> pushPreferencesNowForTest() => _attemptPushPreferences();

  Future<void> tryFlushPendingPreferences() async {
    if (!hasPendingPreferences) return;
    final data = _prefsBox.get(_kPendingPrefsKey);
    if (data is Map) {
      final currencies = List<String>.from(data['currencies'] ?? const []);
      final primary = data['primary']?.toString() ?? state.baseCurrency;
      try {
        await _currencyService.setUserCurrencyPreferences(currencies, primary);
        await _prefsBox.delete(_kPendingPrefsKey);
      } catch (_) {
        // keep pending
      }
    }
  }

  /// Toggle currency selection
  Future<void> toggleCurrency(String currencyCode) async {
    assert(_initialized || _suppressAutoInit,
        'CurrencyNotifier used before initialize(); call initialize() first or disable auto-init in tests.');
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
    // Keep exchange rates up-to-date with selection changes
    await _loadExchangeRates();
  }

  /// Get exchange rate between two currencies
  /// Auto-refreshes rates when called (for transaction conversions)
  Future<ExchangeRate?> getExchangeRate(String from, String to,
      {bool autoRefresh = true}) async {
    assert(_initialized || _suppressAutoInit,
        'CurrencyNotifier used before initialize(); call initialize() first or disable auto-init in tests.');
    if (from == to) {
      return ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: 1.0,
        date: DateTime.now(),
        source: 'identity',
      );
    }

    // Auto-refresh rates when performing conversion
    if (autoRefresh) {
      await refreshExchangeRates();
    }

    // Check if either is crypto
    final fromIsCrypto =
        CurrencyDefaults.cryptoCurrencies.any((c) => c.code == from);
    final toIsCrypto =
        CurrencyDefaults.cryptoCurrencies.any((c) => c.code == to);

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
  /// Auto-refreshes exchange rates before conversion
  Future<double?> convertAmount(double amount, String from, String to) async {
    assert(_initialized || _suppressAutoInit,
        'CurrencyNotifier used before initialize(); call initialize() first or disable auto-init in tests.');
    // Always refresh rates when converting (for transactions)
    final rate = await getExchangeRate(from, to, autoRefresh: true);
    return rate?.convert(amount);
  }

  /// Format amount with currency
  String formatCurrency(double amount, String currencyCode) {
    final currency = _currencyCache[currencyCode];
    if (currency == null) return amount.toStringAsFixed(2);
    final amt = currency.formatAmount(amount);
    if (state.showCurrencySymbol && state.showCurrencyCode) {
      return '${currency.symbol}$amt ${currency.code}';
    } else if (state.showCurrencySymbol) {
      return '${currency.symbol}$amt';
    } else if (state.showCurrencyCode) {
      return '$amt ${currency.code}';
    } else {
      // Fallback to code if both off (should not happen due to guard)
      return '$amt ${currency.code}';
    }
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
final currencyProvider =
  StateNotifierProvider<CurrencyNotifier, CurrencyPreferences>((ref) {
  // Get user's country from settings or detect from locale
  // For now, we'll assume null (no restrictions)
  const String? userCountry =
      null; // TODO: Get from user settings or IP geolocation

  // Get or create Hive box for preferences
  final box = Hive.box('preferences');

  // Create service instances
  final exchangeRateService = ExchangeRateService();
  final cryptoPriceService = CryptoPriceService();
  final currencyService = api.CurrencyService(null);

  return CurrencyNotifier(box, userCountry, exchangeRateService,
      cryptoPriceService, currencyService);
});

/// Expose catalog meta separately so UI can listen without rebuilding all currency prefs consumers
final currencyCatalogMetaProvider = Provider<CurrencyCatalogMeta>((ref) {
  ref.watch(currencyProvider); // depend on main provider updates
  return ref.read(currencyProvider.notifier).catalogMeta;
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

/// Expose current fiat/crypto exchange rates relative to base as a simple map
final exchangeRatesProvider = Provider<Map<String, double>>((ref) {
  // Rebuild when currency state changes
  ref.watch(currencyProvider);
  final notifier = ref.read(currencyProvider.notifier);
  // Build map of toCurrency -> rate from base
  final Map<String, double> map = {};
  for (final entry in notifier._exchangeRates.entries) {
    map[entry.key] = entry.value.rate;
  }
  return map;
});

/// Expose ExchangeRate objects (with source) keyed by toCurrency
final exchangeRateObjectsProvider = Provider<Map<String, ExchangeRate>>((ref) {
  ref.watch(currencyProvider);
  final notifier = ref.read(currencyProvider.notifier);
  // Return a copy to avoid external mutation
  return Map<String, ExchangeRate>.fromEntries(
    notifier._exchangeRates.entries.map((e) => MapEntry(e.key, e.value)),
  );
});

/// Expose crypto prices in base currency (code -> price in base)
final cryptoPricesProvider = Provider<Map<String, double>>((ref) {
  ref.watch(currencyProvider);
  final notifier = ref.read(currencyProvider.notifier);
  final Map<String, double> map = {};
  for (final entry in notifier._exchangeRates.entries) {
    final code = entry.key;
    final isCrypto =
        CurrencyDefaults.cryptoCurrencies.any((c) => c.code == code);
    if (isCrypto && entry.value.rate != 0) {
      map[code] = 1.0 / entry.value.rate;
    }
  }
  return map;
});
