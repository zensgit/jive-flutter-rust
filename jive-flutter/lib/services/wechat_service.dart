import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// WeChat登录服务
/// 封装微信登录和绑定相关功能
class WeChatService {
  static const _platform = MethodChannel('com.jivemoney.flutter/wechat');
  
  /// WeChat应用配置
  static const String _appId = 'wx1234567890abcdef'; // TODO: 替换为实际的WeChat App ID
  
  /// 初始化WeChat SDK
  static Future<bool> initWeChat() async {
    // Web环境下直接返回成功，不调用平台方法
    if (kIsWeb) {
      debugPrint('Web环境下跳过微信SDK初始化');
      return true;
    }
    
    try {
      final result = await _platform.invokeMethod('initWeChat', {
        'appId': _appId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('WeChat初始化失败: ${e.message}');
      return false;
    }
  }
  
  /// 检查是否安装了微信
  static Future<bool> isWeChatInstalled() async {
    // Web环境下始终返回false，使用模拟登录
    if (kIsWeb) {
      return false;
    }
    
    try {
      final result = await _platform.invokeMethod('isWeChatInstalled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('检查微信安装状态失败: ${e.message}');
      return false;
    }
  }
  
  /// 微信登录授权
  static Future<WeChatAuthResult?> login() async {
    // Web环境下直接使用模拟登录
    if (kIsWeb) {
      return simulateLogin();
    }
    
    try {
      final result = await _platform.invokeMethod('login');
      if (result != null) {
        return WeChatAuthResult.fromMap(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('微信登录失败: ${e.message}');
      return null;
    }
  }
  
  /// 获取用户信息
  static Future<WeChatUserInfo?> getUserInfo(String accessToken, String openId) async {
    // Web环境下直接使用模拟用户信息
    if (kIsWeb) {
      return simulateGetUserInfo();
    }
    
    try {
      final result = await _platform.invokeMethod('getUserInfo', {
        'accessToken': accessToken,
        'openId': openId,
      });
      if (result != null) {
        return WeChatUserInfo.fromMap(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('获取微信用户信息失败: ${e.message}');
      return null;
    }
  }
  
  /// 模拟微信登录（用于Web和开发环境）
  static Future<WeChatAuthResult?> simulateLogin() async {
    // 模拟延迟
    await Future.delayed(const Duration(seconds: 2));
    
    return WeChatAuthResult(
      code: 'mock_code_${DateTime.now().millisecondsSinceEpoch}',
      state: 'mock_state',
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
      openId: 'mock_openid_${DateTime.now().millisecondsSinceEpoch}',
      unionId: 'mock_unionid_${DateTime.now().millisecondsSinceEpoch}',
      expiresIn: 7200,
    );
  }
  
  /// 模拟获取用户信息（用于Web和开发环境）
  static Future<WeChatUserInfo?> simulateGetUserInfo() async {
    await Future.delayed(const Duration(seconds: 1));
    
    return WeChatUserInfo(
      openId: 'mock_openid',
      nickname: '微信用户${DateTime.now().millisecond}',
      headImgUrl: 'https://via.placeholder.com/100',
      sex: 1,
      province: '广东',
      city: '深圳',
      country: '中国',
      unionId: 'mock_unionid',
    );
  }
}

/// WeChat授权结果
class WeChatAuthResult {
  final String code;
  final String? state;
  final String? accessToken;
  final String? refreshToken;
  final String openId;
  final String? unionId;
  final int expiresIn;
  
  WeChatAuthResult({
    required this.code,
    this.state,
    this.accessToken,
    this.refreshToken,
    required this.openId,
    this.unionId,
    required this.expiresIn,
  });
  
  factory WeChatAuthResult.fromMap(Map<String, dynamic> map) {
    return WeChatAuthResult(
      code: map['code'] ?? '',
      state: map['state'],
      accessToken: map['access_token'],
      refreshToken: map['refresh_token'],
      openId: map['openid'] ?? '',
      unionId: map['unionid'],
      expiresIn: map['expires_in'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'state': state,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'openid': openId,
      'unionid': unionId,
      'expires_in': expiresIn,
    };
  }
}

/// WeChat用户信息
class WeChatUserInfo {
  final String openId;
  final String nickname;
  final String headImgUrl;
  final int sex; // 1为男性，2为女性，0为未知
  final String province;
  final String city;
  final String country;
  final String? unionId;
  
  WeChatUserInfo({
    required this.openId,
    required this.nickname,
    required this.headImgUrl,
    required this.sex,
    required this.province,
    required this.city,
    required this.country,
    this.unionId,
  });
  
  factory WeChatUserInfo.fromMap(Map<String, dynamic> map) {
    return WeChatUserInfo(
      openId: map['openid'] ?? '',
      nickname: map['nickname'] ?? '',
      headImgUrl: map['headimgurl'] ?? '',
      sex: map['sex'] ?? 0,
      province: map['province'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      unionId: map['unionid'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'openid': openId,
      'nickname': nickname,
      'headimgurl': headImgUrl,
      'sex': sex,
      'province': province,
      'city': city,
      'country': country,
      'unionid': unionId,
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