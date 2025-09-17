/// 审计日志模型
/// 用于记录系统中的所有重要操作

/// 审计日志操作类型
enum AuditActionType {
  // 认证相关
  userLogin('user_login', '用户登录'),
  userLogout('user_logout', '用户登出'),
  userRegister('user_register', '用户注册'),
  passwordChange('password_change', '密码修改'),

  // 家庭管理
  familyCreate('family_create', '创建家庭'),
  familyUpdate('family_update', '更新家庭'),
  familyDelete('family_delete', '删除家庭'),
  familyArchive('family_archive', '归档家庭'),
  familyRestore('family_restore', '恢复家庭'),

  // 成员管理
  memberInvite('member_invite', '邀请成员'),
  memberAccept('member_accept', '接受邀请'),
  memberDecline('member_decline', '拒绝邀请'),
  memberRemove('member_remove', '移除成员'),
  memberLeave('member_leave', '退出家庭'),
  memberRoleChange('member_role_change', '角色变更'),

  // 交易管理
  transactionCreate('transaction_create', '创建交易'),
  transactionUpdate('transaction_update', '更新交易'),
  transactionDelete('transaction_delete', '删除交易'),
  transactionBulkImport('transaction_bulk_import', '批量导入交易'),
  transactionExport('transaction_export', '导出交易'),

  // 分类管理
  categoryCreate('category_create', '创建分类'),
  categoryUpdate('category_update', '更新分类'),
  categoryDelete('category_delete', '删除分类'),
  categoryMerge('category_merge', '合并分类'),

  // 标签管理
  tagCreate('tag_create', '创建标签'),
  tagUpdate('tag_update', '更新标签'),
  tagDelete('tag_delete', '删除标签'),

  // 设置变更
  settingsUpdate('settings_update', '更新设置'),
  currencyChange('currency_change', '货币变更'),
  timezoneChange('timezone_change', '时区变更'),

  // 数据操作
  dataExport('data_export', '数据导出'),
  dataImport('data_import', '数据导入'),
  dataBackup('data_backup', '数据备份'),
  dataRestore('data_restore', '数据恢复'),

  // 安全相关
  permissionGrant('permission_grant', '授予权限'),
  permissionRevoke('permission_revoke', '撤销权限'),
  securityAlert('security_alert', '安全警报'),
  suspiciousActivity('suspicious_activity', '可疑活动');

  final String value;
  final String label;

  const AuditActionType(this.value, this.label);

  static AuditActionType fromString(String? value) {
    return AuditActionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AuditActionType.userLogin,
    );
  }
}

/// 审计日志严重级别
enum AuditSeverity {
  info('info', '信息', 0),
  warning('warning', '警告', 1),
  error('error', '错误', 2),
  critical('critical', '严重', 3);

  final String value;
  final String label;
  final int level;

  const AuditSeverity(this.value, this.label, this.level);

  static AuditSeverity fromString(String? value) {
    return AuditSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => AuditSeverity.info,
    );
  }
}

/// 审计日志实体
class AuditLog {
  final String id;
  final String familyId;
  final String userId;
  final String? userName;
  final AuditActionType actionType;
  final String actionDescription;
  final Map<String, dynamic>? metadata;
  final String? targetId;
  final String? targetType;
  final String? targetName;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final AuditSeverity severity;
  final String ipAddress;
  final String? userAgent;
  final String? deviceInfo;
  final DateTime createdAt;
  final bool isSystemGenerated;

  AuditLog({
    required this.id,
    required this.familyId,
    required this.userId,
    this.userName,
    required this.actionType,
    required this.actionDescription,
    this.metadata,
    this.targetId,
    this.targetType,
    this.targetName,
    this.oldValue,
    this.newValue,
    this.severity = AuditSeverity.info,
    required this.ipAddress,
    this.userAgent,
    this.deviceInfo,
    required this.createdAt,
    this.isSystemGenerated = false,
  });

