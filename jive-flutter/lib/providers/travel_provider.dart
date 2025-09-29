import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/travel_event.dart';
import '../services/api_service.dart';

class TravelProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<TravelEvent> _travelEvents = [];
  TravelEvent? _currentTravel;
  bool _isLoading = false;
  String? _error;

  // 统计信息
  TravelStatistics? _statistics;
  List<TravelBudget> _budgets = [];

  TravelProvider(this._apiService);

  // Getters
  List<TravelEvent> get travelEvents => _travelEvents;
  TravelEvent? get currentTravel => _currentTravel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TravelStatistics? get statistics => _statistics;
  List<TravelBudget> get budgets => _budgets;

  // 获取活跃的旅行
  TravelEvent? get activeTravel {
    try {
      return _travelEvents.firstWhere((t) => t.status == 'active');
    } catch (_) {
      return null;
    }
  }

  // 加载旅行列表
  Future<void> loadTravelEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/api/v1/travel/events');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _travelEvents = data.map((json) => TravelEvent.fromJson(json)).toList();

        // 按开始日期排序
        _travelEvents.sort((a, b) => b.startDate.compareTo(a.startDate));
      }
    } catch (e) {
      _error = '加载旅行列表失败: ${e.toString()}';
      print('Error loading travel events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 获取单个旅行详情
  Future<void> loadTravelDetail(String travelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/api/v1/travel/events/$travelId');
      if (response.statusCode == 200) {
        _currentTravel = TravelEvent.fromJson(response.data);

        // 同时加载统计和预算信息
        await Future.wait([
          loadStatistics(travelId),
          loadBudgets(travelId),
        ]);
      }
    } catch (e) {
      _error = '加载旅行详情失败: ${e.toString()}';
      print('Error loading travel detail: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 创建新旅行
  Future<bool> createTravelEvent(CreateTravelEventInput input) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events',
        data: input.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newTravel = TravelEvent.fromJson(response.data);
        _travelEvents.insert(0, newTravel);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = '创建旅行失败: ${e.toString()}';
      print('Error creating travel: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 更新旅行信息
  Future<bool> updateTravelEvent(String travelId, UpdateTravelEventInput input) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.put(
        '/api/v1/travel/events/$travelId',
        data: input.toJson(),
      );

      if (response.statusCode == 200) {
        final updatedTravel = TravelEvent.fromJson(response.data);

        // 更新列表中的项
        final index = _travelEvents.indexWhere((t) => t.id == travelId);
        if (index != -1) {
          _travelEvents[index] = updatedTravel;
        }

        // 如果是当前旅行，也更新它
        if (_currentTravel?.id == travelId) {
          _currentTravel = updatedTravel;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = '更新旅行失败: ${e.toString()}';
      print('Error updating travel: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 删除旅行
  Future<bool> deleteTravelEvent(String travelId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.delete('/api/v1/travel/events/$travelId');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _travelEvents.removeWhere((t) => t.id == travelId);

        if (_currentTravel?.id == travelId) {
          _currentTravel = null;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = '删除旅行失败: ${e.toString()}';
      print('Error deleting travel: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 激活旅行
  Future<bool> activateTravel(String travelId) async {
    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events/$travelId/activate',
      );

      if (response.statusCode == 200) {
        await loadTravelDetail(travelId);
        return true;
      }
    } catch (e) {
      _error = '激活旅行失败: ${e.toString()}';
      print('Error activating travel: $e');
    }

    notifyListeners();
    return false;
  }

  // 完成旅行
  Future<bool> completeTravel(String travelId) async {
    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events/$travelId/complete',
      );

      if (response.statusCode == 200) {
        await loadTravelDetail(travelId);
        return true;
      }
    } catch (e) {
      _error = '完成旅行失败: ${e.toString()}';
      print('Error completing travel: $e');
    }

    notifyListeners();
    return false;
  }

  // 加载旅行统计
  Future<void> loadStatistics(String travelId) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/travel/events/$travelId/statistics',
      );

      if (response.statusCode == 200) {
        _statistics = TravelStatistics.fromJson(response.data);
      }
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  // 加载预算列表
  Future<void> loadBudgets(String travelId) async {
    try {
      final response = await _apiService.dio.get(
        '/api/v1/travel/events/$travelId/budgets',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _budgets = data.map((json) => TravelBudget.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading budgets: $e');
    }
  }

  // 设置分类预算
  Future<bool> setBudget(String travelId, String categoryId, double amount, String? currencyCode) async {
    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events/$travelId/budgets',
        data: {
          'category_id': categoryId,
          'budget_amount': amount,
          'budget_currency_code': currencyCode,
          'alert_threshold': 0.8, // 默认80%警戒线
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await loadBudgets(travelId);
        return true;
      }
    } catch (e) {
      _error = '设置预算失败: ${e.toString()}';
      print('Error setting budget: $e');
    }

    notifyListeners();
    return false;
  }

  // 关联交易到旅行
  Future<bool> attachTransactions(String travelId, List<String> transactionIds) async {
    try {
      final response = await _apiService.dio.post(
        '/api/v1/travel/events/$travelId/transactions',
        data: {
          'transaction_ids': transactionIds,
        },
      );

      if (response.statusCode == 200) {
        await loadTravelDetail(travelId);
        return true;
      }
    } catch (e) {
      _error = '关联交易失败: ${e.toString()}';
      print('Error attaching transactions: $e');
    }

    notifyListeners();
    return false;
  }

  // 取消关联交易
  Future<bool> detachTransactions(String travelId, List<String> transactionIds) async {
    try {
      final response = await _apiService.dio.delete(
        '/api/v1/travel/events/$travelId/transactions',
        data: {
          'transaction_ids': transactionIds,
        },
      );

      if (response.statusCode == 200) {
        await loadTravelDetail(travelId);
        return true;
      }
    } catch (e) {
      _error = '取消关联交易失败: ${e.toString()}';
      print('Error detaching transactions: $e');
    }

    notifyListeners();
    return false;
  }

  // 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 重置状态
  void reset() {
    _travelEvents = [];
    _currentTravel = null;
    _statistics = null;
    _budgets = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}