import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  static DateTime? _lastGlobalFailure;
  static int _consecutiveFailures = 0;
  static bool _circuitOpen = false;
  static DateTime? _circuitOpenedAt;
  // 熔断持续时间
  final Duration circuitOpenDuration;
  // 达到多少连续失败开启熔断
  final int circuitFailureThreshold;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 2),
    this.circuitOpenDuration = const Duration(seconds: 8),
    this.circuitFailureThreshold = 8,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 判断是否应该重试
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    // 熔断状态下直接返回错误，避免风暴
    if (_circuitOpen) {
      final since = DateTime.now().difference(_circuitOpenedAt!);
      if (since < circuitOpenDuration) {
        handler.next(err);
        return;
      } else {
        // 熔断期结束，半开
        _circuitOpen = false;
        _consecutiveFailures = 0;
      }
    }

    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    if (retryCount >= maxRetries) {
      _recordFailure();
      handler.next(err);
      return;
    }

    final backoff = _calcBackoff(retryCount);
    await Future.delayed(backoff);

    try {
      // 更新重试次数
      err.requestOptions.extra['retryCount'] = retryCount + 1;

      // 重新发起请求
      final response = await dio.request(
        err.requestOptions.path,
        data: err.requestOptions.data,
        queryParameters: err.requestOptions.queryParameters,
        options: Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          extra: err.requestOptions.extra,
        ),
      );

      _recordSuccess();
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        _recordFailure();
        handler.next(e);
      } else {
        _recordFailure();
        handler.next(err);
      }
    }
  }

  /// 判断是否应该重试
  bool _shouldRetry(DioException err) {
    // 只重试特定类型的错误
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // 网络错误
    if (err.error is SocketException ||
        err.error is HttpException ||
        err.error is TimeoutException) {
      return true;
    }

    // 服务器错误（5xx）
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // 429 Too Many Requests
    if (statusCode == 429) {
      return true;
    }

    // 其他错误不重试
    return false;
  }

  Duration _calcBackoff(int retryCount) {
    final ms = (baseDelay.inMilliseconds * (1 << retryCount))
        .clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  void _recordFailure() {
    _lastGlobalFailure = DateTime.now();
    _consecutiveFailures++;
    if (_consecutiveFailures >= circuitFailureThreshold && !_circuitOpen) {
      _circuitOpen = true;
      _circuitOpenedAt = DateTime.now();
    }
  }

  void _recordSuccess() {
    _consecutiveFailures = 0;
    _circuitOpen = false;
  }
}
