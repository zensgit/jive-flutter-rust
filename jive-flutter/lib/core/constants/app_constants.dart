/// 应用常量定义
import 'package:flutter/material.dart';

class AppConstants {
  // 应用信息
  static const String appName = 'Jive';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Personal Finance Management';

  // API 配置
  static const String baseUrl = 'https://api.jive.app';
  static const String apiVersion = 'v1';
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // 存储配置
  static const String hiveBoxName = 'jive_data';
  static const String prefsKeyTheme = 'theme_mode';
  static const String prefsKeyLanguage = 'language';
  static const String prefsKeyOnboardingCompleted = 'onboarding_completed';
  static const String prefsKeyBiometricEnabled = 'biometric_enabled';
  static const String prefsKeyAutoSync = 'auto_sync';

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // 动画配置
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // 尺寸配置
  static const double borderRadius = 12.0;
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  // 响应式断点
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // 货币配置
  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CNY',
    'CAD',
    'AUD',
    'CHF',
    'SEK',
    'NOK',
    'DKK',
    'KRW',
    'SGD',
    'HKD',
    'INR',
    'BRL'
  ];

  static const String defaultCurrency = 'USD';

  // 语言配置
  static const List<String> supportedLanguages = [
    'en',
    'zh',
    'es',
    'fr',
    'de',
    'ja',
    'ko'
  ];

  static const String defaultLanguage = 'en';

  // 主题配置
  static const String lightTheme = 'light';
  static const String darkTheme = 'dark';
  static const String systemTheme = 'system';

  // 安全配置
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const Duration sessionTimeout = Duration(hours: 24);

  // 同步配置
  static const Duration syncInterval = Duration(minutes: 15);
  static const Duration backgroundSyncInterval = Duration(hours: 1);
  static const int maxOfflineTransactions = 1000;

  // 文件配置
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];
  static const int maxBackupFileSizeBytes = 100 * 1024 * 1024; // 100MB

  // 通知配置
  static const String notificationChannelId = 'jive_general';
  static const String notificationChannelName = 'Jive Notifications';
  static const String notificationChannelDescription =
      'General notifications from Jive';

  // 错误消息
  static const String errorGeneral = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Network connection failed. Please check your internet connection.';
  static const String errorAuth = 'Authentication failed. Please log in again.';
  static const String errorPermission =
      'Permission denied. Please grant the required permissions.';
  static const String errorNotFound = 'The requested resource was not found.';
  static const String errorServer = 'Server error. Please try again later.';
  static const String errorOffline =
      'You are offline. Some features may not be available.';

  // 成功消息
  static const String successSaved = 'Successfully saved!';
  static const String successDeleted = 'Successfully deleted!';
  static const String successUpdated = 'Successfully updated!';
  static const String successSynced = 'Data synchronized successfully!';
  static const String successLogout = 'Logged out successfully!';

  // 正则表达式
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String passwordRegex =
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$';
  static const String phoneRegex = r'^\+?[1-9]\d{1,14}$';

  // 格式化配置
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'h:mm a';
  static const String displayDateTimeFormat = 'MMM dd, yyyy h:mm a';

  // 图表配置
  static const int chartMaxDataPoints = 365; // 最大一年的数据点
  static const double chartDefaultHeight = 300.0;
  static const double chartDefaultWidth = double.infinity;

  // 导出配置
  static const List<String> supportedExportFormats = ['csv', 'xlsx', 'pdf'];
  static const String defaultExportFormat = 'csv';

  // 分类图标
  static const Map<String, String> categoryIcons = {
    'food': '🍽️',
    'transport': '🚗',
    'shopping': '🛍️',
    'entertainment': '🎬',
    'housing': '🏠',
    'healthcare': '⚕️',
    'education': '📚',
    'communication': '📱',
    'salary': '💰',
    'bonus': '🎁',
    'investment': '📈',
    'business': '💼',
    'other': '🔄',
  };

  // 系统颜色
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF06B6D4);

  // 默认颜色
  static const Map<String, String> categoryColors = {
    'food': '#EF4444',
    'transport': '#F97316',
    'shopping': '#F59E0B',
    'entertainment': '#EAB308',
    'housing': '#84CC16',
    'healthcare': '#22C55E',
    'education': '#06B6D4',
    'communication': '#3B82F6',
    'salary': '#10B981',
    'bonus': '#059669',
    'investment': '#047857',
    'business': '#065F46',
    'other': '#6B7280',
  };
}
