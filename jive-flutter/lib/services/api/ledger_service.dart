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

/// 账本统计信息
class LedgerStatistics {
  final String ledgerId;
  final int accountCount;
  final int transactionCount;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final Map<String, double> accountTypeBreakdown;
  final Map<String, double> monthlyTrend;
  final DateTime? lastTransactionDate;
  
  LedgerStatistics({
    required this.ledgerId,
    required this.accountCount,
    required this.transactionCount,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.accountTypeBreakdown,
    required this.monthlyTrend,
    this.lastTransactionDate,
  });
  
  factory LedgerStatistics.fromJson(Map<String, dynamic> json) {
    return LedgerStatistics(
      ledgerId: json['ledger_id'],
      accountCount: json['account_count'] ?? 0,
      transactionCount: json['transaction_count'] ?? 0,
      totalAssets: (json['total_assets'] ?? 0).toDouble(),
      totalLiabilities: (json['total_liabilities'] ?? 0).toDouble(),
      netWorth: (json['net_worth'] ?? 0).toDouble(),
      accountTypeBreakdown: Map<String, double>.from(json['account_type_breakdown'] ?? {}),
      monthlyTrend: Map<String, double>.from(json['monthly_trend'] ?? {}),
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'])
          : null,
    );
  }
}

/// 账本成员
class LedgerMember {
  final String userId;
  final String name;
  final String email;
  final String? avatar;
  final LedgerRole role;
  final Map<String, bool> permissions;
  final DateTime joinedAt;
  final DateTime? lastAccessedAt;
  
  LedgerMember({
    required this.userId,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
    required this.permissions,
    required this.joinedAt,
    this.lastAccessedAt,
  });
  
  factory LedgerMember.fromJson(Map<String, dynamic> json) {
    return LedgerMember(
      userId: json['user_id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      role: LedgerRole.fromString(json['role']),
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
      joinedAt: DateTime.parse(json['joined_at']),
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
    );
  }
}

/// 账本角色
enum LedgerRole {
  owner('owner', '所有者'),
  admin('admin', '管理员'),
  editor('editor', '编辑者'),
  viewer('viewer', '查看者');
  
  final String value;
  final String label;
  
  const LedgerRole(this.value, this.label);
  
  static LedgerRole fromString(String? value) {
    return LedgerRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => LedgerRole.viewer,
    );
  }
}