import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jive_money/models/currency.dart';
import 'package:jive_money/models/exchange_rate.dart';
import 'package:jive_money/services/exchange_rate_service.dart';
import 'package:jive_money/services/crypto_price_service.dart';
import 'package:jive_money/services/currency_service.dart' as api;
import 'package:jive_money/services/currency_service.dart';
import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/core/network/api_readiness.dart';

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
  final Map<String, Currency> _currencyCache = {};
  // Server-provided currency catalog
  List<Currency> _serverCurrencies = [];
  String? _catalogEtag;
  CurrencyCatalogMeta _catalogMeta = const CurrencyCatalogMeta(usingFallback: false);
  Map<String, ExchangeRate> _exchangeRates = {};
  // Per-currency manual expiry (from server detailed response, local time)
  final Map<String, DateTime?> _manualExpiryMeta = {};
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
  static const String _kCachedRatesKey = 'cached_exchange_rates';
  static const String _kCachedRatesTimestampKey = 'cached_rates_timestamp';

  bool _initialized = false;
  final bool _suppressAutoInit;
  bool _disposed = false;

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
        // ⚡ v3.1: Load cached rates immediately (synchronous, instant)
        _loadCachedRates();
        // ⚡ v3.1: Overlay manual rates on cached data immediately
        _overlayManualRates();
        // Trigger UI update with cached data immediately
        state = state.copyWith();
        debugPrint('[CurrencyProvider] Loaded cached rates with manual overlay, UI can display immediately');
        // Refresh from API in background (non-blocking)
        _loadExchangeRates().then((_) {
          debugPrint('[CurrencyProvider] Background rate refresh completed');
        });
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
        // DEBUG: Log loaded manual rates
        debugPrint('[CurrencyProvider] Loaded ${_manualRates.length} manual rates from Hive:');
        _manualRates.forEach((code, rate) {
          debugPrint('  $code = $rate');
        });
      } else {
        debugPrint('[CurrencyProvider] No manual rates found in Hive');
      }
      // Load per-currency expiry map first (new schema)
      final expiryMap = _prefsBox.get(_kManualRatesExpiryMapKey);
      _manualRatesExpiryByCurrency.clear();
      if (expiryMap is Map) {
        expiryMap.forEach((k, v) {
          final dt = v is String ? DateTime.tryParse(v) : null;
          if (dt != null) {
            _manualRatesExpiryByCurrency[k.toString()] = dt.toUtc();
            debugPrint('[CurrencyProvider] Expiry for ${k.toString()}: $dt');
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
      debugPrint('[CurrencyProvider] Error loading manual rates: $e');
      _manualRates.clear();
      _manualRatesExpiryUtc = null;
      _manualRatesExpiryByCurrency.clear();
    }
  }

  /// Load cached exchange rates from Hive for instant display
  /// ⚡ v3.2: Filter out manual rates (they are loaded separately from _kManualRatesKey)
  void _loadCachedRates() {
    try {
      final cached = _prefsBox.get(_kCachedRatesKey);
      final timestampStr = _prefsBox.get(_kCachedRatesTimestampKey);

      debugPrint('[CurrencyProvider] 🔍 Loading cached rates...');
      debugPrint('[CurrencyProvider] Cached data exists: ${cached != null}');
      debugPrint('[CurrencyProvider] Timestamp exists: ${timestampStr != null}');

      if (cached is Map && timestampStr is String) {
        _lastRateUpdate = DateTime.tryParse(timestampStr);
        debugPrint('[CurrencyProvider] Found ${cached.length} cached entries');

        // Load cached rates into _exchangeRates
        int loadedCount = 0;
        int skippedManual = 0;
        cached.forEach((key, value) {
          if (value is Map) {
            try {
              final code = key.toString();
              final rate = (value['rate'] as num?)?.toDouble() ?? 1.0;
              final dateStr = value['date']?.toString();
              final source = value['source']?.toString() ?? 'cached';

              // ⚡ v3.2: Skip manual rates from cache (should not exist, but filter for safety)
              if (source == 'manual') {
                skippedManual++;
                debugPrint('[CurrencyProvider]   ⏭️  Skipped manual rate in cache: $code (will load from _kManualRatesKey)');
                return;
              }

              _exchangeRates[code] = ExchangeRate(
                fromCurrency: value['from']?.toString() ?? state.baseCurrency,
                toCurrency: code,
                rate: rate,
                date: dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now(),
                source: source,
              );
              loadedCount++;
              debugPrint('[CurrencyProvider]   → Loaded $code: rate=$rate, source=$source');
            } catch (e) {
              debugPrint('[CurrencyProvider] ❌ Error parsing cached rate for $key: $e');
            }
          }
        });

        debugPrint('[CurrencyProvider] ⚡ Loaded $loadedCount cached rates from Hive (instant display)');
        if (skippedManual > 0) {
          debugPrint('[CurrencyProvider] ⚠️  Skipped $skippedManual manual rates in cache (data cleanup needed)');
        }
        debugPrint('[CurrencyProvider] _exchangeRates now has ${_exchangeRates.length} entries');
        if (_lastRateUpdate != null) {
          final age = DateTime.now().difference(_lastRateUpdate!);
          debugPrint('[CurrencyProvider] Cache age: ${age.inMinutes} minutes');
        }
      } else {
        debugPrint('[CurrencyProvider] ⚠️ No cached rates found in Hive (cached=${cached?.runtimeType}, timestamp=$timestampStr)');
      }
    } catch (e) {
      debugPrint('[CurrencyProvider] ❌ Error loading cached rates: $e');
      _exchangeRates.clear();
    }
  }

  /// Overlay valid manual rates onto _exchangeRates so they take precedence until expiry
  void _overlayManualRates() {
    final nowUtc = DateTime.now().toUtc();
    debugPrint('[CurrencyProvider] 🔄 Starting manual rate overlay...');
    debugPrint('[CurrencyProvider] _manualRates.length = ${_manualRates.length}');
    debugPrint('[CurrencyProvider] _exchangeRates.length (before overlay) = ${_exchangeRates.length}');

    if (_manualRates.isNotEmpty) {
      debugPrint('[CurrencyProvider] Overlaying ${_manualRates.length} manual rates...');
      for (final entry in _manualRates.entries) {
        final code = entry.key;
        final value = entry.value;
        final perExpiry = _manualRatesExpiryByCurrency[code];
        final isValid = perExpiry != null
            ? nowUtc.isBefore(perExpiry)
            : (_manualRatesExpiryUtc != null &&
                nowUtc.isBefore(_manualRatesExpiryUtc!));

        debugPrint('[CurrencyProvider]   Checking $code: value=$value, perExpiry=$perExpiry, isValid=$isValid');

        if (isValid) {
          _exchangeRates[code] = ExchangeRate(
            fromCurrency: state.baseCurrency,
            toCurrency: code,
            rate: value,
            date: DateTime.now(),
            source: 'manual',
          );
          debugPrint('[CurrencyProvider]   ✅ Overlaid manual rate: $code = $value (expiry: ${perExpiry?.toLocal()})');
        } else {
          debugPrint('[CurrencyProvider]   ❌ Skipped expired manual rate: $code = $value');
        }
      }
    } else {
      debugPrint('[CurrencyProvider] ⚠️ No manual rates to overlay');
    }

    debugPrint('[CurrencyProvider] _exchangeRates.length (after overlay) = ${_exchangeRates.length}');
    debugPrint('[CurrencyProvider] Final _exchangeRates keys: ${_exchangeRates.keys.toList()}');
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
        // Trust the API's is_crypto classification directly
        _serverCurrencies = res.items.map((c) {
          _currencyCache[c.code] = c;
          return c;
        }).toList();

        // DEBUG: Log first 20 currencies to verify isCrypto values
        print('[CurrencyProvider] Loaded ${_serverCurrencies.length} currencies from API');
        final fiatCount = _serverCurrencies.where((c) => !c.isCrypto).length;
        final cryptoCount = _serverCurrencies.where((c) => c.isCrypto).length;
        print('[CurrencyProvider] Fiat: $fiatCount, Crypto: $cryptoCount');
        print('[CurrencyProvider] First 20 currencies:');
        for (var i = 0; i < _serverCurrencies.length && i < 20; i++) {
          final c = _serverCurrencies[i];
          print('  ${c.code}: isCrypto=${c.isCrypto}');
        }
        // Check problem currencies specifically
        final problemCodes = ['MKR', 'AAVE', 'COMP', '1INCH', 'ADA', 'AGIX', 'PEPE', 'SOL', 'MATIC', 'UNI'];
        print('[CurrencyProvider] Problem currencies:');
        for (final code in problemCodes) {
          try {
            final c = _serverCurrencies.firstWhere((x) => x.code == code);
            print('  $code: isCrypto=${c.isCrypto}');
          } catch (e) {
            print('  $code: NOT FOUND in server currencies');
          }
        }
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
    if (_isLoadingRates || _disposed) return;

    _isLoadingRates = true;

    try {
      // Check if disposed before continuing
      if (_disposed) return;

      // Always fetch live rates first for selected targets (no mock)
      final targets = state.selectedCurrencies
          .where((c) => c != state.baseCurrency)
          .toList();
      final rates = await _exchangeRateService.getExchangeRatesForTargets(
          state.baseCurrency, targets);
      _exchangeRates =
          rates; // may be partially empty if server missing some pairs
      // Fetch manual expiry meta in parallel (best-effort)
      try {
        final dio = HttpClient.instance.dio;
        final resp = await dio.post('/currencies/rates-detailed', data: {
          'base_currency': state.baseCurrency,
          'target_currencies': targets,
        });
        final data = resp.data['data'] ?? resp.data;
        final rmap = (data['rates'] as Map?) ?? {};
        _manualExpiryMeta.clear();
        rmap.forEach((code, item) {
          if (item is Map && item['manual_rate_expiry'] != null) {
            final dt = DateTime.tryParse(item['manual_rate_expiry'].toString());
            _manualExpiryMeta[code.toString()] = dt?.toLocal();
          }
        });
      } catch (_) {
        // ignore meta failures
      }
      // ⚡ v3.1: Overlay valid manual rates using shared method
      _overlayManualRates();
      // Do not auto-fill missing with mock; let UI reflect missing to avoid confusion
      _lastRateUpdate = DateTime.now();
      // Save rates to cache for instant display next time
      await _saveCachedRates();
      state = state.copyWith(isFallback: _exchangeRateService.lastWasFallback);
      if (state.cryptoEnabled) {
        await _loadCryptoPrices();
      }
    } catch (e) {
      debugPrint('Error loading exchange rates: $e');
      if (!_disposed) {
        _exchangeRates = MockExchangeRates.getAllRatesFrom(state.baseCurrency);
        _lastRateUpdate = DateTime.now();
        state = state.copyWith(isFallback: true);
      }
    } finally {
      _isLoadingRates = false;
    }
  }

  /// Save current exchange rates to Hive cache for instant display on next load
  /// ⚡ v3.2: Exclude manual rates from cache (they are stored separately)
  Future<void> _saveCachedRates() async {
    try {
      final cacheData = <String, Map<String, dynamic>>{};

      _exchangeRates.forEach((code, rate) {
        // ⚡ v3.2: Skip manual rates - they are stored in _kManualRatesKey
        if (rate.source == 'manual') {
          debugPrint('[CurrencyProvider]   ⏭️  Skipping manual rate: $code (stored separately)');
          return;
        }

        cacheData[code] = {
          'from': rate.fromCurrency,
          'rate': rate.rate,
          'date': rate.date.toIso8601String(),
          'source': rate.source,
        };
      });

      await _prefsBox.put(_kCachedRatesKey, cacheData);
      await _prefsBox.put(_kCachedRatesTimestampKey, DateTime.now().toIso8601String());

      debugPrint('[CurrencyProvider] 💾 Saved ${cacheData.length} rates to cache (excluding manual rates)');
    } catch (e) {
      debugPrint('[CurrencyProvider] Error saving cached rates: $e');
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

    // Persist to backend per-currency
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      for (final entry in toCurrencyRates.entries) {
        final code = entry.key;
        final rate = entry.value;
        final expiry = expiriesUtc[code]?.toUtc();
        await dio.post('/currencies/rates/add', data: {
          'from_currency': state.baseCurrency,
          'to_currency': code,
          'rate': rate,
          'source': 'manual',
          if (expiry != null) 'manual_rate_expiry': expiry.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Failed to persist manual rates: $e');
    }
  }

  /// Clear manual rates (revert to automatic)
  Future<void> clearManualRates() async {
    // Store codes that had manual rates for immediate removal
    final manualCodes = _manualRates.keys.toList();

    _manualRates.clear();
    _manualRatesExpiryUtc = null;
    _manualRatesExpiryByCurrency.clear();
    await _prefsBox.delete(_kManualRatesKey);
    await _prefsBox.delete(_kManualRatesExpiryKey);
    await _prefsBox.delete(_kManualRatesExpiryMapKey);
    await _savePreferences();

    // ✅ FIX: Immediately remove all manual rates from _exchangeRates so UI shows "loading" or cached auto rates
    // This prevents stale manual rates from being displayed while waiting for API refresh
    for (final code in manualCodes) {
      _exchangeRates.remove(code);
      debugPrint('[CurrencyProvider] ✅ Immediately removed manual rate from _exchangeRates[$code]');
    }

    // Trigger UI rebuild immediately so user sees the change instantly
    state = state.copyWith();
    debugPrint('[CurrencyProvider] ✅ UI state updated, ${manualCodes.length} manual rates removed, will fetch auto rates in background');

    // 同步清除服务端该基础货币下的所有手动汇率
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      await dio.post('/currencies/rates/clear-manual-batch', data: {
        'from_currency': state.baseCurrency,
      });
    } catch (e) {
      debugPrint('Failed to batch clear manual rates on server: $e');
    }

    // Background refresh to fetch automatic rates (non-blocking)
    // This will load the automatic rates from API and update UI when ready
    _loadExchangeRates().then((_) {
      debugPrint('[CurrencyProvider] Background rate refresh completed, automatic rates should be displayed now');
    });
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

    // ✅ FIX v4.1: Immediately remove manual rate from _exchangeRates so UI shows "loading" or cached auto rate
    // This prevents the stale manual rate from being displayed while waiting for API refresh
    _exchangeRates.remove(toCurrencyCode);
    debugPrint('[CurrencyProvider] ✅ Immediately removed manual rate from _exchangeRates[$toCurrencyCode]');

    // Trigger UI rebuild immediately so user sees the change instantly
    state = state.copyWith();
    debugPrint('[CurrencyProvider] ✅ UI state updated, manual rate removed, will fetch auto rate in background');

    // Persist to backend: clear today's manual flag for this pair
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      await dio.post('/currencies/rates/clear-manual', data: {
        'from_currency': state.baseCurrency,
        'to_currency': toCurrencyCode,
      });
    } catch (e) {
      debugPrint('Failed to clear manual rate on server: $e');
    }

    // Background refresh to fetch automatic rate (non-blocking, optional)
    // This will load the automatic rate from API and update UI when ready
    _loadExchangeRates().then((_) {
      debugPrint('[CurrencyProvider] Background rate refresh completed, automatic rate should be displayed now');
    });
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

    // Persist to backend (best-effort, don't block on failure)
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      await dio.post('/currencies/rates/add', data: {
        'from_currency': state.baseCurrency,
        'to_currency': toCurrencyCode,
        'rate': rate,
        'source': 'manual',
        'manual_rate_expiry': expiryUtc.toIso8601String(),
      });
      debugPrint('✅ Manual rate saved to database: $toCurrencyCode = $rate, expiry: ${expiryUtc.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Failed to persist manual rate to server: $e');
      // Don't rethrow - allow local save to succeed even if server sync fails
    }

    // ✅ FIX v4.0: Immediately update _exchangeRates and trigger UI update
    // This ensures the manual rate is visible instantly without waiting for background refresh
    _exchangeRates[toCurrencyCode] = ExchangeRate(
      fromCurrency: state.baseCurrency,
      toCurrency: toCurrencyCode,
      rate: rate,
      date: DateTime.now(),
      source: 'manual',
    );
    debugPrint('[CurrencyProvider] ✅ Immediately updated _exchangeRates[$toCurrencyCode] = $rate (manual)');

    // Trigger UI rebuild immediately so user sees the new manual rate
    state = state.copyWith();
    debugPrint('[CurrencyProvider] ✅ UI state updated, manual rate should be visible now');

    // Background refresh other rates (non-blocking, optional)
    // This ensures manual rate persists even after background refresh completes
    _loadExchangeRates().then((_) {
      debugPrint('[CurrencyProvider] Background rate refresh completed, manual rates re-overlaid');
    });
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

  /// Manual expiry for specific currency (local time if provided by server)
  DateTime? manualExpiryFor(String toCurrencyCode) => _manualExpiryMeta[toCurrencyCode];

  Future<void> _loadCryptoPrices() async {
    try {
      // Skip if crypto is not enabled
      if (!state.cryptoEnabled) {
        return;
      }

      // Only fetch prices for selected cryptos to avoid noise
      // Use currency cache to check if it's crypto (respects API classification)
      final selectedCryptoCodes = state.selectedCurrencies
          .where((code) {
            final currency = _currencyCache[code];
            return currency?.isCrypto ?? false;
          })
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
      // Save updated rates (including crypto) to cache
      await _saveCachedRates();
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

  /// Get all cryptocurrencies (for management page)
  /// Returns all crypto currencies regardless of cryptoEnabled setting
  /// This allows users to see and select from all available cryptocurrencies
  List<Currency> getAllCryptoCurrencies() {
    // Prefer server catalog
    final serverCrypto = _serverCurrencies.where((c) => c.isCrypto).toList();
    if (serverCrypto.isNotEmpty) {
      return serverCrypto;
    }
    // Fallback to default list
    return CurrencyDefaults.cryptoCurrencies;
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

  /// 检查汇率是否需要更新
  bool get ratesNeedUpdate {
    // 简单实现：检查汇率是否过期（如果有上次更新时间）
    if (_lastRateUpdate == null) return true;

    final now = DateTime.now();
    final timeSinceUpdate = now.difference(_lastRateUpdate!);

    // 如果超过1小时未更新，认为需要更新
    return timeSinceUpdate.inHours >= 1;
  }

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

    // Check if either is crypto using currency cache (respects API classification)
    final fromCurrency = _currencyCache[from];
    final toCurrency = _currencyCache[to];
    final fromIsCrypto = fromCurrency?.isCrypto ?? false;
    final toIsCrypto = toCurrency?.isCrypto ?? false;

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

  @override
  void dispose() {
    _disposed = true;
    _pendingRateUpdate = null;
    super.dispose();
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
    // Use currency cache to check if it's crypto (respects API classification)
    final currency = notifier._currencyCache[code];
    final isCrypto = currency?.isCrypto ?? false;
    if (isCrypto && entry.value.rate != 0) {
      map[code] = 1.0 / entry.value.rate;
    }
  }
  return map;
});
