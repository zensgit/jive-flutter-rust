import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/family.dart' as family_model;
import 'api/family_service.dart';

/// 动态权限服务 - 实时权限管理
class DynamicPermissionsService extends ChangeNotifier {
  static DynamicPermissionsService? _instance;
  
  final FamilyService _familyService;
  
  // 权限缓存
  final Map<String, UserPermissions> _permissionsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // 实时更新流
  StreamController<PermissionUpdate>? _permissionUpdateStream;
  Stream<PermissionUpdate>? _updateStream;
  
  // 权限继承规则
  final Map<String, List<String>> _permissionInheritance = {
    'admin.*': ['transaction.*', 'budget.*', 'category.*', 'report.*'],
    'transaction.manage': ['transaction.create', 'transaction.edit', 'transaction.delete'],
    'budget.manage': ['budget.create', 'budget.edit', 'budget.delete'],
    'category.manage': ['category.create', 'category.edit', 'category.delete'],
  };
  
  // 临时权限
  final Map<String, TemporaryPermission> _temporaryPermissions = {};
  
  // 权限委托
  final Map<String, PermissionDelegation> _delegations = {};

  DynamicPermissionsService._({FamilyService? familyService})
      : _familyService = familyService ?? FamilyService() {
    _initializeStream();
    _startPermissionSync();
  }

  factory DynamicPermissionsService({FamilyService? familyService}) {
    _instance ??= DynamicPermissionsService._(familyService: familyService);
    return _instance!;
  }

  Stream<PermissionUpdate> get updateStream => _updateStream!;

  void _initializeStream() {
    _permissionUpdateStream = StreamController<PermissionUpdate>.broadcast();
    _updateStream = _permissionUpdateStream!.stream;
  }

  /// 获取用户权限
  Future<UserPermissions> getUserPermissions({
    required String userId,
    required String familyId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$userId:$familyId';
    
    // 检查缓存
    if (!forceRefresh && _permissionsCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey]!;
      if (DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _permissionsCache[cacheKey]!;
      }
    }
    
    try {
      // 从服务器获取权限
      final permissions = await _familyService.getUserPermissions(userId, familyId);
      
      if (permissions != null) {
        // 应用继承规则
        final expandedPermissions = _expandPermissions(permissions.permissions);
        
        // 应用临时权限
        final withTemporary = _applyTemporaryPermissions(
          expandedPermissions,
          userId,
          familyId,
        );
        
        // 应用委托权限
        final withDelegations = _applyDelegatedPermissions(
          withTemporary,
          userId,
          familyId,
        );
        
        final userPermissions = UserPermissions(
          userId: userId,
          familyId: familyId,
          role: permissions.role,
          permissions: withDelegations,
          customPermissions: permissions.customPermissions,
          restrictions: permissions.restrictions,
        );
        
        // 更新缓存
        _permissionsCache[cacheKey] = userPermissions;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return userPermissions;
      }
    } catch (e) {
      debugPrint('Failed to get user permissions: $e');
    }
    
    // 返回默认权限
    return UserPermissions(
      userId: userId,
      familyId: familyId,
      role: family_model.FamilyRole.viewer,
      permissions: [],
    );
  }

  /// 检查用户是否有权限
  Future<bool> hasPermission({
    required String userId,
    required String familyId,
    required String permission,
  }) async {
    final userPermissions = await getUserPermissions(
      userId: userId,
      familyId: familyId,
    );
    
    // 检查直接权限
    if (userPermissions.permissions.contains(permission)) {
      return true;
    }
    
    // 检查通配符权限
    for (final perm in userPermissions.permissions) {
      if (perm.endsWith('*')) {
        final prefix = perm.substring(0, perm.length - 1);
        if (permission.startsWith(prefix)) {
          return true;
        }
      }
    }
    
    // 检查限制
    if (userPermissions.restrictions?.contains(permission) == true) {
      return false;
    }
    
    return false;
  }

  /// 批量检查权限
  Future<Map<String, bool>> checkPermissions({
    required String userId,
    required String familyId,
    required List<String> permissions,
  }) async {
    final results = <String, bool>{};
    
    for (final permission in permissions) {
      results[permission] = await hasPermission(
        userId: userId,
        familyId: familyId,
        permission: permission,
      );
    }
    
    return results;
  }

