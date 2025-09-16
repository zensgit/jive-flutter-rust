// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 令牌存储服务 - 临时使用 SharedPreferences
class TokenStorage {
  // 存储键
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userIdKey = 'user_id';
  static const String _rememberMeKey = 'remember_me';
  
  /// 保存访问令牌
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }
  
  /// 获取访问令牌
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    if (token != null && token.trim().isEmpty) {
      return null;
    }
    return token;
  }
  
  /// 保存刷新令牌
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }
  
  /// 获取刷新令牌
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }
  
  /// 保存令牌（同时保存访问和刷新令牌）
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiryDate,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      if (expiryDate != null) saveTokenExpiry(expiryDate),
    ]);
  }
  
  /// 保存令牌过期时间
  static Future<void> saveTokenExpiry(DateTime expiryDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenExpiryKey, expiryDate.toIso8601String());
  }
  
  /// 获取令牌过期时间
  static Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_tokenExpiryKey);
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }
  
  /// 检查令牌是否过期
  static Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) {
      return true; // 没有过期时间，认为已过期
    }
    return DateTime.now().isAfter(expiry);
  }

  /// 解码简单 JWT (不验证签名) 获取 exp 秒级时间戳，如果本地未存 expiry。
  static DateTime? decodeJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final decoded = String.fromCharCodes(base64.decode(normalized));
      final map = jsonDecode(decoded);
      if (map is Map && map['exp'] is num) {
        final exp = (map['exp'] as num).toInt();
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();
      }
    } catch (_) {}
    return null;
  }
  
  /// 保存用户ID
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }
  
  /// 获取用户ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
  
  /// 设置记住我
  static Future<void> setRememberMe(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
  }
  
  /// 获取记住我状态
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }
  
  /// 清除所有令牌
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_tokenExpiryKey),
      prefs.remove(_userIdKey),
    ]);
  }
  
  /// 清除所有存储数据
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  /// 检查是否已登录
  static Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    
    // 检查是否过期
    final isExpired = await isTokenExpired();
    return !isExpired;
  }
  
  /// 获取认证信息
  static Future<AuthInfo?> getAuthInfo() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final userId = await getUserId();
    final expiry = await getTokenExpiry();
    
    if (accessToken == null || refreshToken == null) {
      return null;
    }
    
    return AuthInfo(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiryDate: expiry,
    );
  }
}

/// 认证信息
class AuthInfo {
  final String accessToken;
  final String refreshToken;
  final String? userId;
  final DateTime? expiryDate;
  
  const AuthInfo({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.expiryDate,
  });
  
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }
  
  Duration get remainingTime {
    if (expiryDate == null) return Duration.zero;
    final remaining = expiryDate!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() => 'AuthInfo(userId: ' + (userId ?? 'null') + ', exp: ' + (expiryDate?.toIso8601String() ?? 'null') + ', expired=' + isExpired.toString() + ')';
}
