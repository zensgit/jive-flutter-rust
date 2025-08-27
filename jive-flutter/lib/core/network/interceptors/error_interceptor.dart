import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// 错误拦截器
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 记录错误日志
    _logError(err);
    
    // 处理特定错误
    final error = _transformError(err);
    
    handler.next(error);
  }
  
  /// 记录错误日志
  void _logError(DioException err) {
    final request = err.requestOptions;
    final response = err.response;
    
    AppLogger.error('''
    ==================== API Error ====================
    URL: ${request.method} ${request.uri}
    Headers: ${request.headers}
    Data: ${request.data}
    Query: ${request.queryParameters}
    
    Error Type: ${err.type}
    Error Message: ${err.message}
    
    Response Status: ${response?.statusCode}
    Response Data: ${response?.data}
    ===================================================
    ''');
  }
  
  /// 转换错误信息
  DioException _transformError(DioException err) {
    String message = err.message ?? '未知错误';
    
    // 根据错误类型自定义错误信息
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        message = '连接超时，请检查网络连接';
        break;
      case DioExceptionType.sendTimeout:
        message = '发送超时，请稍后重试';
        break;
      case DioExceptionType.receiveTimeout:
        message = '接收超时，请稍后重试';
        break;
      case DioExceptionType.badResponse:
        message = _getResponseErrorMessage(err.response);
        break;
      case DioExceptionType.cancel:
        message = '请求已取消';
        break;
      case DioExceptionType.connectionError:
        message = '网络连接错误，请检查网络设置';
        break;
      case DioExceptionType.badCertificate:
        message = '证书验证失败';
        break;
      case DioExceptionType.unknown:
      default:
        if (err.error.toString().contains('SocketException')) {
          message = '网络连接失败，请检查网络';
        } else if (err.error.toString().contains('HttpException')) {
          message = '网络请求失败';
        }
        break;
    }
    
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      message: message,
    );
  }
  
  /// 获取响应错误信息
  String _getResponseErrorMessage(Response? response) {
    if (response == null) {
      return '服务器无响应';
    }
    
    final data = response.data;
    String message = '请求失败';
    
    // 尝试从响应中提取错误信息
    if (data is Map<String, dynamic>) {
      // 优先使用message字段
      if (data.containsKey('message')) {
        message = data['message'];
      }
      // 其次使用error字段
      else if (data.containsKey('error')) {
        message = data['error'];
      }
      // 如果有errors字段（验证错误）
      else if (data.containsKey('errors')) {
        final errors = data['errors'];
        if (errors is Map) {
          // 获取第一个错误信息
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          } else {
            message = firstError.toString();
          }
        } else if (errors is List && errors.isNotEmpty) {
          message = errors.first.toString();
        }
      }
    } else if (data is String) {
      message = data;
    }
    
    // 添加状态码信息
    final statusCode = response.statusCode ?? 0;
    switch (statusCode) {
      case 400:
        message = '请求参数错误：$message';
        break;
      case 401:
        message = '未授权，请重新登录';
        break;
      case 403:
        message = '无权限访问该资源';
        break;
      case 404:
        message = '请求的资源不存在';
        break;
      case 422:
        message = '数据验证失败：$message';
        break;
      case 429:
        message = '请求过于频繁，请稍后重试';
        break;
      case 500:
        message = '服务器内部错误';
        break;
      case 502:
        message = '网关错误';
        break;
      case 503:
        message = '服务暂时不可用';
        break;
      case 504:
        message = '网关超时';
        break;
    }
    
    return message;
  }
}