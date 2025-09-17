/// 邀请系统模型
/// 用于管理Family成员邀请流程

import 'package:flutter/foundation.dart';
import 'family.dart';
import 'user.dart';

/// 邀请状态枚举
enum InvitationStatus {
  pending('pending', '待处理'),
  accepted('accepted', '已接受'),
  declined('declined', '已拒绝'),
  expired('expired', '已过期'),
  cancelled('cancelled', '已取消');

  final String value;
  final String label;

  const InvitationStatus(this.value, this.label);

  static InvitationStatus fromString(String? value) {
    return InvitationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvitationStatus.pending,
    );
  }
}

/// 邀请实体
class Invitation {
  final String id;
  final String familyId;
  final String email;
  final String token;
  final FamilyRole role;
  final String invitedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final InvitationStatus status;

  Invitation({
    required this.id,
    required this.familyId,
    required this.email,
    required this.token,
    required this.role,
    required this.invitedBy,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.acceptedBy,
    this.status = InvitationStatus.pending,
  });

  /// 从JSON创建
  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'],
      familyId: json['family_id'],
      email: json['email'],
      token: json['token'],
      role: FamilyRole.fromString(json['role']),
      invitedBy: json['invited_by'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      acceptedBy: json['accepted_by'],
      status: InvitationStatus.fromString(json['status']),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'email': email,
      'token': token,
      'role': role.value,
      'invited_by': invitedBy,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'accepted_by': acceptedBy,
      'status': status.value,
    };
  }

  /// 检查是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 检查是否可以接受
  bool get canAccept => status == InvitationStatus.pending && !isExpired;

  /// 获取剩余时间（小时）
  int get hoursRemaining {
    if (isExpired) return 0;
    return expiresAt.difference(DateTime.now()).inHours;
  }

  /// 获取剩余时间描述
  String get remainingTimeDescription {
    if (isExpired) return '已过期';

    final diff = expiresAt.difference(DateTime.now());
    if (diff.inDays > 0) {
      return '${diff.inDays}天后过期';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时后过期';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟后过期';
    } else {
      return '即将过期';
    }
  }

  /// 复制并更新
  Invitation copyWith({
    String? id,
    String? familyId,
    String? email,
    String? token,
    FamilyRole? role,
    String? invitedBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    InvitationStatus? status,
  }) {
    return Invitation(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      email: email ?? this.email,
      token: token ?? this.token,
      role: role ?? this.role,
      invitedBy: invitedBy ?? this.invitedBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      status: status ?? this.status,
    );
  }
}

/// 邀请详情（包含关联信息）
class InvitationWithDetails {
  final Invitation invitation;
  final Family family;
  final User inviter;

  InvitationWithDetails({
    required this.invitation,
    required this.family,
    required this.inviter,
  });

  /// 从JSON创建
  factory InvitationWithDetails.fromJson(Map<String, dynamic> json) {
    return InvitationWithDetails(
      invitation: Invitation.fromJson(json['invitation'] ?? json),
      family: Family.fromJson(json['family']),
      inviter: User.fromJson(json['inviter']),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'invitation': invitation.toJson(),
      'family': family.toJson(),
      'inviter': inviter.toJson(),
    };
  }
}

/// 邀请统计
class InvitationStatistics {
  final int totalSent;
  final int pendingCount;
  final int acceptedCount;
  final int declinedCount;
  final int expiredCount;
  final DateTime? lastSentAt;
  final DateTime? lastAcceptedAt;

  InvitationStatistics({
    required this.totalSent,
    required this.pendingCount,
    required this.acceptedCount,
    required this.declinedCount,
    required this.expiredCount,
    this.lastSentAt,
    this.lastAcceptedAt,
  });

  /// 从JSON创建
  factory InvitationStatistics.fromJson(Map<String, dynamic> json) {
    return InvitationStatistics(
      totalSent: json['total_sent'] ?? 0,
      pendingCount: json['pending_count'] ?? 0,
      acceptedCount: json['accepted_count'] ?? 0,
      declinedCount: json['declined_count'] ?? 0,
      expiredCount: json['expired_count'] ?? 0,
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.parse(json['last_sent_at'])
          : null,
      lastAcceptedAt: json['last_accepted_at'] != null
          ? DateTime.parse(json['last_accepted_at'])
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'total_sent': totalSent,
      'pending_count': pendingCount,
      'accepted_count': acceptedCount,
      'declined_count': declinedCount,
      'expired_count': expiredCount,
      'last_sent_at': lastSentAt?.toIso8601String(),
      'last_accepted_at': lastAcceptedAt?.toIso8601String(),
    };
  }

  /// 接受率
  double get acceptanceRate {
    if (totalSent == 0) return 0;
    return (acceptedCount / totalSent) * 100;
  }

  /// 活跃邀请数
  int get activeInvitations => pendingCount;
}

/// 批量邀请请求
class BatchInvitationRequest {
  final String familyId;
  final List<String> emails;
  final FamilyRole defaultRole;
  final String? message;
  final DateTime? customExpiresAt;

  BatchInvitationRequest({
    required this.familyId,
    required this.emails,
    required this.defaultRole,
    this.message,
    this.customExpiresAt,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'family_id': familyId,
      'emails': emails,
      'default_role': defaultRole.value,
      'message': message,
      'custom_expires_at': customExpiresAt?.toIso8601String(),
    };
  }
}

/// 邀请验证结果
class InvitationValidation {
  final bool isValid;
  final String? errorMessage;
  final InvitationWithDetails? details;

  InvitationValidation({
    required this.isValid,
    this.errorMessage,
    this.details,
  });

  /// 从JSON创建
  factory InvitationValidation.fromJson(Map<String, dynamic> json) {
    return InvitationValidation(
      isValid: json['is_valid'] ?? false,
      errorMessage: json['error_message'],
      details: json['details'] != null
          ? InvitationWithDetails.fromJson(json['details'])
          : null,
    );
  }
}
