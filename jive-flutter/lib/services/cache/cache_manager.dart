import 'package:shared_preferences/shared_preferences.dart';

/// Simple cache manager using SharedPreferences
class CacheManager {
  SharedPreferences? _prefs;

  /// Initialize the cache manager
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get string value from cache
  String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Set string value in cache
  Future<void> setString(String key, String value) async {
    await init();
    await _prefs?.setString(key, value);
  }

  /// Get DateTime from cache
  DateTime? getDateTime(String key) {
    final timestamp = _prefs?.getInt(key);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Set DateTime in cache
  Future<void> setDateTime(String key, DateTime dateTime) async {
    await init();
    await _prefs?.setInt(key, dateTime.millisecondsSinceEpoch);
  }

  /// Clear specific key from cache
  Future<void> remove(String key) async {
    await init();
    await _prefs?.remove(key);
  }

  /// Clear all cache
  Future<void> clear() async {
    await init();
    await _prefs?.clear();
  }
}