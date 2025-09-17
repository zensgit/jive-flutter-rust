/// Family（家庭/组织）模型
/// 支持多Family架构，一个用户可以属于多个Family

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Family实体
class Family {
  final String id;
  final String name;
  final String currency;
  final String timezone;
  final String locale;
  final int fiscalYearStart;
  final Map<String, dynamic>? settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Family({
    required this.id,
    required this.name,
    this.currency = 'CNY',
    this.timezone = 'Asia/Shanghai',
    this.locale = 'zh-CN',
    this.fiscalYearStart = 1,
    this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'],
      name: json['name'],
      currency: json['currency'] ?? 'CNY',
      timezone: json['timezone'] ?? 'Asia/Shanghai',
      locale: json['locale'] ?? 'zh-CN',
      fiscalYearStart: json['fiscal_year_start'] ?? 1,
      settings: json['settings'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'timezone': timezone,
      'locale': locale,
      'fiscal_year_start': fiscalYearStart,
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Family copyWith({
    String? id,
    String? name,
    String? currency,
    String? timezone,
    String? locale,
    int? fiscalYearStart,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Family(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      fiscalYearStart: fiscalYearStart ?? this.fiscalYearStart,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Family设置
class FamilySettings {
  final String currency;
  final String locale;
  final String timezone;
  final int startOfWeek;

  FamilySettings({
    required this.currency,
    required this.locale,
    required this.timezone,
    required this.startOfWeek,
  });

  factory FamilySettings.fromJson(Map<String, dynamic> json) {
    return FamilySettings(
      currency: json['currency'] ?? 'CNY',
      locale: json['locale'] ?? 'zh_CN',
      timezone: json['timezone'] ?? 'Asia/Shanghai',
      startOfWeek: json['start_of_week'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      'locale': locale,
      'timezone': timezone,
      'start_of_week': startOfWeek,
    };
  }
}

/// Family成员角色
enum FamilyRole {
  owner('owner', '拥有者', 4),
  admin('admin', '管理员', 3),
  member('member', '成员', 2),
  viewer('viewer', '观察者', 1);

  final String value;
  final String label;
  final int level;

  const FamilyRole(this.value, this.label, this.level);

  static FamilyRole fromString(String? value) {
    return FamilyRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => FamilyRole.viewer,
    );
  }

  /// 是否有管理权限
  bool get canManage => level >= admin.level;

  /// 是否可以记账
  bool get canWrite => level >= member.level;

  /// 是否可以查看
  bool get canRead => level >= viewer.level;

  /// 是否是拥有者
  bool get isOwner => this == owner;
}

/// Family成员关系
class FamilyMember {
  final String id;
  final String familyId;
  final String userId;
  final FamilyRole role;
  final Map<String, dynamic>? permissions;
  final DateTime joinedAt;

  FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    this.permissions,
    required this.joinedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'],
      familyId: json['family_id'],
      userId: json['user_id'],
      role: FamilyRole.fromString(json['role']),
      permissions: json['permissions'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'role': role.value,
      'permissions': permissions,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

/// 用户的Family信息（包含Family详情和角色）
class UserFamilyInfo {
  final Family family;
  final FamilyRole role;
  final DateTime joinedAt;
  final bool isCurrent;

  UserFamilyInfo({
    required this.family,
    required this.role,
    required this.joinedAt,
    this.isCurrent = false,
  });

  factory UserFamilyInfo.fromJson(Map<String, dynamic> json) {
    return UserFamilyInfo(
      family: Family.fromJson(json['family']),
      role: FamilyRole.fromString(json['role']),
      joinedAt: DateTime.parse(json['joined_at']),
      isCurrent: json['is_current'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'family': family.toJson(),
      'role': role.value,
      'joined_at': joinedAt.toIso8601String(),
      'is_current': isCurrent,
    };
  }

  /// 获取角色标签颜色
  Color get roleColor {
    switch (role) {
      case FamilyRole.owner:
        return const Color(0xFF6366F1); // 紫色
      case FamilyRole.admin:
        return const Color(0xFF3B82F6); // 蓝色
      case FamilyRole.member:
        return const Color(0xFF10B981); // 绿色
      case FamilyRole.viewer:
        return const Color(0xFF6B7280); // 灰色
    }
  }

  /// 获取角色图标
  String get roleIcon {
    switch (role) {
      case FamilyRole.owner:
        return '👑';
      case FamilyRole.admin:
        return '⚙️';
      case FamilyRole.member:
        return '👤';
      case FamilyRole.viewer:
        return '👁️';
    }
  }
}

/// 创建Family请求
class CreateFamilyRequest {
  final String name;
  final String currency;
  final String timezone;
  final String locale;
  final int fiscalYearStart;
  final Map<String, dynamic>? settings;

  CreateFamilyRequest({
    required this.name,
    this.currency = 'CNY',
    this.timezone = 'Asia/Shanghai',
    this.locale = 'zh-CN',
    this.fiscalYearStart = 1,
    this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'currency': currency,
      'timezone': timezone,
      'locale': locale,
      'fiscal_year_start': fiscalYearStart,
      'settings': settings,
    };
  }
}

/// Family邀请
class FamilyInvitation {
  final String id;
  final String familyId;
  final String invitedBy;
  final String invitedEmail;
  final FamilyRole role;
  final String token;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.invitedBy,
    required this.invitedEmail,
    required this.role,
    required this.token,
    required this.expiresAt,
    this.acceptedAt,
    required this.createdAt,
  });

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    return FamilyInvitation(
      id: json['id'],
      familyId: json['family_id'],
      invitedBy: json['invited_by'],
      invitedEmail: json['invited_email'],
      role: FamilyRole.fromString(json['role']),
      token: json['token'],
      expiresAt: DateTime.parse(json['expires_at']),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'invited_by': invitedBy,
      'invited_email': invitedEmail,
      'role': role.value,
      'token': token,
      'expires_at': expiresAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 是否已接受
  bool get isAccepted => acceptedAt != null;
}
