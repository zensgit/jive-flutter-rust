import 'package:dio/dio.dart';
import 'package:jive_money/core/storage/token_storage.dart';
import 'package:jive_money/core/auth/auth_events.dart';
import 'package:jive_money/services/api/auth_service.dart';

/// 认证拦截器
class AuthInterceptor extends Interceptor {
  static DateTime? _lastRefreshAttempt;
  static const Duration _refreshBackoff = Duration(seconds: 5);
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 从存储中获取令牌
    final token = await TokenStorage.getAccessToken();

    // 调试日志：追踪令牌获取
    print('🔐 AuthInterceptor.onRequest - Path: ${options.path}');
    print('🔐 AuthInterceptor.onRequest - Token from storage: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');

    if (token != null && token.isNotEmpty) {
      // 添加认证头
      options.headers['Authorization'] = 'Bearer $token';
      print('🔐 AuthInterceptor.onRequest - Authorization header added');
    } else {
      print('⚠️ AuthInterceptor.onRequest - NO TOKEN AVAILABLE, request will fail if auth required');
    }

    // 添加其他必要的头部
    options.headers['X-Request-ID'] = _generateRequestId();
    options.headers['X-Timestamp'] = DateTime.now().toIso8601String();

    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 检查是否有新的令牌
    final newToken = response.headers.value('X-New-Token');
    if (newToken != null) {
      await TokenStorage.saveAccessToken(newToken);
    }

    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 如果是401错误，尝试刷新令牌
    if (err.response?.statusCode == 401) {
      final now = DateTime.now();
      if (_lastRefreshAttempt != null &&
          now.difference(_lastRefreshAttempt!) < _refreshBackoff) {
        handler.next(err);
        return;
      }
      _lastRefreshAttempt = now;
      final refreshed = await _refreshToken();

      if (refreshed) {
        // 重试原始请求
        try {
          final response = await _retry(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.reject(err);
          return;
        }
      }

      // 刷新失败，清除令牌并跳转到登录页
      await TokenStorage.clearTokens();
      // 通知应用需要跳转登录
      AuthEvents.notify(AuthEvent.unauthorized);
    }

    handler.next(err);
  }

  /// 刷新令牌
  Future<bool> _refreshToken() async {
    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return false;
      final authService = AuthService();
      final resp = await authService.refreshToken();
      return resp.accessToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 重试请求
  Future<Response> _retry(RequestOptions requestOptions) async {
    final token = await TokenStorage.getAccessToken();

    if (token != null) {
      requestOptions.headers['Authorization'] = 'Bearer $token';
    }

    final dio = Dio();
    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
      ),
    );
  }

  /// 生成请求ID
  String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';
  }

  /// 生成随机字符串
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) =>
          chars[(DateTime.now().millisecondsSinceEpoch + index) % chars.length],
    ).join();
  }
}