  /// 实时更新权限
  Future<void> updateUserPermissions({
    required String userId,
    required String familyId,
    required List<String> permissions,
    String? reason,
  }) async {
    try {
      final success = await _familyService.updateUserPermissions(
        userId,
        familyId,
        permissions,
      );
      
      if (success) {
        // 清除缓存
        final cacheKey = '$userId:$familyId';
        _permissionsCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        
        // 发送更新通知
        _permissionUpdateStream?.add(PermissionUpdate(
          userId: userId,
          familyId: familyId,
          permissions: permissions,
          timestamp: DateTime.now(),
          reason: reason,
        ));
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update user permissions: $e');
      rethrow;
    }
  }

  /// 授予临时权限
  Future<void> grantTemporaryPermission({
    required String userId,
    required String familyId,
    required String permission,
    required Duration duration,
    String? reason,
  }) async {
    final key = '$userId:$familyId:$permission';
    final expiresAt = DateTime.now().add(duration);
    
    _temporaryPermissions[key] = TemporaryPermission(
      userId: userId,
      familyId: familyId,
      permission: permission,
      grantedAt: DateTime.now(),
      expiresAt: expiresAt,
      reason: reason,
    );
    
    // 清除缓存强制刷新
    final cacheKey = '$userId:$familyId';
    _permissionsCache.remove(cacheKey);
    
    // 记录到服务器
    try {
      await _familyService.grantTemporaryPermission(
        userId,
        familyId,
        permission,
        expiresAt,
        reason,
      );
    } catch (e) {
      debugPrint('Failed to grant temporary permission: $e');
    }
    
    // 设置自动撤销
    Future.delayed(duration, () {
      revokeTemporaryPermission(
        userId: userId,
        familyId: familyId,
        permission: permission,
      );
    });
    
    notifyListeners();
  }

  /// 撤销临时权限
  Future<void> revokeTemporaryPermission({
    required String userId,
    required String familyId,
    required String permission,
  }) async {
    final key = '$userId:$familyId:$permission';
    _temporaryPermissions.remove(key);
    
    // 清除缓存
    final cacheKey = '$userId:$familyId';
    _permissionsCache.remove(cacheKey);
    
    // 通知服务器
    try {
      await _familyService.revokeTemporaryPermission(
        userId,
        familyId,
        permission,
      );
    } catch (e) {
      debugPrint('Failed to revoke temporary permission: $e');
    }
    
    notifyListeners();
  }

  /// 委托权限
  Future<void> delegatePermission({
    required String fromUserId,
    required String toUserId,
    required String familyId,
    required List<String> permissions,
    DateTime? expiresAt,
    String? reason,
  }) async {
    final key = '$toUserId:$familyId';
    
    _delegations[key] = PermissionDelegation(
      fromUserId: fromUserId,
      toUserId: toUserId,
      familyId: familyId,
      permissions: permissions,
      delegatedAt: DateTime.now(),
      expiresAt: expiresAt,
      reason: reason,
    );
    
    // 清除缓存
    _permissionsCache.remove(key);
    
    // 记录到服务器
    try {
      await _familyService.delegatePermissions(
        fromUserId,
        toUserId,
        familyId,
        permissions,
        expiresAt,
        reason,
      );
    } catch (e) {
      debugPrint('Failed to delegate permissions: $e');
    }
    
    // 如果有过期时间，设置自动撤销
    if (expiresAt != null) {
      final duration = expiresAt.difference(DateTime.now());
      if (duration.isNegative) return;
      
      Future.delayed(duration, () {
        revokeDelegation(
          toUserId: toUserId,
          familyId: familyId,
        );
      });
    }
    
    notifyListeners();
  }

  /// 撤销委托
  Future<void> revokeDelegation({
    required String toUserId,
    required String familyId,
  }) async {
    final key = '$toUserId:$familyId';
    _delegations.remove(key);
    
    // 清除缓存
    _permissionsCache.remove(key);
    
    // 通知服务器
    try {
      await _familyService.revokeDelegation(toUserId, familyId);
    } catch (e) {
      debugPrint('Failed to revoke delegation: $e');
    }
    
    notifyListeners();
  }

  /// 展开权限（应用继承规则）
  List<String> _expandPermissions(List<String> permissions) {
    final expanded = Set<String>.from(permissions);
    
    for (final permission in permissions) {
      if (_permissionInheritance.containsKey(permission)) {
        expanded.addAll(_permissionInheritance[permission]!);
      }
      
      // 处理通配符
      if (permission.endsWith('.*')) {
        final prefix = permission.substring(0, permission.length - 2);
        _permissionInheritance.forEach((key, values) {
          if (key.startsWith(prefix)) {
            expanded.addAll(values);
          }
        });
      }
    }
    
    return expanded.toList();
  }

  /// 应用临时权限
  List<String> _applyTemporaryPermissions(
    List<String> permissions,
    String userId,
    String familyId,
  ) {
    final result = Set<String>.from(permissions);
    final now = DateTime.now();
    
    _temporaryPermissions.forEach((key, temp) {
      if (temp.userId == userId &&
          temp.familyId == familyId &&
          temp.expiresAt.isAfter(now)) {
        result.add(temp.permission);
      }
    });
    
    return result.toList();
  }

  /// 应用委托权限
  List<String> _applyDelegatedPermissions(
    List<String> permissions,
    String userId,
    String familyId,
  ) {
    final result = Set<String>.from(permissions);
    final key = '$userId:$familyId';
    
    if (_delegations.containsKey(key)) {
      final delegation = _delegations[key]!;
      if (delegation.expiresAt == null ||
          delegation.expiresAt!.isAfter(DateTime.now())) {
        result.addAll(delegation.permissions);
      }
    }
    
    return result.toList();
  }

  /// 定期同步权限
  void _startPermissionSync() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _syncPermissions();
    });
  }

  /// 同步权限
  Future<void> _syncPermissions() async {
    // 清理过期的临时权限
    final now = DateTime.now();
    _temporaryPermissions.removeWhere((key, temp) {
      return temp.expiresAt.isBefore(now);
    });
    
    // 清理过期的委托
    _delegations.removeWhere((key, delegation) {
      return delegation.expiresAt != null &&
          delegation.expiresAt!.isBefore(now);
    });
    
    // 清理过期的缓存
    _cacheTimestamps.removeWhere((key, timestamp) {
      return now.difference(timestamp) > _cacheExpiry;
    });
    _permissionsCache.removeWhere((key, _) {
      return !_cacheTimestamps.containsKey(key);
    });
    
    notifyListeners();
  }

  /// 清除所有缓存
  void clearCache() {
    _permissionsCache.clear();
    _cacheTimestamps.clear();
    notifyListeners();
  }

  /// 获取用户的所有临时权限
  List<TemporaryPermission> getUserTemporaryPermissions(
    String userId,
    String familyId,
  ) {
    final result = <TemporaryPermission>[];
    final now = DateTime.now();
    
    _temporaryPermissions.forEach((key, temp) {
      if (temp.userId == userId &&
          temp.familyId == familyId &&
          temp.expiresAt.isAfter(now)) {
        result.add(temp);
      }
    });
    
    return result;
  }

  /// 获取用户的委托权限
  PermissionDelegation? getUserDelegation(String userId, String familyId) {
    final key = '$userId:$familyId';
    if (_delegations.containsKey(key)) {
      final delegation = _delegations[key]!;
      if (delegation.expiresAt == null ||
          delegation.expiresAt!.isAfter(DateTime.now())) {
        return delegation;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _permissionUpdateStream?.close();
    super.dispose();
  }
}

/// 用户权限
class UserPermissions {
  final String userId;
  final String familyId;
  final family_model.FamilyRole role;
  final List<String> permissions;
  final List<String>? customPermissions;
  final List<String>? restrictions;

  UserPermissions({
    required this.userId,
    required this.familyId,
    required this.role,
    required this.permissions,
    this.customPermissions,
    this.restrictions,
  });
}

/// 权限更新通知
class PermissionUpdate {
  final String userId;
  final String familyId;
  final List<String> permissions;
  final DateTime timestamp;
  final String? reason;

  PermissionUpdate({
    required this.userId,
    required this.familyId,
    required this.permissions,
    required this.timestamp,
    this.reason,
  });
}

/// 临时权限
class TemporaryPermission {
  final String userId;
  final String familyId;
  final String permission;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final String? reason;

  TemporaryPermission({
    required this.userId,
    required this.familyId,
    required this.permission,
    required this.grantedAt,
    required this.expiresAt,
    this.reason,
  });
}

/// 权限委托
class PermissionDelegation {
  final String fromUserId;
  final String toUserId;
  final String familyId;
  final List<String> permissions;
  final DateTime delegatedAt;
  final DateTime? expiresAt;
  final String? reason;

  PermissionDelegation({
    required this.fromUserId,
    required this.toUserId,
    required this.familyId,
    required this.permissions,
    required this.delegatedAt,
    this.expiresAt,
    this.reason,
  });
}