  /// 从JSON创建
  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      familyId: json['family_id'],
      userId: json['user_id'],
      userName: json['user_name'],
      actionType: AuditActionType.fromString(json['action_type']),
      actionDescription: json['action_description'],
      metadata: json['metadata'],
      targetId: json['target_id'],
      targetType: json['target_type'],
      targetName: json['target_name'],
      oldValue: json['old_value'],
      newValue: json['new_value'],
      severity: AuditSeverity.fromString(json['severity']),
      ipAddress: json['ip_address'] ?? 'Unknown',
      userAgent: json['user_agent'],
      deviceInfo: json['device_info'],
      createdAt: DateTime.parse(json['created_at']),
      isSystemGenerated: json['is_system_generated'] ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'user_name': userName,
      'action_type': actionType.value,
      'action_description': actionDescription,
      'metadata': metadata,
      'target_id': targetId,
      'target_type': targetType,
      'target_name': targetName,
      'old_value': oldValue,
      'new_value': newValue,
      'severity': severity.value,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'device_info': deviceInfo,
      'created_at': createdAt.toIso8601String(),
      'is_system_generated': isSystemGenerated,
    };
  }

  /// 获取变更摘要
  String get changeSummary {
    if (oldValue == null || newValue == null) {
      return actionDescription;
    }

    final changes = <String>[];
    final allKeys = {...oldValue!.keys, ...newValue!.keys};

    for (final key in allKeys) {
      final oldVal = oldValue![key];
      final newVal = newValue![key];

      if (oldVal != newVal) {
        changes.add('$key: $oldVal → $newVal');
      }
    }

    return changes.isEmpty ? actionDescription : changes.join(', ');
  }

  /// 获取时间描述
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 复制并更新
  AuditLog copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? userName,
    AuditActionType? actionType,
    String? actionDescription,
    Map<String, dynamic>? metadata,
    String? targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    AuditSeverity? severity,
    String? ipAddress,
    String? userAgent,
    String? deviceInfo,
    DateTime? createdAt,
    bool? isSystemGenerated,
  }) {
    return AuditLog(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      actionType: actionType ?? this.actionType,
      actionDescription: actionDescription ?? this.actionDescription,
      metadata: metadata ?? this.metadata,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      targetName: targetName ?? this.targetName,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      severity: severity ?? this.severity,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      createdAt: createdAt ?? this.createdAt,
      isSystemGenerated: isSystemGenerated ?? this.isSystemGenerated,
    );
  }
}

/// 审计日志统计
class AuditLogStatistics {
  final int totalLogs;
  final int todayLogs;
  final int weekLogs;
  final int monthLogs;
  final Map<AuditActionType, int> actionCounts;
  final Map<AuditSeverity, int> severityCounts;
  final List<UserActivitySummary> topUsers;
  final List<String> recentAlerts;
  final DateTime? lastActivityAt;

  AuditLogStatistics({
    required this.totalLogs,
    required this.todayLogs,
    required this.weekLogs,
    required this.monthLogs,
    required this.actionCounts,
    required this.severityCounts,
    required this.topUsers,
    required this.recentAlerts,
    this.lastActivityAt,
  });

