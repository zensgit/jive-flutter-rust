import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/ledger.dart';

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
      
      return LedgerStatistics.fromJson(response.data);
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
      
      final List<dynamic> data = response.data['data'] ?? response.data;
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