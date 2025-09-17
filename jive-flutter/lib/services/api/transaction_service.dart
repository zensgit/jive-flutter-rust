import 'package:dio/dio.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/transaction.dart';

/// 交易API服务
class TransactionService {
  final _client = HttpClient.instance;

  /// 获取交易列表
  Future<TransactionListResponse> getTransactions({
    String? ledgerId,
    String? accountId,
    String? category,
    TransactionType? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    String? sortBy = 'date',
    String? sortOrder = 'desc',
  }) async {
    try {
      final response = await _client.get(
        Endpoints.transactions,
        queryParameters: {
          if (ledgerId != null) 'ledger_id': ledgerId,
          if (accountId != null) 'account_id': accountId,
          if (category != null) 'category': category,
          if (type != null) 'type': type.value,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'page': page,
          'limit': limit,
          'sort_by': sortBy,
          'sort_order': sortOrder,
        },
      );

      return TransactionListResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取单个交易
  Future<Transaction> getTransaction(String id) async {
    try {
      final response = await _client.get(
        '${Endpoints.transactions}/$id',
      );

      return Transaction.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建交易
  Future<Transaction> createTransaction(Transaction transaction) async {
    try {
      final response = await _client.post(
        Endpoints.transactions,
        data: transaction.toJson(),
      );

      return Transaction.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新交易
  Future<Transaction> updateTransaction(
      String id, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        '${Endpoints.transactions}/$id',
        data: updates,
      );

      return Transaction.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除交易
  Future<void> deleteTransaction(String id) async {
    try {
      await _client.delete(
        '${Endpoints.transactions}/$id',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 批量创建交易
  Future<List<Transaction>> createBulkTransactions(
      List<Transaction> transactions) async {
    try {
      final response = await _client.post(
        '${Endpoints.transactions}/bulk',
        data: {
          'transactions': transactions.map((t) => t.toJson()).toList(),
        },
      );

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 批量删除交易
  Future<void> deleteBulkTransactions(List<String> ids) async {
    try {
      await _client.post(
        '${Endpoints.transactions}/bulk-delete',
        data: {
          'ids': ids,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取交易分类
  Future<List<TransactionCategory>> getCategories() async {
    try {
      final response = await _client.get(
        Endpoints.transactionCategories,
      );

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => TransactionCategory.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建交易分类
  Future<TransactionCategory> createCategory(
      TransactionCategory category) async {
    try {
      final response = await _client.post(
        Endpoints.transactionCategories,
        data: category.toJson(),
      );

      return TransactionCategory.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取交易统计
  Future<TransactionStatistics> getStatistics({
    String? ledgerId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    String period = 'month',
  }) async {
    try {
      final response = await _client.get(
        Endpoints.transactionStats,
        queryParameters: {
          if (ledgerId != null) 'ledger_id': ledgerId,
          if (accountId != null) 'account_id': accountId,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'period': period,
        },
      );

      return TransactionStatistics.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 搜索交易
  Future<List<Transaction>> searchTransactions({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _client.get(
        '${Endpoints.transactions}/search',
        queryParameters: {
          'q': query,
          'limit': limit,
        },
      );

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Transaction.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取定期交易
  Future<List<ScheduledTransaction>> getScheduledTransactions() async {
    try {
      final response = await _client.get(
        Endpoints.scheduledTransactions,
      );

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => ScheduledTransaction.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建定期交易
  Future<ScheduledTransaction> createScheduledTransaction(
    ScheduledTransaction scheduledTransaction,
  ) async {
    try {
      final response = await _client.post(
        Endpoints.scheduledTransactions,
        data: scheduledTransaction.toJson(),
      );

      return ScheduledTransaction.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 暂停/恢复定期交易
  Future<ScheduledTransaction> toggleScheduledTransaction(
      String id, bool pause) async {
    try {
      final response = await _client.post(
        '${Endpoints.scheduledTransactions}/$id/${pause ? "pause" : "resume"}',
      );

      return ScheduledTransaction.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除定期交易
  Future<void> deleteScheduledTransaction(String id) async {
    try {
      await _client.delete(
        '${Endpoints.scheduledTransactions}/$id',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 导出交易
  Future<String> exportTransactions({
    required String format, // csv, excel, pdf
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? category,
  }) async {
    try {
      final response = await _client.post(
        '${Endpoints.transactions}/export',
        data: {
          'format': format,
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          if (accountId != null) 'account_id': accountId,
          if (category != null) 'category': category,
        },
      );

      return response.data['download_url'] ?? response.data['url'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 导入交易
  Future<ImportResult> importTransactions({
    required String filePath,
    required String format, // csv, ofx, qif
    String? accountId,
  }) async {
    try {
      // TODO: 实现文件上传
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'format': format,
        if (accountId != null) 'account_id': accountId,
      });

      final response = await _client.upload(
        '${Endpoints.transactions}/import',
        formData: formData,
      );

      return ImportResult.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException('交易服务错误：${error.toString()}');
  }
}

/// 交易列表响应
class TransactionListResponse {
  final List<Transaction> data;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  TransactionListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    return TransactionListResponse(
      data: data.map((item) => Transaction.fromJson(item)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      hasMore: json['has_more'] ?? false,
    );
  }
}

/// 交易统计
class TransactionStatistics {
  final double totalIncome;
  final double totalExpense;
  final double netIncome;
  final int transactionCount;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> monthlyTrend;
  final Map<String, double> dailyAverage;

  TransactionStatistics({
    required this.totalIncome,
    required this.totalExpense,
    required this.netIncome,
    required this.transactionCount,
    required this.categoryBreakdown,
    required this.monthlyTrend,
    required this.dailyAverage,
  });

  factory TransactionStatistics.fromJson(Map<String, dynamic> json) {
    return TransactionStatistics(
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      netIncome: (json['net_income'] ?? 0).toDouble(),
      transactionCount: json['transaction_count'] ?? 0,
      categoryBreakdown:
          Map<String, double>.from(json['category_breakdown'] ?? {}),
      monthlyTrend: Map<String, double>.from(json['monthly_trend'] ?? {}),
      dailyAverage: Map<String, double>.from(json['daily_average'] ?? {}),
    );
  }
}

/// 导入结果
class ImportResult {
  final int imported;
  final int failed;
  final int duplicates;
  final List<String> errors;

  ImportResult({
    required this.imported,
    required this.failed,
    required this.duplicates,
    required this.errors,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      imported: json['imported'] ?? 0,
      failed: json['failed'] ?? 0,
      duplicates: json['duplicates'] ?? 0,
      errors: List<String>.from(json['errors'] ?? []),
    );
  }
}
