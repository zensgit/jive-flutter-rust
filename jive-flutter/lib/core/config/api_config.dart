/// API配置文件
class ApiConfig {
  // API基础配置
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8012', // 开发环境默认值 - Jive API服务器端口
  );
  
  static const String apiVersion = 'v1';
  static const String apiPath = '/api/$apiVersion';
  
  // 完整的API URL
  static String get apiUrl => '$baseUrl$apiPath';
  
  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  // 请求头配置
  static Map<String, String> get defaultHeaders => {
    // 不在这里设置Content-Type，让Dio自动处理
    'Accept': 'application/json',
    'X-App-Version': '1.0.0',
    'X-Platform': 'flutter',
  };
  
  // 环境配置
  static bool get isDevelopment => const bool.fromEnvironment('dart.vm.product') == false;
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product') == true;
  
  // 日志配置
  static bool get enableLogging => isDevelopment;
  static bool get enableRequestLogging => isDevelopment;
  static bool get enableResponseLogging => isDevelopment;
  static bool get enableErrorLogging => true;
}

/// API端点
class Endpoints {
  const Endpoints._();
  
  // 认证相关
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/profile';
  
  // 账本相关
  static const String ledgers = '/ledgers';
  static const String currentLedger = '/ledgers/current';
  static const String ledgerStats = '/ledgers/:id/stats';
  static const String ledgerMembers = '/ledgers/:id/members';
  
  // 账户相关
  static const String accounts = '/accounts';
  static const String accountGroups = '/account-groups';
  static const String accountStats = '/accounts/:id/stats';
  
  // 交易相关
  static const String transactions = '/transactions';
  static const String transactionCategories = '/transactions/categories';
  static const String transactionStats = '/transactions/stats';
  static const String scheduledTransactions = '/scheduled-transactions';
  
  // 预算相关
  static const String budgets = '/budgets';
  static const String budgetTemplates = '/budgets/templates';
  static const String budgetStats = '/budgets/stats';
  
  // 报表相关
  static const String reports = '/reports';
  static const String cashFlow = '/reports/cash-flow';
  static const String incomeExpense = '/reports/income-expense';
  static const String netWorth = '/reports/net-worth';
  
  // 导入导出
  static const String importData = '/import';
  static const String exportData = '/export';
  
  // 设置相关
  static const String settings = '/settings';
  static const String currencies = '/currencies';
  static const String exchangeRates = '/exchange-rates';
}

/// API环境枚举
enum ApiEnvironment {
  development,
  staging,
  production,
}

/// API环境配置
class ApiEnvironmentConfig {
  final ApiEnvironment environment;
  final String baseUrl;
  final bool enableLogging;
  final bool enableCaching;
  
  const ApiEnvironmentConfig({
    required this.environment,
    required this.baseUrl,
    this.enableLogging = false,
    this.enableCaching = true,
  });
  
  static const development = ApiEnvironmentConfig(
    environment: ApiEnvironment.development,
    baseUrl: 'http://localhost:8012',
    enableLogging: true,
    enableCaching: false,
  );
  
  static const staging = ApiEnvironmentConfig(
    environment: ApiEnvironment.staging,
    baseUrl: 'https://staging-api.jivemoney.com',
    enableLogging: true,
    enableCaching: true,
  );
  
  static const production = ApiEnvironmentConfig(
    environment: ApiEnvironment.production,
    baseUrl: 'https://api.jivemoney.com',
    enableLogging: false,
    enableCaching: true,
  );
  
  static ApiEnvironmentConfig get current {
    if (ApiConfig.isDevelopment) {
      return development;
    } else {
      return production;
    }
  }
}