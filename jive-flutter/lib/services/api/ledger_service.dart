import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/core/config/api_config.dart';
import 'package:jive_money/models/ledger.dart';

/// 账本API服务
class LedgerService {
  final _client = HttpClient.instance;

  /// 获取所有账本
  Future<List<Ledger>> getAllLedgers() async {
    try {
      final response = await _client.get(
        Endpoints.ledgers,
      );

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Ledger.fromJson(json)).toList();
    } catch (e) {
      // 如果是认证错误或Missing credentials，返回空列表（新用户可能还没有ledgers）
      if (e is BadRequestException && e.message.contains('Missing credentials')) {
        return [];
      }
      if (e is UnauthorizedException) {
        return [];
      }
      throw _handleError(e);
    }
  }

  /// 获取单个账本
  Future<Ledger> getLedger(String id) async {
    try {
      final response = await _client.get(
        '${Endpoints.ledgers}/$id',
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建账本
  Future<Ledger> createLedger(Ledger ledger) async {
    try {
      final response = await _client.post(
        Endpoints.ledgers,
        data: ledger.toJson(),
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新账本
  Future<Ledger> updateLedger(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        '${Endpoints.ledgers}/$id',
        data: updates,
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除账本
  Future<void> deleteLedger(String id) async {
    try {
      await _client.delete(
        '${Endpoints.ledgers}/$id',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 设置默认账本
  Future<Ledger> setDefaultLedger(String id) async {
    try {
      final response = await _client.post(
        '${Endpoints.ledgers}/$id/set-default',
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 分享账本
  Future<Ledger> shareLedger(String id, List<String> userEmails) async {
    try {
      final response = await _client.post(
        '${Endpoints.ledgers}/$id/share',
        data: {
          'user_emails': userEmails,
        },
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 取消分享账本
  Future<Ledger> unshareLedger(String id, String userEmail) async {
    try {
      final response = await _client.post(
        '${Endpoints.ledgers}/$id/unshare',
        data: {
          'user_email': userEmail,
        },
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取账本统计
  Future<LedgerStatistics> getLedgerStatistics(String id) async {
    try {
      final response = await _client.get(
        '${Endpoints.ledgers}/$id/statistics',
      );

      // 处理不同的响应格式
      dynamic responseData = response.data;
      Map<String, dynamic> statisticsData;

      if (responseData is Map) {
        // 如果响应本身就是统计数据
        if (responseData.containsKey('totalAccounts') ||
            responseData.containsKey('totalTransactions') ||
            responseData.containsKey('totalBudgets')) {
          statisticsData = responseData as Map<String, dynamic>;
        } else if (responseData.containsKey('data')) {
          // 如果响应包含 'data' 字段
          statisticsData = responseData['data'] as Map<String, dynamic>;
        } else if (responseData.containsKey('statistics')) {
          // 如果响应包含 'statistics' 字段
          statisticsData = responseData['statistics'] as Map<String, dynamic>;
        } else {
          // 使用整个响应作为统计数据
          statisticsData = responseData as Map<String, dynamic>;
        }
      } else {
        // 如果响应格式不正确，返回默认值
        statisticsData = {
          'totalAccounts': 0,
          'totalTransactions': 0,
          'totalBudgets': 0,
          'monthlyExpense': 0.0,
          'monthlyIncome': 0.0,
          'balance': 0.0,
        };
      }

      return LedgerStatistics.fromJson(statisticsData);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取账本成员
  Future<List<LedgerMember>> getLedgerMembers(String id) async {
    try {
      final response = await _client.get(
        '${Endpoints.ledgers}/$id/members',
      );

      // 处理不同的响应格式
      dynamic responseData = response.data;
      List<dynamic> data;

      if (responseData is List) {
        data = responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        // 如果响应是包含 'data' 字段的对象
        final dataField = responseData['data'];
        if (dataField is List) {
          data = dataField;
        } else if (dataField is Map && dataField.containsKey('members')) {
          // 如果 data 是对象且包含 'members' 字段
          data = dataField['members'] ?? [];
        } else {
          data = [];
        }
      } else if (responseData is Map && responseData.containsKey('members')) {
        // 如果响应直接包含 'members' 字段
        data = responseData['members'] ?? [];
      } else {
        data = [];
      }

      return data.map((json) => LedgerMember.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新成员权限
  Future<LedgerMember> updateMemberPermissions(
    String ledgerId,
    String userId,
    Map<String, bool> permissions,
  ) async {
    try {
      final response = await _client.put(
        '${Endpoints.ledgers}/$ledgerId/members/$userId',
        data: {
          'permissions': permissions,
        },
      );

      return LedgerMember.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取当前账本
  Future<Ledger> getCurrentLedger() async {
    try {
      final response = await _client.get(
        '${Endpoints.ledgers}/current',
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 设置当前账本
  Future<void> setCurrentLedger(String ledgerId) async {
    try {
      await _client.post(
        '${Endpoints.ledgers}/$ledgerId/set-current',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新账本 (接受Ledger对象)
  Future<Ledger> updateLedgerFromObject(Ledger ledger) async {
    try {
      final response = await _client.put(
        '${Endpoints.ledgers}/${ledger.id}',
        data: ledger.toJson(),
      );

      return Ledger.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException('账本服务错误：${error.toString()}');
  }
}
