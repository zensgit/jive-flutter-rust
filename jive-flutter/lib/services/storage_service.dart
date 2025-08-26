import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/theme_models.dart';

/// 本地存储服务
/// 管理用户数据、微信绑定信息等持久化数据
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // 存储键常量
  static const String _keyUserData = 'user_data';
  static const String _keyWeChatData = 'wechat_data'; 
  static const String _keyAuthToken = 'auth_token';
  static const String _keyLoginHistory = 'login_history';
  static const String _keyAppSettings = 'app_settings';
  static const String _keyThemeSettings = 'theme_settings';
  static const String _keyCustomThemes = 'custom_themes';
  static const String _keySharedThemes = 'shared_themes';

  // 模拟的内存存储（实际项目中应使用 SharedPreferences 或 Hive）
  final Map<String, dynamic> _storage = {};

  /// 保存用户数据
  Future<bool> saveUserData(UserData userData) async {
    try {
      _storage[_keyUserData] = userData.toJson();
      await _simulateDelay();
      debugPrint('用户数据已保存: ${userData.username}');
      return true;
    } catch (e) {
      debugPrint('保存用户数据失败: $e');
      return false;
    }
  }

  /// 获取用户数据
  Future<UserData?> getUserData() async {
    try {
      await _simulateDelay();
      final data = _storage[_keyUserData];
      if (data != null) {
        return UserData.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('获取用户数据失败: $e');
      return null;
    }
  }

  /// 保存微信绑定数据
  Future<bool> saveWeChatData(WeChatBindingData wechatData) async {
    try {
      _storage[_keyWeChatData] = wechatData.toJson();
      await _simulateDelay();
      debugPrint('微信绑定数据已保存: ${wechatData.nickname}');
      return true;
    } catch (e) {
      debugPrint('保存微信绑定数据失败: $e');
      return false;
    }
  }

  /// 获取微信绑定数据
  Future<WeChatBindingData?> getWeChatData() async {
    try {
      await _simulateDelay();
      final data = _storage[_keyWeChatData];
      if (data != null) {
        return WeChatBindingData.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('获取微信绑定数据失败: $e');
      return null;
    }
  }

  /// 删除微信绑定数据
  Future<bool> removeWeChatData() async {
    try {
      _storage.remove(_keyWeChatData);
      await _simulateDelay();
      debugPrint('微信绑定数据已删除');
      return true;
    } catch (e) {
      debugPrint('删除微信绑定数据失败: $e');
      return false;
    }
  }

  /// 保存认证令牌
  Future<bool> saveAuthToken(String token) async {
    try {
      _storage[_keyAuthToken] = token;
      await _simulateDelay();
      debugPrint('认证令牌已保存');
      return true;
    } catch (e) {
      debugPrint('保存认证令牌失败: $e');
      return false;
    }
  }

  /// 获取认证令牌
  Future<String?> getAuthToken() async {
    try {
      await _simulateDelay();
      return _storage[_keyAuthToken];
    } catch (e) {
      debugPrint('获取认证令牌失败: $e');
      return null;
    }
  }

  /// 添加登录历史记录
  Future<bool> addLoginHistory(LoginHistoryItem item) async {
    try {
      List<dynamic> history = _storage[_keyLoginHistory] ?? [];
      history.insert(0, item.toJson()); // 最新的在前面
      
      // 只保留最近20条记录
      if (history.length > 20) {
        history = history.take(20).toList();
      }
      
      _storage[_keyLoginHistory] = history;
      await _simulateDelay();
      debugPrint('登录历史已记录: ${item.loginMethod}');
      return true;
    } catch (e) {
      debugPrint('保存登录历史失败: $e');
      return false;
    }
  }

  /// 获取登录历史
  Future<List<LoginHistoryItem>> getLoginHistory() async {
    try {
      await _simulateDelay();
      List<dynamic> history = _storage[_keyLoginHistory] ?? [];
      return history.map((item) => LoginHistoryItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('获取登录历史失败: $e');
      return [];
    }
  }

  /// 清除所有数据（登出时使用）
  Future<bool> clearAllData() async {
    try {
      _storage.clear();
      await _simulateDelay();
      debugPrint('所有本地数据已清除');
      return true;
    } catch (e) {
      debugPrint('清除数据失败: $e');
      return false;
    }
  }

  /// 检查用户是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    final userData = await getUserData();
    return token != null && userData != null;
  }

  /// 模拟网络延迟
  Future<void> _simulateDelay() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // 主题相关存储方法
  /// 保存主题设置
  Future<bool> saveThemeSettings(AppThemeSettings settings) async {
    try {
      _storage[_keyThemeSettings] = settings.toJson();
      await _simulateDelay();
      debugPrint('主题设置已保存');
      return true;
    } catch (e) {
      debugPrint('保存主题设置失败: $e');
      return false;
    }
  }

  /// 获取主题设置
  Future<AppThemeSettings?> getThemeSettings() async {
    try {
      await _simulateDelay();
      final data = _storage[_keyThemeSettings];
      if (data != null) {
        return AppThemeSettings.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('获取主题设置失败: $e');
      return null;
    }
  }

  /// 保存自定义主题列表
  Future<bool> saveCustomThemes(List<CustomThemeData> themes) async {
    try {
      final themesJson = themes.map((theme) => theme.toJson()).toList();
      _storage[_keyCustomThemes] = themesJson;
      await _simulateDelay();
      debugPrint('自定义主题列表已保存，共 ${themes.length} 个');
      return true;
    } catch (e) {
      debugPrint('保存自定义主题列表失败: $e');
      return false;
    }
  }

  /// 获取自定义主题列表
  Future<List<CustomThemeData>> getCustomThemes() async {
    try {
      await _simulateDelay();
      final data = _storage[_keyCustomThemes];
      if (data != null && data is List) {
        return data.map((json) => CustomThemeData.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('获取自定义主题列表失败: $e');
      return [];
    }
  }

  /// 保存分享主题数据
  Future<bool> saveSharedTheme(String shareCode, SharedThemeData sharedTheme) async {
    try {
      Map<String, dynamic> sharedThemes = _storage[_keySharedThemes] ?? {};
      sharedThemes[shareCode] = sharedTheme.toJson();
      _storage[_keySharedThemes] = sharedThemes;
      await _simulateDelay();
      debugPrint('分享主题已保存: $shareCode');
      return true;
    } catch (e) {
      debugPrint('保存分享主题失败: $e');
      return false;
    }
  }

  /// 获取分享主题数据
  Future<SharedThemeData?> getSharedTheme(String shareCode) async {
    try {
      await _simulateDelay();
      final sharedThemes = _storage[_keySharedThemes];
      if (sharedThemes != null && sharedThemes[shareCode] != null) {
        return SharedThemeData.fromJson(sharedThemes[shareCode]);
      }
      return null;
    } catch (e) {
      debugPrint('获取分享主题失败: $e');
      return null;
    }
  }

  /// 删除过期的分享主题
  Future<void> cleanupExpiredSharedThemes() async {
    try {
      Map<String, dynamic> sharedThemes = _storage[_keySharedThemes] ?? {};
      final now = DateTime.now();
      
      final validThemes = <String, dynamic>{};
      for (final entry in sharedThemes.entries) {
        try {
          final sharedTheme = SharedThemeData.fromJson(entry.value);
          if (now.isBefore(sharedTheme.expiresAt)) {
            validThemes[entry.key] = entry.value;
          }
        } catch (e) {
          // 跳过无效的主题数据
          debugPrint('跳过无效的分享主题: ${entry.key}');
        }
      }
      
      _storage[_keySharedThemes] = validThemes;
      debugPrint('清理过期分享主题完成，剩余 ${validThemes.length} 个');
    } catch (e) {
      debugPrint('清理过期分享主题失败: $e');
    }
  }
}

/// 用户数据模型
class UserData {
  final String id;
  final String username;
  final String email;
  final String? avatar;
  final String? realName; // 真实姓名
  final DateTime registerTime;
  final DateTime lastLoginTime;
  final String role; // Owner, Admin, Member, Viewer

  UserData({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.realName,
    required this.registerTime,
    required this.lastLoginTime,
    this.role = 'Owner',
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      realName: json['real_name'],
      registerTime: DateTime.parse(json['register_time'] ?? DateTime.now().toIso8601String()),
      lastLoginTime: DateTime.parse(json['last_login_time'] ?? DateTime.now().toIso8601String()),
      role: json['role'] ?? 'Owner',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'real_name': realName,
      'register_time': registerTime.toIso8601String(),
      'last_login_time': lastLoginTime.toIso8601String(),
      'role': role,
    };
  }

  UserData copyWith({
    String? username,
    String? email,
    String? avatar,
    String? realName,
    DateTime? lastLoginTime,
    String? role,
  }) {
    return UserData(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      realName: realName ?? this.realName,
      registerTime: registerTime,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      role: role ?? this.role,
    );
  }
}

/// 微信绑定数据模型
class WeChatBindingData {
  final String openId;
  final String? unionId;
  final String nickname;
  final String headImgUrl;
  final int sex;
  final String province;
  final String city;
  final String country;
  final DateTime bindTime;

  WeChatBindingData({
    required this.openId,
    this.unionId,
    required this.nickname,
    required this.headImgUrl,
    required this.sex,
    required this.province,
    required this.city,
    required this.country,
    required this.bindTime,
  });

  factory WeChatBindingData.fromJson(Map<String, dynamic> json) {
    return WeChatBindingData(
      openId: json['openid'] ?? '',
      unionId: json['unionid'],
      nickname: json['nickname'] ?? '',
      headImgUrl: json['headimgurl'] ?? '',
      sex: json['sex'] ?? 0,
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      bindTime: DateTime.parse(json['bind_time'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openid': openId,
      'unionid': unionId,
      'nickname': nickname,
      'headimgurl': headImgUrl,
      'sex': sex,
      'province': province,
      'city': city,
      'country': country,
      'bind_time': bindTime.toIso8601String(),
    };
  }

  String get sexText {
    switch (sex) {
      case 1:
        return '男';
      case 2:
        return '女';
      default:
        return '未知';
    }
  }
}

/// 登录历史项
class LoginHistoryItem {
  final DateTime loginTime;
  final String loginMethod; // email, username, wechat
  final String? deviceInfo;
  final String? location;
  final bool success;

  LoginHistoryItem({
    required this.loginTime,
    required this.loginMethod,
    this.deviceInfo,
    this.location,
    this.success = true,
  });

  factory LoginHistoryItem.fromJson(Map<String, dynamic> json) {
    return LoginHistoryItem(
      loginTime: DateTime.parse(json['login_time'] ?? DateTime.now().toIso8601String()),
      loginMethod: json['login_method'] ?? '',
      deviceInfo: json['device_info'],
      location: json['location'],
      success: json['success'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login_time': loginTime.toIso8601String(),
      'login_method': loginMethod,
      'device_info': deviceInfo,
      'location': location,
      'success': success,
    };
  }
}
