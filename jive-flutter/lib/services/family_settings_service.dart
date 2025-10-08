import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jive_money/services/api/family_service.dart';
import 'dart:async';

/// 家庭设置服务 - 负责设置的持久化和同步
class FamilySettingsService extends ChangeNotifier {
  static const String _keyPrefix = 'family_settings_';
  // static const String _keySyncStatus = 'sync_status'; // unused
  static const String _keyLastSync = 'last_sync';
  static const String _keyPendingChanges = 'pending_changes';

  final FamilyService _familyService;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // 同步状态
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  final List<PendingChange> _pendingChanges = [];

  FamilySettingsService({FamilyService? familyService})
      : _familyService = familyService ?? FamilyService();

  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasPendingChanges => _pendingChanges.isNotEmpty;
  int get pendingChangesCount => _pendingChanges.length;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSyncStatus();
    await _loadPendingChanges();
    _isInitialized = true;

    // 自动同步
    _startAutoSync();

    notifyListeners();
  }

  /// 保存家庭设置
  Future<void> saveFamilySettings(
    String familyId,
    FamilySettings settings,
  ) async {
    await _ensureInitialized();

    final key = '$_keyPrefix$familyId';
    final json = settings.toJson();

    // 保存到本地
    await _prefs.setString(key, jsonEncode(json));

    // 添加到待同步队列
    _addPendingChange(PendingChange(
      type: ChangeType.update,
      entityType: 'family_settings',
      entityId: familyId,
      data: json,
      timestamp: DateTime.now(),
    ));

    // 尝试同步
    unawaited(_syncToServer());

    notifyListeners();
  }

  /// 获取家庭设置
  Future<FamilySettings?> getFamilySettings(String familyId) async {
    await _ensureInitialized();

    final key = '$_keyPrefix$familyId';
    final jsonStr = _prefs.getString(key);

    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr);
        return FamilySettings.fromJson(json);
      } catch (e) {
        debugPrint('Failed to parse family settings: $e');
      }
    }

    // 尝试从服务器获取
    try {
      final settings = await _familyService.getFamilySettings(familyId);
      if (settings != null) {
        await _prefs.setString(key, jsonEncode(settings.toJson()));
        return settings;
      }
    } catch (e) {
      debugPrint('Failed to fetch settings from server: $e');
    }

    return null;
  }

  /// 删除家庭设置
  Future<void> deleteFamilySettings(String familyId) async {
    await _ensureInitialized();

    final key = '$_keyPrefix$familyId';
    await _prefs.remove(key);

    _addPendingChange(PendingChange(
      type: ChangeType.delete,
      entityType: 'family_settings',
      entityId: familyId,
      timestamp: DateTime.now(),
    ));

    unawaited(_syncToServer());
    notifyListeners();
  }

  /// 保存用户偏好设置
  Future<void> saveUserPreferences(
    String familyId,
    UserPreferences preferences,
  ) async {
    await _ensureInitialized();

    final key = '${_keyPrefix}user_pref_$familyId';
    await _prefs.setString(key, jsonEncode(preferences.toJson()));

    _addPendingChange(PendingChange(
      type: ChangeType.update,
      entityType: 'user_preferences',
      entityId: familyId,
      data: preferences.toJson(),
      timestamp: DateTime.now(),
    ));

    unawaited(_syncToServer());
    notifyListeners();
  }

  /// 获取用户偏好设置
  Future<UserPreferences> getUserPreferences(String familyId) async {
    await _ensureInitialized();

    final key = '${_keyPrefix}user_pref_$familyId';
    final jsonStr = _prefs.getString(key);

    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr);
        return UserPreferences.fromJson(json);
      } catch (e) {
        debugPrint('Failed to parse user preferences: $e');
      }
    }

    return UserPreferences.defaultPreferences();
  }

  /// 同步到服务器
  Future<void> _syncToServer() async {
    if (_isSyncing || _pendingChanges.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    final changesToSync = List<PendingChange>.from(_pendingChanges);
    final successfulChanges = <PendingChange>[];

    for (final change in changesToSync) {
      try {
        bool success = false;

        switch (change.entityType) {
          case 'family_settings':
            if (change.type == ChangeType.update) {
              await _familyService.updateFamilySettings(
                change.entityId,
                FamilySettings.fromJson(change.data!).toJson(),
              );
              success = true;
            } else if (change.type == ChangeType.delete) {
              await _familyService.deleteFamilySettings(change.entityId);

              success = true;
            }
            break;

          case 'user_preferences':
            if (change.type == ChangeType.update) {
              await _familyService.updateUserPreferences(
                change.entityId,
                UserPreferences.fromJson(change.data!).toJson(),
              );
              success = true;
            }
            break;
        }

        if (success) {
          successfulChanges.add(change);
        }
      } catch (e) {
        debugPrint('Failed to sync change: $e');
      }
    }

    // 移除已成功同步的更改
    for (final change in successfulChanges) {
      _pendingChanges.remove(change);
    }

    // 更新同步状态
    if (successfulChanges.isNotEmpty) {
      _lastSyncTime = DateTime.now();
      await _saveSyncStatus();
    }

    await _savePendingChanges();

    _isSyncing = false;
    notifyListeners();
  }

  /// 强制同步
  Future<void> forceSync() async {
    unawaited(_syncToServer());
  }

  /// 从服务器拉取最新设置
  Future<void> pullFromServer(String familyId) async {
    try {
      final settings = await _familyService.getFamilySettings(familyId);
      if (settings != null) {
        final key = '$_keyPrefix$familyId';
        await _prefs.setString(key, jsonEncode(settings.toJson()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to pull settings from server: $e');
    }
  }

  /// 清除所有本地设置
  Future<void> clearAllSettings() async {
    await _ensureInitialized();

    final keys = _prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }

    _pendingChanges.clear();
    await _savePendingChanges();

    notifyListeners();
  }

  /// 自动同步
  void _startAutoSync() {
    // 每5分钟自动同步一次
    Future.delayed(const Duration(minutes: 5), () {
      if (_isInitialized && !_isSyncing) {
        _syncToServer().then((_) {
          if (_isInitialized) {
            _startAutoSync();
          }
        });
      }
    });
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 加载同步状态
  Future<void> _loadSyncStatus() async {
    final lastSyncStr = _prefs.getString(_keyLastSync);
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }
  }

  /// 保存同步状态
  Future<void> _saveSyncStatus() async {
    if (_lastSyncTime != null) {
      await _prefs.setString(_keyLastSync, _lastSyncTime!.toIso8601String());
    }
  }

  /// 加载待同步更改
  Future<void> _loadPendingChanges() async {
    final changesStr = _prefs.getString(_keyPendingChanges);
    if (changesStr != null) {
      try {
        final List<dynamic> changesJson = jsonDecode(changesStr);
        _pendingChanges.clear();
        _pendingChanges.addAll(
          changesJson.map((json) => PendingChange.fromJson(json)),
        );
      } catch (e) {
        debugPrint('Failed to load pending changes: $e');
      }
    }
  }

  /// 保存待同步更改
  Future<void> _savePendingChanges() async {
    final changesJson = _pendingChanges.map((c) => c.toJson()).toList();
    await _prefs.setString(_keyPendingChanges, jsonEncode(changesJson));
  }

  /// 添加待同步更改
  void _addPendingChange(PendingChange change) {
    // 移除相同实体的旧更改
    _pendingChanges.removeWhere((c) =>
        c.entityType == change.entityType && c.entityId == change.entityId);

    _pendingChanges.add(change);
    _savePendingChanges();
  }
}

/// 家庭设置
class FamilySettings {
  final String familyId;
  final String name;
  final String? description;
  final String currency;
  final String timezone;
  final String locale;
  final int startOfWeek;
  final bool enableBudget;
  final bool enableRecurring;
  final bool enableAttachments;
  final bool enableLocation;
  final bool enableTags;
  final bool requireApproval;
  final double? approvalThreshold;
  final Map<String, dynamic> customSettings;
  final DateTime updatedAt;

  FamilySettings({
    required this.familyId,
    required this.name,
    this.description,
    required this.currency,
    required this.timezone,
    required this.locale,
    this.startOfWeek = 1,
    this.enableBudget = true,
    this.enableRecurring = true,
    this.enableAttachments = true,
    this.enableLocation = false,
    this.enableTags = true,
    this.requireApproval = false,
    this.approvalThreshold,
    Map<String, dynamic>? customSettings,
    DateTime? updatedAt,
  })  : customSettings = customSettings ?? {},
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'familyId': familyId,
        'name': name,
        'description': description,
        'currency': currency,
        'timezone': timezone,
        'locale': locale,
        'startOfWeek': startOfWeek,
        'enableBudget': enableBudget,
        'enableRecurring': enableRecurring,
        'enableAttachments': enableAttachments,
        'enableLocation': enableLocation,
        'enableTags': enableTags,
        'requireApproval': requireApproval,
        'approvalThreshold': approvalThreshold,
        'customSettings': customSettings,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FamilySettings.fromJson(Map<String, dynamic> json) => FamilySettings(
        familyId: json['familyId'],
        name: json['name'],
        description: json['description'],
        currency: json['currency'],
        timezone: json['timezone'],
        locale: json['locale'],
        startOfWeek: json['startOfWeek'] ?? 1,
        enableBudget: json['enableBudget'] ?? true,
        enableRecurring: json['enableRecurring'] ?? true,
        enableAttachments: json['enableAttachments'] ?? true,
        enableLocation: json['enableLocation'] ?? false,
        enableTags: json['enableTags'] ?? true,
        requireApproval: json['requireApproval'] ?? false,
        approvalThreshold: json['approvalThreshold'],
        customSettings: json['customSettings'] ?? {},
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

/// 用户偏好设置
class UserPreferences {
  final bool showBalance;
  final bool showBudgetWarnings;
  final bool enableNotifications;
  final bool enableEmailNotifications;
  final bool enablePushNotifications;
  final String defaultView;
  final String dateFormat;
  final String timeFormat;
  final String numberFormat;
  final bool compactMode;
  final bool darkModeFollowSystem;
  final Map<String, bool> notificationTypes;

  UserPreferences({
    this.showBalance = true,
    this.showBudgetWarnings = true,
    this.enableNotifications = true,
    this.enableEmailNotifications = false,
    this.enablePushNotifications = true,
    this.defaultView = 'dashboard',
    this.dateFormat = 'yyyy-MM-dd',
    this.timeFormat = 'HH:mm',
    this.numberFormat = '#,##0.00',
    this.compactMode = false,
    this.darkModeFollowSystem = true,
    Map<String, bool>? notificationTypes,
  }) : notificationTypes = notificationTypes ?? _defaultNotificationTypes();

  static Map<String, bool> _defaultNotificationTypes() => {
        'transaction_added': true,
        'transaction_edited': false,
        'transaction_deleted': false,
        'member_joined': true,
        'member_left': true,
        'budget_exceeded': true,
        'weekly_summary': true,
        'monthly_report': true,
      };

  factory UserPreferences.defaultPreferences() => UserPreferences();

  Map<String, dynamic> toJson() => {
        'showBalance': showBalance,
        'showBudgetWarnings': showBudgetWarnings,
        'enableNotifications': enableNotifications,
        'enableEmailNotifications': enableEmailNotifications,
        'enablePushNotifications': enablePushNotifications,
        'defaultView': defaultView,
        'dateFormat': dateFormat,
        'timeFormat': timeFormat,
        'numberFormat': numberFormat,
        'compactMode': compactMode,
        'darkModeFollowSystem': darkModeFollowSystem,
        'notificationTypes': notificationTypes,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        showBalance: json['showBalance'] ?? true,
        showBudgetWarnings: json['showBudgetWarnings'] ?? true,
        enableNotifications: json['enableNotifications'] ?? true,
        enableEmailNotifications: json['enableEmailNotifications'] ?? false,
        enablePushNotifications: json['enablePushNotifications'] ?? true,
        defaultView: json['defaultView'] ?? 'dashboard',
        dateFormat: json['dateFormat'] ?? 'yyyy-MM-dd',
        timeFormat: json['timeFormat'] ?? 'HH:mm',
        numberFormat: json['numberFormat'] ?? '#,##0.00',
        compactMode: json['compactMode'] ?? false,
        darkModeFollowSystem: json['darkModeFollowSystem'] ?? true,
        notificationTypes: Map<String, bool>.from(
          json['notificationTypes'] ?? _defaultNotificationTypes(),
        ),
      );
}

/// 待同步更改
class PendingChange {
  final ChangeType type;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  PendingChange({
    required this.type,
    required this.entityType,
    required this.entityId,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'entityType': entityType,
        'entityId': entityId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingChange.fromJson(Map<String, dynamic> json) => PendingChange(
        type: ChangeType.values.firstWhere(
          (e) => e.toString() == json['type'],
        ),
        entityType: json['entityType'],
        entityId: json['entityId'],
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

/// 更改类型
enum ChangeType {
  create,
  update,
  delete,
}
