import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/account.dart';

/// 账户API服务
class AccountService {
  final _client = HttpClient.instance;
  
  /// 获取所有账户
  Future<List<Account>> getAllAccounts({
    String? ledgerId,
    bool includeArchived = false,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.accounts,
        queryParameters: {
          if (ledgerId != null) 'ledger_id': ledgerId,
          'include_archived': includeArchived,
        },
      );
      
      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Account.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 获取单个账户
  Future<Account> getAccount(String id) async {
    try {
      final response = await _client.get(
        '${Endpoints.accounts}/$id',
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 创建账户
  Future<Account> createAccount(Account account) async {
    try {
      final response = await _client.post(
        Endpoints.accounts,
        data: account.toJson(),
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 更新账户
  Future<Account> updateAccount(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        '${Endpoints.accounts}/$id',
        data: updates,
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 删除账户
  Future<void> deleteAccount(String id) async {
    try {
      await _client.delete(
        '${Endpoints.accounts}/$id',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 归档账户
  Future<Account> archiveAccount(String id) async {
    try {
      final response = await _client.post(
        '${Endpoints.accounts}/$id/archive',
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 恢复归档账户
  Future<Account> unarchiveAccount(String id) async {
    try {
      final response = await _client.post(
        '${Endpoints.accounts}/$id/unarchive',
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 设置默认账户
  Future<Account> setDefaultAccount(String id) async {
    try {
      final response = await _client.post(
        '${Endpoints.accounts}/$id/set-default',
      );
      
      return Account.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 获取账户统计信息
  Future<AccountStatistics> getAccountStatistics(String id) async {
    try {
      final response = await _client.get(
        Endpoints.accountStats.replaceAll(':id', id),
      );
      
      return AccountStatistics.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 获取账户交易历史
  Future<List<dynamic>> getAccountTransactions(
    String id, {
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _client.get(
        '${Endpoints.accounts}/$id/transactions',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
        },
      );
      
      return response.data['data'] ?? response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 获取账户余额历史
  Future<List<BalanceHistory>> getBalanceHistory(
    String id, {
    String period = 'month', // day, week, month, year
    int count = 30,
  }) async {
    try {
      final response = await _client.get(
        '${Endpoints.accounts}/$id/balance-history',
        queryParameters: {
          'period': period,
          'count': count,
        },
      );
      
      final List<dynamic> data = response.data;
      return data.map((json) => BalanceHistory.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 批量更新账户排序
  Future<void> updateAccountsOrder(List<String> accountIds) async {
    try {
      await _client.post(
        '${Endpoints.accounts}/reorder',
        data: {
          'account_ids': accountIds,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException('账户服务错误：${error.toString()}');
  }
}

/// 账户统计信息
class AccountStatistics {
  final String accountId;
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final int transactionCount;
  final DateTime? lastTransactionDate;
  final Map<String, double>? monthlyTrend;
  final Map<String, double>? categoryBreakdown;
  
  AccountStatistics({
    required this.accountId,
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.transactionCount,
    this.lastTransactionDate,
    this.monthlyTrend,
    this.categoryBreakdown,
  });
  
  factory AccountStatistics.fromJson(Map<String, dynamic> json) {
    return AccountStatistics(
      accountId: json['account_id'],
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
      monthlyTrend: json['monthly_trend'] != null
          ? Map<String, double>.from(json['monthly_trend'])
          : null,
      categoryBreakdown: json['category_breakdown'] != null
          ? Map<String, double>.from(json['category_breakdown'])
          : null,
    );
  }
}

/// 余额历史
class BalanceHistory {
  final DateTime date;
  final double balance;
  final double change;
  final double changePercent;
  
  BalanceHistory({
    required this.date,
    required this.balance,
    required this.change,
    required this.changePercent,
  });
  
  factory BalanceHistory.fromJson(Map<String, dynamic> json) {
    return BalanceHistory(
      date: DateTime.parse(json['date']),
      balance: (json['balance'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      changePercent: (json['change_percent'] ?? 0).toDouble(),
    );
  }
}