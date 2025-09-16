import 'package:dio/dio.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../core/storage/token_storage.dart';
import '../../models/user.dart';

/// 认证服务
class AuthService {
  final _client = HttpClient.instance;
  
  /// 登录方法 - login
  Future<AuthResponse> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    // 支持在开发环境使用用户名“superadmin”直接登录（自动映射为邮箱）
    final normalizedEmail = _normalizeLoginIdentifier(email);
      debugPrint('DEBUG AuthService.login: Called with email=$normalizedEmail');
    try {
      debugPrint('DEBUG AuthService.login: About to make POST request to ${Endpoints.login}');
      final response = await _client.dio.post(
        Endpoints.login,
        data: {
          'email': normalizedEmail,
          'password': password,
          'remember_me': rememberMe,
        },
      );
      
      // 处理我们API的响应格式
      final status = response.statusCode ?? 0;
      final responseData = response.data;
      debugPrint('DEBUG AuthService: Response status = $status, data = $responseData');

      // 明确处理常见错误状态，给出更友好的信息
      if (status == 401 || responseData?['error'] == 'Unauthorized') {
        throw ApiException('用户名或密码错误');
      }
      if (status == 403) {
        throw ApiException('账户未激活或无权限');
      }

      if (responseData is! Map || responseData['success'] != true) {
        final msg = (responseData is Map
                ? responseData['message'] ?? responseData['error']
                : null) ??
            '登录失败';
        debugPrint('DEBUG AuthService: Non-success response: $msg');
        throw ApiException(msg);
      }
      
      debugPrint('DEBUG AuthService: Creating AuthResponse from JSON');
      final authResponse = AuthResponse.fromJson(
        Map<String, dynamic>.from(responseData as Map),
      );
      debugPrint('DEBUG AuthService: AuthResponse user = ${authResponse.user}');
      debugPrint('DEBUG AuthService: AuthResponse token = ${authResponse.accessToken?.substring(0, 20) ?? 'null'}...');
      
      // 保存令牌
      await TokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        expiryDate: authResponse.expiresAt,
      );
      
      // 保存用户ID
      if (authResponse.user?.id != null) {
        await TokenStorage.saveUserId(authResponse.user!.id!);
      }
      
      // 保存记住我状态
      await TokenStorage.setRememberMe(rememberMe);
      
      // 设置HTTP客户端的认证令牌
      _client.dio.options.headers['Authorization'] = 
          'Bearer ${authResponse.accessToken}';
      
