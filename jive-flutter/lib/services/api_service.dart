import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/core/network/api_readiness.dart';
import 'package:jive_money/core/storage/token_storage.dart';
import 'package:jive_money/models/payee.dart';
import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/models/rule.dart';

class ApiService {
  // 统一通过 ApiConfig, 在 HttpClient 中已经设置 baseUrl

  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 通用请求头
  Future<Map<String, String>> headers() async {
    final token = await TokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Dio get _dio => HttpClient.instance.dio;

  Future<T> _run<T>(Future<T> Function() op) async {
    int attempt = 0;
    while (true) {
      try {
        return await op();
      } catch (e) {
        if (e is DioException &&
            (e.type == DioExceptionType.connectionError ||
                e.error is SocketException)) {
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
            attempt++;
            continue;
          }
        }
        rethrow;
      }
    }
  }

  // ==================== Generic HTTP Methods ====================

  /// Generic GET request
  Future<dynamic> get(String endpoint) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp =
        await _run(() => _dio.get(endpoint, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      return resp.data;
    } else {
      throw Exception('GET failed: ${resp.statusCode}');
    }
      return resp;
  }

  /// Generic POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(
        () => _dio.post(endpoint, data: body, options: Options(headers: hdr)));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return resp.data;
    } else {
      throw Exception('POST failed: ${resp.statusCode}');
    }
      return resp;
  }

  /// Generic PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(
        () => _dio.put(endpoint, data: body, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      return resp.data;
    } else {
      throw Exception('PUT failed: ${resp.statusCode}');
    }
      return resp;
  }

  /// Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp =
        await _run(() => _dio.delete(endpoint, options: Options(headers: hdr)));
    if (resp.statusCode == 200 || resp.statusCode == 204) {
      return resp.data;
    } else {
      throw Exception('DELETE failed: ${resp.statusCode}');
    }
      return resp;
  }

  // ==================== Payee管理 ====================

  /// 获取收款人列表
  Future<List<Payee>> getPayees({
    String? ledgerId,
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    final queryParams = {
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (search != null) 'search': search,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/payees',
        queryParameters: queryParams, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.map((j) => Payee.fromJson(j)).toList();
    }
    throw Exception('Failed to load payees');
  }

  /// 创建收款人
  Future<Payee> createPayee(Payee payee) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/payees',
        data: payee.toJson(), options: Options(headers: hdr)));
    if ((resp.statusCode == 200 || resp.statusCode == 201)) {
      return Payee.fromJson(
          resp.data is Map ? resp.data : json.decode(resp.data));
    }
    throw Exception('Failed to create payee');
  }

  /// 更新收款人
  Future<Payee> updatePayee(String id, Map<String, dynamic> updates) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() =>
        _dio.put('/payees/$id', data: updates, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      return Payee.fromJson(
          resp.data is Map ? resp.data : json.decode(resp.data));
    }
    throw Exception('Failed to update payee');
  }

  /// 删除收款人
  Future<void> deletePayee(String id) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(
        () => _dio.delete('/payees/$id', options: Options(headers: hdr)));
    if ((resp.statusCode == 200 || resp.statusCode == 204)) {
      return;
    }
    throw Exception('Failed to delete payee');
  }

  /// 获取收款人建议
  Future<List<PayeeSuggestion>> getPayeeSuggestions(
      String text, String ledgerId) async {
    final queryParams = {
      'text': text,
      'ledger_id': ledgerId,
    };

    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/payees/suggestions',
        queryParameters: queryParams, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.map((j) => PayeeSuggestion.fromJson(j)).toList();
    }
    throw Exception('Failed to get suggestions');
  }

  /// 合并收款人
  Future<Payee> mergePayees(String targetId, List<String> sourceIds) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/payees/merge',
        data: {
          'target_id': targetId,
          'source_ids': sourceIds,
        },
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      return Payee.fromJson(
          resp.data is Map ? resp.data : json.decode(resp.data));
    }
    throw Exception('Failed to merge payees');
  }

  // ==================== 交易管理 ====================

  /// 获取交易列表
  Future<List<Transaction>> getTransactions({
    String? ledgerId,
    String? accountId,
    String? categoryId,
    String? payeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    final queryParams = {
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (payeeId != null) 'payee_id': payeeId,
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
      if (search != null) 'search': search,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/transactions',
        queryParameters: queryParams, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.map((j) => Transaction.fromJson(j)).toList();
    }
    throw Exception('Failed to load transactions');
  }

  /// 创建交易
  Future<Transaction> createTransaction(Transaction transaction) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/transactions',
        data: transaction.toJson(), options: Options(headers: hdr)));
    if ((resp.statusCode == 200 || resp.statusCode == 201)) {
      return Transaction.fromJson(
          resp.data is Map ? resp.data : json.decode(resp.data));
    }
    throw Exception('Failed to create transaction');
  }

  /// 批量操作交易
  Future<Map<String, dynamic>> bulkTransactionOperation({
    required List<String> transactionIds,
    required String operation,
    String? categoryId,
    String? status,
  }) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/transactions/bulk',
        data: {
          'transaction_ids': transactionIds,
          'operation': operation,
          'category_id': categoryId,
          'status': status,
        },
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) return resp.data;
    throw Exception('Failed to perform bulk operation');
  }

  // ==================== 规则引擎 ====================

  /// 获取规则列表
  Future<List<Rule>> getRules({
    String? ledgerId,
    bool? isActive,
    String? ruleType,
    int page = 1,
    int perPage = 50,
  }) async {
    final queryParams = {
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (isActive != null) 'is_active': isActive.toString(),
      if (ruleType != null) 'rule_type': ruleType,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/rules',
        queryParameters: queryParams, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.map((j) => Rule.fromJson(j)).toList();
    }
    throw Exception('Failed to load rules');
  }

  /// 创建规则
  Future<Rule> createRule(Rule rule) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/rules',
        data: rule.toJson(), options: Options(headers: hdr)));
    if ((resp.statusCode == 200 || resp.statusCode == 201)) {
      return Rule.fromJson(
          resp.data is Map ? resp.data : json.decode(resp.data));
    }
    throw Exception('Failed to create rule');
  }

  /// 执行规则
  Future<List<RuleExecutionResult>> executeRules({
    List<String>? transactionIds,
    List<String>? ruleIds,
    bool dryRun = false,
  }) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.post('/rules/execute',
        data: {
          'transaction_ids': transactionIds,
          'rule_ids': ruleIds,
          'dry_run': dryRun,
        },
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.map((j) => RuleExecutionResult.fromJson(j)).toList();
    }
    throw Exception('Failed to execute rules');
  }

  /// 删除规则
  Future<void> deleteRule(String id) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(
        () => _dio.delete('/rules/$id', options: Options(headers: hdr)));
    if ((resp.statusCode == 200 || resp.statusCode == 204)) {
      return;
    }
    throw Exception('Failed to delete rule');
  }

  // ==================== 账户管理 ====================

  /// 获取账户列表
  Future<List<Map<String, dynamic>>> getAccounts({
    String? ledgerId,
    int page = 1,
    int perPage = 50,
  }) async {
    final queryParams = {
      if (ledgerId != null) 'ledger_id': ledgerId,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/accounts',
        queryParameters: queryParams, options: Options(headers: hdr)));
    if (resp.statusCode == 200) {
      final List data =
          resp.data is List ? resp.data : (resp.data['data'] ?? []);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load accounts');
  }

  /// 获取账户统计
  Future<Map<String, dynamic>> getAccountStatistics(String ledgerId) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/accounts/statistics',
        queryParameters: {'ledger_id': ledgerId},
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) return resp.data;
    throw Exception('Failed to get account statistics');
  }

  /// 获取交易统计
  Future<Map<String, dynamic>> getTransactionStatistics(String ledgerId) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/transactions/statistics',
        queryParameters: {'ledger_id': ledgerId},
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) return resp.data;
    throw Exception('Failed to get transaction statistics');
  }

  /// 获取收款人统计
  Future<Map<String, dynamic>> getPayeeStatistics(String ledgerId) async {
    await ApiReadiness.ensureReady(_dio);
    final hdr = await headers();
    final resp = await _run(() => _dio.get('/payees/statistics',
        queryParameters: {'ledger_id': ledgerId},
        options: Options(headers: hdr)));
    if (resp.statusCode == 200) return resp.data;
    throw Exception('Failed to get payee statistics');
  }
}

// 模型类定义
class PayeeSuggestion {
  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final int usageCount;
  final double confidenceScore;

  PayeeSuggestion({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.usageCount,
    required this.confidenceScore,
  });

  factory PayeeSuggestion.fromJson(Map<String, dynamic> json) {
    return PayeeSuggestion(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      usageCount: json['usage_count'],
      confidenceScore: json['confidence_score'].toDouble(),
    );
  }
}

class RuleExecutionResult {
  final String ruleId;
  final String ruleName;
  final List<String> matchedTransactions;
  final int appliedCount;
  final int failedCount;
  final List<String> errors;

  RuleExecutionResult({
    required this.ruleId,
    required this.ruleName,
    required this.matchedTransactions,
    required this.appliedCount,
    required this.failedCount,
    required this.errors,
  });

  factory RuleExecutionResult.fromJson(Map<String, dynamic> json) {
    return RuleExecutionResult(
      ruleId: json['rule_id'],
      ruleName: json['rule_name'],
      matchedTransactions: List<String>.from(json['matched_transactions']),
      appliedCount: json['applied_count'],
      failedCount: json['failed_count'],
      errors: List<String>.from(json['errors']),
    );
  }
}
