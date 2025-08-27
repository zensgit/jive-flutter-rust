import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// 重试拦截器
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;
  
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
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
    
    // 获取重试次数
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    
    if (retryCount >= maxRetries) {
      handler.next(err);
      return;
    }
    
    // 计算延迟时间（指数退避）
    final delay = Duration(
      milliseconds: (retryDelay.inMilliseconds * (retryCount + 1)).toInt(),
    );
    
    // 等待一段时间后重试
    await Future.delayed(delay);
    
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
      
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
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
}