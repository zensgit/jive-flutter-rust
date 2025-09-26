/// API Constants
library;
import 'package:jive_money/core/config/api_config.dart';

class ApiConstants {
  // 统一使用 ApiConfig.apiUrl，避免环境切换不一致
  static String get baseUrl => ApiConfig.apiUrl;

  // Authentication endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/profile';

  // Currency endpoints
  static const String currencies = '/currencies';
  static const String exchangeRates = '/exchange-rates';
  static const String currencyConvert = '/currencies/convert';

  // Transaction endpoints
  static const String transactions = '/transactions';
  static const String accounts = '/accounts';
  static const String budgets = '/budgets';

  // Family endpoints
  static const String familyMembers = '/family/members';
  static const String familySettings = '/family/settings';
}

/// App Constants
class AppConstants {
  static const String appName = 'Jive Money';
  static const String appVersion = '1.0.0';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String preferencesKey = 'preferences';

  // Defaults
  static const String defaultCurrency = 'USD';
  static const String defaultLanguage = 'zh';
  static const String defaultDateFormat = 'yyyy-MM-dd';
}

/// Error Messages
class ErrorMessages {
  static const String networkError = '网络连接失败，请检查网络设置';
  static const String serverError = '服务器错误，请稍后重试';
  static const String authError = '认证失败，请重新登录';
  static const String invalidInput = '输入数据无效';
  static const String unknownError = '未知错误';
}
