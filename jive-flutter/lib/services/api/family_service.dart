import 'package:dio/dio.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/family.dart';
import '../../models/user.dart';

/// Family服务 - 管理多Family功能
class FamilyService {
  final _client = HttpClient.instance;

  /// 获取用户的所有Family列表及角色
  Future<List<UserFamilyInfo>> getUserFamilies() async {
    try {
      final response = await _client.get('/families/my-families');

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => UserFamilyInfo.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取当前Family
  Future<Family?> getCurrentFamily() async {
    try {
      final response = await _client.get('/families/current');

      if (response.data == null) {
        return null;
      }

      return Family.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      // 如果没有当前Family，返回null
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e);
    }
  }

  /// 切换当前Family
  Future<void> switchFamily(String familyId) async {
    try {
      await _client.post(
        '/families/switch',
        data: {
          'family_id': familyId,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 创建新Family
  Future<UserFamilyInfo> createFamily(CreateFamilyRequest request) async {
    try {
      final response = await _client.post(
        '/families',
        data: request.toJson(),
      );

      return UserFamilyInfo.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新Family信息
  Future<Family> updateFamily(
      String familyId, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        '/families/$familyId',
        data: updates,
      );

      return Family.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取Family成员列表
  Future<List<FamilyMemberWithUser>> getFamilyMembers(String familyId) async {
    try {
      final response = await _client.get('/families/$familyId/members');

      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => FamilyMemberWithUser.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 邀请成员加入Family
  Future<FamilyInvitation> inviteMember({
    required String familyId,
    required String email,
    required FamilyRole role,
  }) async {
    try {
      final response = await _client.post(
        '/families/$familyId/invite',
        data: {
          'email': email,
          'role': role.value,
        },
      );

      return FamilyInvitation.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 接受Family邀请
  Future<UserFamilyInfo> acceptInvitation(String token) async {
    try {
      final response = await _client.post(
        '/families/invitations/accept',
        data: {
          'token': token,
        },
      );

      return UserFamilyInfo.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 更新成员角色
  Future<void> updateMemberRole({
    required String familyId,
    required String userId,
    required FamilyRole newRole,
  }) async {
    try {
      await _client.put(
        '/families/$familyId/members/$userId',
        data: {
          'role': newRole.value,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 移除Family成员
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {
    try {
      await _client.delete('/families/$familyId/members/$userId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 离开Family
  Future<void> leaveFamily(String familyId) async {
    try {
      await _client.post('/families/$familyId/leave');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除Family（仅Owner可以）
  Future<void> deleteFamily(String familyId) async {
    try {
      await _client.delete('/families/$familyId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取Family统计信息
  Future<FamilyStatistics> getFamilyStatistics(String familyId) async {
    try {
      final response = await _client.get('/families/$familyId/statistics');

      return FamilyStatistics.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException) {
      if (error.response?.data != null &&
          error.response?.data['message'] != null) {
        return ApiException(error.response!.data['message']);
      }
      return ApiException('网络错误：${error.message}');
    }
    return ApiException('Family服务错误：${error.toString()}');
  }
}

/// Family成员信息（包含用户详情）
class FamilyMemberWithUser {
  final FamilyMember member;
  final User user;

  FamilyMemberWithUser({
    required this.member,
    required this.user,
  });

  factory FamilyMemberWithUser.fromJson(Map<String, dynamic> json) {
    return FamilyMemberWithUser(
      member: FamilyMember.fromJson(json['member'] ?? json),
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member': member.toJson(),
      'user': user.toJson(),
    };
  }
}

/// Family统计信息
class FamilyStatistics {
  final int memberCount;
  final int ledgerCount;
  final int accountCount;
  final int transactionCount;
  final Map<String, double> totalBalance;
  final DateTime lastActivity;

  FamilyStatistics({
    required this.memberCount,
    required this.ledgerCount,
    required this.accountCount,
    required this.transactionCount,
    required this.totalBalance,
    required this.lastActivity,
  });

  factory FamilyStatistics.fromJson(Map<String, dynamic> json) {
    return FamilyStatistics(
      memberCount: json['member_count'] ?? 0,
      ledgerCount: json['ledger_count'] ?? 0,
      accountCount: json['account_count'] ?? 0,
      transactionCount: json['transaction_count'] ?? 0,
      totalBalance: Map<String, double>.from(json['total_balance'] ?? {}),
      lastActivity: DateTime.parse(json['last_activity']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_count': memberCount,
      'ledger_count': ledgerCount,
      'account_count': accountCount,
      'transaction_count': transactionCount,
      'total_balance': totalBalance,
      'last_activity': lastActivity.toIso8601String(),
    };
  }
}

/// API异常
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

/// 未授权异常
class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, statusCode: 401);
}
