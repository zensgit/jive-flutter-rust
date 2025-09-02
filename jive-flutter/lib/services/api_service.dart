import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payee.dart';
import '../models/transaction.dart';
import '../models/rule.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8012/api/v1';
  
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 通用请求头
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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
    
    final uri = Uri.parse('$baseUrl/payees').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Payee.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load payees: ${response.body}');
    }
  }

  /// 创建收款人
  Future<Payee> createPayee(Payee payee) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payees'),
      headers: headers,
      body: json.encode(payee.toJson()),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Payee.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create payee: ${response.body}');
    }
  }

  /// 更新收款人
  Future<Payee> updatePayee(String id, Map<String, dynamic> updates) async {
    final response = await http.put(
      Uri.parse('$baseUrl/payees/$id'),
      headers: headers,
      body: json.encode(updates),
    );
    
    if (response.statusCode == 200) {
      return Payee.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update payee: ${response.body}');
    }
  }

  /// 删除收款人
  Future<void> deletePayee(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/payees/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete payee: ${response.body}');
    }
  }

  /// 获取收款人建议
  Future<List<PayeeSuggestion>> getPayeeSuggestions(String text, String ledgerId) async {
    final queryParams = {
      'text': text,
      'ledger_id': ledgerId,
    };
    
    final uri = Uri.parse('$baseUrl/payees/suggestions').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => PayeeSuggestion.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get suggestions: ${response.body}');
    }
  }

  /// 合并收款人
  Future<Payee> mergePayees(String targetId, List<String> sourceIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payees/merge'),
      headers: headers,
      body: json.encode({
        'target_id': targetId,
        'source_ids': sourceIds,
      }),
    );
    
    if (response.statusCode == 200) {
      return Payee.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to merge payees: ${response.body}');
    }
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
      if (startDate != null) 'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
      if (search != null) 'search': search,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    
    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Transaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load transactions: ${response.body}');
    }
  }

  /// 创建交易
  Future<Transaction> createTransaction(Transaction transaction) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: headers,
      body: json.encode(transaction.toJson()),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Transaction.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create transaction: ${response.body}');
    }
  }

  /// 批量操作交易
  Future<Map<String, dynamic>> bulkTransactionOperation({
    required List<String> transactionIds,
    required String operation,
    String? categoryId,
    String? status,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/bulk'),
      headers: headers,
      body: json.encode({
        'transaction_ids': transactionIds,
        'operation': operation,
        'category_id': categoryId,
        'status': status,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to perform bulk operation: ${response.body}');
    }
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
    
    final uri = Uri.parse('$baseUrl/rules').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Rule.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load rules: ${response.body}');
    }
  }

  /// 创建规则
  Future<Rule> createRule(Rule rule) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rules'),
      headers: headers,
      body: json.encode(rule.toJson()),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Rule.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create rule: ${response.body}');
    }
  }

  /// 执行规则
  Future<List<RuleExecutionResult>> executeRules({
    List<String>? transactionIds,
    List<String>? ruleIds,
    bool dryRun = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rules/execute'),
      headers: headers,
      body: json.encode({
        'transaction_ids': transactionIds,
        'rule_ids': ruleIds,
        'dry_run': dryRun,
      }),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => RuleExecutionResult.fromJson(json)).toList();
    } else {
      throw Exception('Failed to execute rules: ${response.body}');
    }
  }

  /// 删除规则
  Future<void> deleteRule(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/rules/$id'),
      headers: headers,
    );
    
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete rule: ${response.body}');
    }
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
    
    final uri = Uri.parse('$baseUrl/accounts').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load accounts: ${response.body}');
    }
  }

  /// 获取账户统计
  Future<Map<String, dynamic>> getAccountStatistics(String ledgerId) async {
    final uri = Uri.parse('$baseUrl/accounts/statistics').replace(
      queryParameters: {'ledger_id': ledgerId},
    );
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get account statistics: ${response.body}');
    }
  }

  /// 获取交易统计
  Future<Map<String, dynamic>> getTransactionStatistics(String ledgerId) async {
    final uri = Uri.parse('$baseUrl/transactions/statistics').replace(
      queryParameters: {'ledger_id': ledgerId},
    );
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get transaction statistics: ${response.body}');
    }
  }

  /// 获取收款人统计
  Future<Map<String, dynamic>> getPayeeStatistics(String ledgerId) async {
    final uri = Uri.parse('$baseUrl/payees/statistics').replace(
      queryParameters: {'ledger_id': ledgerId},
    );
    final response = await http.get(uri, headers: headers);
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get payee statistics: ${response.body}');
    }
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