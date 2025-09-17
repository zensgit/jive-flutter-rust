import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'api_readiness.dart';

/// HTTP客户端单例
class HttpClient {
  static HttpClient? _instance;
  late final Dio _dio;

  HttpClient._() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }

  static HttpClient get instance {
    _instance ??= HttpClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// 基础配置
  BaseOptions get _baseOptions => BaseOptions(
        baseUrl: ApiConfig.apiUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: ApiConfig.defaultHeaders,
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType, // 使用Dio的常量
        validateStatus: (status) => status! < 500,
      );

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.addAll([
      // 认证拦截器
      AuthInterceptor(),
      // 错误拦截器
      ErrorInterceptor(),
      // 重试拦截器
      RetryInterceptor(dio: _dio),
      // 日志拦截器（仅开发环境）
      if (ApiConfig.enableLogging) LoggingInterceptor(),
    ]);
  }

  /// GET请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      // 在首次关键 GET（排除 /health 自身）前确保 API 就绪
      if (!path.contains('health')) {
        await ApiReadiness.ensureReady(_dio);
      }
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      if (!path.contains('auth') && !path.contains('health')) {
        await ApiReadiness.ensureReady(_dio);
      }
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      if (!path.contains('auth')) {
        await ApiReadiness.ensureReady(_dio);
      }
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      if (!path.contains('auth')) {
        await ApiReadiness.ensureReady(_dio);
      }
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH请求
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 上传文件
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: formData,
        options: options ??
            Options(
              contentType: 'multipart/form-data',
            ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 下载文件
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
  }) async {
    try {
      final response = await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: options,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 错误处理
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return ApiException('连接超时，请检查网络');
      case DioExceptionType.sendTimeout:
        return ApiException('发送超时，请稍后重试');
      case DioExceptionType.receiveTimeout:
        return ApiException('接收超时，请稍后重试');
      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);
      case DioExceptionType.cancel:
        return ApiException('请求已取消');
      case DioExceptionType.connectionError:
        return ApiException('连接错误，请检查网络');
      case DioExceptionType.badCertificate:
        return ApiException('证书验证失败');
      case DioExceptionType.unknown:
      default:
        return ApiException('未知错误：${error.message}');
    }
  }

  /// 处理错误响应
  Exception _handleBadResponse(Response? response) {
    if (response == null) {
      return ApiException('无响应');
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    String message = '请求失败';

    // 尝试从响应中提取错误信息
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['error'] ?? message;
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(message);
      case 401:
        return UnauthorizedException('未授权，请重新登录');
      case 403:
        return ForbiddenException('无权限访问');
      case 404:
        return NotFoundException('资源未找到');
      case 422:
        return ValidationException(message, data['errors']);
      case 500:
        return ServerException('服务器错误');
      case 502:
        return ServerException('网关错误');
      case 503:
        return ServerException('服务不可用');
      default:
        return ApiException('请求失败：$message');
    }
  }

  /// 清除认证信息
  void clearAuth() {
    _dio.options.headers.remove('Authorization');
  }

  /// 设置认证令牌
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
}

/// API异常基类
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

/// 错误请求异常
class BadRequestException extends ApiException {
  BadRequestException(String message) : super(message, statusCode: 400);
}

/// 未授权异常
class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, statusCode: 401);
}

/// 禁止访问异常
class ForbiddenException extends ApiException {
  ForbiddenException(String message) : super(message, statusCode: 403);
}

/// 资源未找到异常
class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message, statusCode: 404);
}

/// 验证异常
class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  ValidationException(String message, this.errors)
      : super(message, statusCode: 422, data: errors);
}

/// 服务器异常
class ServerException extends ApiException {
  ServerException(String message) : super(message, statusCode: 500);
}