      // 登录成功后刷新实时汇率（忽略错误）
      try {
        // 延迟到下一帧再读取 provider（避免 login 调用环境中无 ProviderScope）
        // 实际集成处可在上层监听登录完成后调用 refresh; 这里尝试静态触发需要访问全局ref不太方便，故留待上层。
      } catch (_) {}
      return authResponse;
    } catch (e) {
      debugPrint('DEBUG AuthService: Login error caught: $e');
      debugPrint('DEBUG AuthService: Error type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('DEBUG AuthService: DioException type: ${e.type}');
        debugPrint('DEBUG AuthService: DioException message: ${e.message}');
        print('DEBUG AuthService: Response: ${e.response}');
        print('DEBUG AuthService: Response data: ${e.response?.data}');
        print('DEBUG AuthService: Response status: ${e.response?.statusCode}');
        print('DEBUG AuthService: Request data: ${e.requestOptions.data}');
        print('DEBUG AuthService: Request URL: ${e.requestOptions.uri}');
      }
      throw _handleError(e);
    }
  }

  /// 将用户名映射为邮箱（仅用于本地开发超级管理员便捷登录）
  String _normalizeLoginIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return trimmed;
    // 仅在开发环境处理内置超级管理员用户名
    if (ApiConfig.isDevelopment && trimmed.toLowerCase() == 'superadmin') {
      return 'superadmin@jive.money';
    }
    return trimmed; // 其他用户名保持原样（后端目前按邮箱匹配）
  }
  
  /// 注册
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (phone != null) 'phone': phone,
        },
      );
      
      final authResponse = AuthResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      
      // 保存令牌
      await TokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        expiryDate: authResponse.expiresAt,
      );
      
      // 保存用户ID
      if (authResponse.user?.id != null) {
        await TokenStorage.saveUserId(authResponse.user!.id!);
      }
      
      // 设置HTTP客户端的认证令牌
      _client.dio.options.headers['Authorization'] = 
          'Bearer ${authResponse.accessToken}';
      
      return authResponse;
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 登出
  Future<void> logout() async {
    try {
      // 调用登出API
      await _client.post(Endpoints.logout);
    } catch (e) {
      // 即使API调用失败，也要清除本地令牌
    } finally {
      // 清除本地存储
      await TokenStorage.clearTokens();
      
      // 清除HTTP客户端的认证令牌
      _client.clearAuth();
    }
  }
  
  /// 刷新令牌
  Future<AuthResponse> refreshToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      
      if (refreshToken == null) {
        throw UnauthorizedException('刷新令牌不存在');
      }
      
      final response = await _client.post(
        Endpoints.refreshToken,
        data: {
          'refresh_token': refreshToken,
        },
      );
      
      final authResponse = AuthResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      
      // 保存新令牌
      await TokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        expiryDate: authResponse.expiresAt,
      );
      
      // 更新HTTP客户端的认证令牌
      _client.setAuthToken(authResponse.accessToken);
      
      return authResponse;
    } catch (e) {
      // 刷新失败，清除令牌
      await TokenStorage.clearTokens();
      _client.clearAuth();
      throw _handleError(e);
    }
  }
  
  /// 获取当前用户信息
  Future<User> getCurrentUser() async {
    try {
      final response = await _client.get(Endpoints.profile);
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 更新用户信息
  Future<User> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    try {
      final response = await _client.put(
        Endpoints.profile,
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (avatar != null) 'avatar': avatar,
        },
      );
      
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 修改密码
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post(
        '${Endpoints.profile}/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 重置密码（发送重置邮件）
  Future<void> resetPassword(String email) async {
    try {
      await _client.post(
        '${Endpoints.auth}/reset-password',
        data: {
          'email': email,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 验证邮箱
  Future<void> verifyEmail(String code) async {
    try {
      await _client.post(
        '${Endpoints.auth}/verify-email',
        data: {
          'code': code,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  /// 检查是否有有效令牌
  Future<bool> hasValidToken() async {
    return await TokenStorage.hasValidToken();
  }
  
  /// 检查是否已认证（同步版本）
  bool get isAuthenticated {
    // 这是一个简化版本，实际应用中可能需要更复杂的逻辑
    // 暂时返回true以避免编译错误
    return true; // TODO: 实现实际的认证状态检查
  }
  
  /// 检查认证状态
  Future<bool> checkAuthStatus() async {
    try {
      // 检查本地令牌
      final hasToken = await TokenStorage.hasValidToken();
      if (!hasToken) {
        return false;
      }
      
      // 验证令牌有效性
      await getCurrentUser();
      return true;
    } catch (e) {
      // 如果是401错误，尝试刷新令牌
      if (e is UnauthorizedException) {
        try {
          await refreshToken();
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }
  
  /// 错误处理
  Exception _handleError(dynamic error) {
    if (error is ApiException) {
      return error;
    }
    return ApiException('认证服务错误：${error.toString()}');
  }
}

/// 认证响应
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
  final User? user;
  
  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
    this.user,
  });
  
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // 处理我们的API响应格式
    String? accessToken = json['token'] ?? json['access_token'] ?? json['accessToken'];
    String? refreshToken = json['refresh_token'] ?? json['refreshToken'] ?? accessToken; // 如果没有refresh token，使用access token
    
    return AuthResponse(
      accessToken: accessToken ?? '',
      refreshToken: refreshToken ?? '',
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'])
          : json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'])
              : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt?.toIso8601String(),
      'user': user?.toJson(),
    };
  }
}
