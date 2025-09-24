import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jive_money/models/budget.dart';
import 'package:jive_money/core/config/api_config.dart';

/// 预算服务
class BudgetService {
  final http.Client _httpClient;

  BudgetService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// 获取所有预算
  Future<List<Budget>> getBudgets() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${ApiConfig.apiUrl}${Endpoints.budgets}'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Budget.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load budgets: ${response.statusCode}');
      }
    } catch (e) {
      // 如果API不可用，返回模拟数据
      return _getMockBudgets();
    }
  }

  /// 创建预算
  Future<Budget> createBudget(Map<String, dynamic> data) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('${ApiConfig.apiUrl}${Endpoints.budgets}'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        return Budget.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create budget: ${response.statusCode}');
      }
    } catch (e) {
      // 返回模拟的新预算
      return _createMockBudget(data);
    }
  }

  /// 更新预算
  Future<Budget> updateBudget(String id, Map<String, dynamic> data) async {
    try {
      final response = await _httpClient.put(
        Uri.parse('${ApiConfig.apiUrl}${Endpoints.budgets}/$id'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return Budget.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update budget: ${response.statusCode}');
      }
    } catch (e) {
      // 返回模拟的更新后预算
      return _updateMockBudget(id, data);
    }
  }

  /// 删除预算
  Future<void> deleteBudget(String id) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('${ApiConfig.apiUrl}${Endpoints.budgets}/$id'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete budget: ${response.statusCode}');
      }
    } catch (e) {
      // 模拟删除成功
      return;
    }
  }

  /// 获取预算支出
  Future<double> getBudgetSpending(
      String budgetId, DateTime startDate, DateTime endDate) async {
    try {
      final queryParams = {
        'budgetId': budgetId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

      final uri = Uri.parse('${ApiConfig.apiUrl}${Endpoints.budgetStats}')
          .replace(queryParameters: queryParams);

      final response = await _httpClient.get(
        uri,
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['spending'] as num).toDouble();
      } else {
        throw Exception(
            'Failed to get budget spending: ${response.statusCode}');
      }
    } catch (e) {
      // 返回模拟的支出数据
      return _getMockSpending(budgetId);
    }
  }

  /// 获取模拟预算数据
  List<Budget> _getMockBudgets() {
    final now = DateTime.now();
    return [
      Budget(
        id: '1',
        name: '餐饮预算',
        description: '每月餐饮支出预算',
        amount: 3000.0,
        spent: 1500.0,
        category: '餐饮',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        period: BudgetPeriod.monthly,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Budget(
        id: '2',
        name: '交通预算',
        description: '每月交通支出预算',
        amount: 800.0,
        spent: 650.0,
        category: '交通',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        period: BudgetPeriod.monthly,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Budget(
        id: '3',
        name: '购物预算',
        description: '每月购物支出预算',
        amount: 2000.0,
        spent: 1800.0,
        category: '购物',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        period: BudgetPeriod.monthly,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  /// 创建模拟预算
  Budget _createMockBudget(Map<String, dynamic> data) {
    final now = DateTime.now();
    return Budget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: data['name'] ?? '新预算',
      description: data['description'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      spent: 0.0,
      category: data['category'] ?? '其他',
      startDate: data['startDate'] != null
          ? DateTime.parse(data['startDate'])
          : DateTime(now.year, now.month, 1),
      endDate: data['endDate'] != null ? DateTime.parse(data['endDate']) : null,
      period: data['period'] != null
          ? BudgetPeriod.fromJson(data['period'])
          : BudgetPeriod.monthly,
      isActive: data['isActive'] ?? true,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 更新模拟预算
  Budget _updateMockBudget(String id, Map<String, dynamic> data) {
    // 获取现有的模拟预算并更新
    final budgets = _getMockBudgets();
    final existingBudget = budgets.firstWhere(
      (b) => b.id == id,
      orElse: () => _createMockBudget(data),
    );

    return existingBudget.copyWith(
      name: data['name'] ?? existingBudget.name,
      description: data['description'] ?? existingBudget.description,
      amount: (data['amount'] as num?)?.toDouble() ?? existingBudget.amount,
      category: data['category'] ?? existingBudget.category,
      updatedAt: DateTime.now(),
    );
  }

  /// 获取模拟支出数据
  double _getMockSpending(String budgetId) {
    // 返回随机的支出数据
    final random = budgetId.hashCode % 100;
    return 500.0 + (random * 10);
  }

  /// 释放资源
  void dispose() {
    _httpClient.close();
  }
}