  /// 从JSON创建
  factory AuditLogStatistics.fromJson(Map<String, dynamic> json) {
    final actionCounts = <AuditActionType, int>{};
    if (json['action_counts'] != null) {
      (json['action_counts'] as Map<String, dynamic>).forEach((key, value) {
        actionCounts[AuditActionType.fromString(key)] = value as int;
      });
    }

    final severityCounts = <AuditSeverity, int>{};
    if (json['severity_counts'] != null) {
      (json['severity_counts'] as Map<String, dynamic>).forEach((key, value) {
        severityCounts[AuditSeverity.fromString(key)] = value as int;
      });
    }

    return AuditLogStatistics(
      totalLogs: json['total_logs'] ?? 0,
      todayLogs: json['today_logs'] ?? 0,
      weekLogs: json['week_logs'] ?? 0,
      monthLogs: json['month_logs'] ?? 0,
      actionCounts: actionCounts,
      severityCounts: severityCounts,
      topUsers: (json['top_users'] as List<dynamic>?)
              ?.map((u) => UserActivitySummary.fromJson(u))
              .toList() ??
          [],
      recentAlerts:
          (json['recent_alerts'] as List<dynamic>?)?.cast<String>() ?? [],
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.parse(json['last_activity_at'])
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    final actionCountsJson = <String, int>{};
    actionCounts.forEach((key, value) {
      actionCountsJson[key.value] = value;
    });

    final severityCountsJson = <String, int>{};
    severityCounts.forEach((key, value) {
      severityCountsJson[key.value] = value;
    });

    return {
      'total_logs': totalLogs,
      'today_logs': todayLogs,
      'week_logs': weekLogs,
      'month_logs': monthLogs,
      'action_counts': actionCountsJson,
      'severity_counts': severityCountsJson,
      'top_users': topUsers.map((u) => u.toJson()).toList(),
      'recent_alerts': recentAlerts,
      'last_activity_at': lastActivityAt?.toIso8601String(),
    };
  }
}

/// 用户活动摘要
class UserActivitySummary {
  final String userId;
  final String userName;
  final int actionCount;
  final DateTime lastActivityAt;
  final List<AuditActionType> recentActions;

  UserActivitySummary({
    required this.userId,
    required this.userName,
    required this.actionCount,
    required this.lastActivityAt,
    required this.recentActions,
  });

  /// 从JSON创建
  factory UserActivitySummary.fromJson(Map<String, dynamic> json) {
    return UserActivitySummary(
      userId: json['user_id'],
      userName: json['user_name'],
      actionCount: json['action_count'] ?? 0,
      lastActivityAt: DateTime.parse(json['last_activity_at']),
      recentActions: (json['recent_actions'] as List<dynamic>?)
              ?.map((a) => AuditActionType.fromString(a))
              .toList() ??
          [],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'action_count': actionCount,
      'last_activity_at': lastActivityAt.toIso8601String(),
      'recent_actions': recentActions.map((a) => a.value).toList(),
    };
  }
}

/// 审计日志过滤器
class AuditLogFilter {
  final String? familyId;
  final String? userId;
  final List<AuditActionType>? actionTypes;
  final List<AuditSeverity>? severities;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final String? targetType;
  final bool? systemGenerated;

  AuditLogFilter({
    this.familyId,
    this.userId,
    this.actionTypes,
    this.severities,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.targetType,
    this.systemGenerated,
  });

  /// 转换为查询参数
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    if (familyId != null) params['family_id'] = familyId;
    if (userId != null) params['user_id'] = userId;
    if (actionTypes != null && actionTypes!.isNotEmpty) {
      params['action_types'] = actionTypes!.map((t) => t.value).join(',');
    }
    if (severities != null && severities!.isNotEmpty) {
      params['severities'] = severities!.map((s) => s.value).join(',');
    }
    if (startDate != null) params['start_date'] = startDate!.toIso8601String();
    if (endDate != null) params['end_date'] = endDate!.toIso8601String();
    if (searchQuery != null) params['q'] = searchQuery;
    if (targetType != null) params['target_type'] = targetType;
    if (systemGenerated != null) params['system_generated'] = systemGenerated;

    return params;
  }

  /// 复制并更新
  AuditLogFilter copyWith({
    String? familyId,
    String? userId,
    List<AuditActionType>? actionTypes,
    List<AuditSeverity>? severities,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    String? targetType,
    bool? systemGenerated,
  }) {
    return AuditLogFilter(
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      actionTypes: actionTypes ?? this.actionTypes,
      severities: severities ?? this.severities,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      targetType: targetType ?? this.targetType,
      systemGenerated: systemGenerated ?? this.systemGenerated,
    );
  }
}
