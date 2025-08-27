import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 设置数据模型
class AppSettings {
  final String defaultCurrency;
  final bool autoUpdateRates;
  final bool budgetNotifications;
  final bool darkMode;
  final String language;
  final bool biometricEnabled;
  final bool autoBackup;
  final int backupFrequency; // 天数
  final String dateFormat;
  final String numberFormat;
  final bool showDecimals;
  final ThemeMode themeMode;
  
  AppSettings({
    this.defaultCurrency = 'CNY - 人民币',
    this.autoUpdateRates = true,
    this.budgetNotifications = true,
    this.darkMode = false,
    this.language = 'zh_CN',
    this.biometricEnabled = false,
    this.autoBackup = true,
    this.backupFrequency = 7,
    this.dateFormat = 'yyyy-MM-dd',
    this.numberFormat = '#,##0.00',
    this.showDecimals = true,
    this.themeMode = ThemeMode.system,
  });
  
  // Helper methods for compatibility
  String? getThemeMode() {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
  
  Future<void> setThemeMode(String? mode) async {
    // This will be handled by the notifier
  }
  
  String? getLanguage() {
    return language;
  }
  
  Future<void> setLanguage(String? lang) async {
    // This will be handled by the notifier
  }

  AppSettings copyWith({
    String? defaultCurrency,
    bool? autoUpdateRates,
    bool? budgetNotifications,
    bool? darkMode,
    String? language,
    bool? biometricEnabled,
    bool? autoBackup,
    int? backupFrequency,
    String? dateFormat,
    String? numberFormat,
    bool? showDecimals,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      autoUpdateRates: autoUpdateRates ?? this.autoUpdateRates,
      budgetNotifications: budgetNotifications ?? this.budgetNotifications,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoBackup: autoBackup ?? this.autoBackup,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      dateFormat: dateFormat ?? this.dateFormat,
      numberFormat: numberFormat ?? this.numberFormat,
      showDecimals: showDecimals ?? this.showDecimals,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

// 设置状态管理
class SettingsNotifier extends StateNotifier<AppSettings> {
  late SharedPreferences _prefs;
  
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    state = AppSettings(
      defaultCurrency: _prefs.getString('defaultCurrency') ?? 'CNY - 人民币',
      autoUpdateRates: _prefs.getBool('autoUpdateRates') ?? true,
      budgetNotifications: _prefs.getBool('budgetNotifications') ?? true,
      darkMode: _prefs.getBool('darkMode') ?? false,
      language: _prefs.getString('language') ?? 'zh_CN',
      biometricEnabled: _prefs.getBool('biometricEnabled') ?? false,
      autoBackup: _prefs.getBool('autoBackup') ?? true,
      backupFrequency: _prefs.getInt('backupFrequency') ?? 7,
      dateFormat: _prefs.getString('dateFormat') ?? 'yyyy-MM-dd',
      numberFormat: _prefs.getString('numberFormat') ?? '#,##0.00',
      showDecimals: _prefs.getBool('showDecimals') ?? true,
    );
  }

  Future<void> updateSetting(String key, dynamic value) async {
    // 保存到SharedPreferences
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }

    // 更新状态
    switch (key) {
      case 'defaultCurrency':
        state = state.copyWith(defaultCurrency: value as String);
        break;
      case 'autoUpdateRates':
        state = state.copyWith(autoUpdateRates: value as bool);
        break;
      case 'budgetNotifications':
        state = state.copyWith(budgetNotifications: value as bool);
        break;
      case 'darkMode':
        state = state.copyWith(darkMode: value as bool);
        break;
      case 'language':
        state = state.copyWith(language: value as String);
        break;
      case 'biometricEnabled':
        state = state.copyWith(biometricEnabled: value as bool);
        break;
      case 'autoBackup':
        state = state.copyWith(autoBackup: value as bool);
        break;
      case 'backupFrequency':
        state = state.copyWith(backupFrequency: value as int);
        break;
      case 'dateFormat':
        state = state.copyWith(dateFormat: value as String);
        break;
      case 'numberFormat':
        state = state.copyWith(numberFormat: value as String);
        break;
      case 'showDecimals':
        state = state.copyWith(showDecimals: value as bool);
        break;
    }
  }

  Future<void> resetSettings() async {
    // 清除所有设置
    await _prefs.clear();
    
    // 重置为默认值
    state = AppSettings();
  }
}

// 设置Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

// 当前用户Provider（从auth_provider导入）
final currentUserProvider = Provider<dynamic>((ref) {
  // TODO: 从auth_provider获取当前用户
  return {
    'name': '测试用户',
    'email': 'test@example.com',
    'avatar': null,
  };
});

// 账户分组Provider
final accountGroupsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 实现账户分组数据获取
  return [
    {'id': '1', 'name': '日常账户', 'color': 0xFF4CAF50},
    {'id': '2', 'name': '投资账户', 'color': 0xFF2196F3},
    {'id': '3', 'name': '信用卡', 'color': 0xFFF44336},
  ];
});

// 最近交易Provider
final recentTransactionsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 实现最近交易数据获取
  return [];
});