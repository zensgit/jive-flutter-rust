import 'dart:convert';
import 'package:dio/dio.dart';
import '../../utils/logger.dart';

/// 日志拦截器
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestLog = '''
╔══════════════════════════ Request ══════════════════════════
║ URL: ${options.method} ${options.uri}
║ Headers: ${_formatHeaders(options.headers)}
║ Query Parameters: ${_formatJson(options.queryParameters)}
║ Request Data: ${_formatData(options.data)}
╚══════════════════════════════════════════════════════════════
    ''';
    
    AppLogger.debug(requestLog);
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final responseLog = '''
╔══════════════════════════ Response ══════════════════════════
║ URL: ${response.requestOptions.method} ${response.requestOptions.uri}
║ Status Code: ${response.statusCode}
║ Status Message: ${response.statusMessage}
║ Headers: ${_formatHeaders(response.headers.map)}
║ Response Data: ${_formatData(response.data)}
╚══════════════════════════════════════════════════════════════
    ''';
    
    AppLogger.debug(responseLog);
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final errorLog = '''
╔══════════════════════════ Error ══════════════════════════
║ URL: ${err.requestOptions.method} ${err.requestOptions.uri}
║ Error Type: ${err.type}
║ Error Message: ${err.message}
║ Status Code: ${err.response?.statusCode}
║ Response Data: ${_formatData(err.response?.data)}
╚══════════════════════════════════════════════════════════════
    ''';
    
    AppLogger.error(errorLog);
    handler.next(err);
  }
  
  /// 格式化Headers
  String _formatHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return '{}';
    
    // 隐藏敏感信息
    final sanitized = Map<String, dynamic>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      final auth = sanitized['Authorization'].toString();
      if (auth.length > 20) {
        sanitized['Authorization'] = '${auth.substring(0, 20)}...';
      }
    }
    
    return _formatJson(sanitized);
  }
  
  /// 格式化数据
  String _formatData(dynamic data) {
    if (data == null) return 'null';
    
    if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}: ${e.value}').join(', ');
      final files = data.files.map((e) => '${e.key}: ${e.value.filename}').join(', ');
      return 'FormData { fields: {$fields}, files: {$files} }';
    }
    
    if (data is String) {
      // 尝试解析JSON
      try {
        final json = jsonDecode(data);
        return _formatJson(json);
      } catch (_) {
        // 如果不是JSON，返回原始字符串
        return data.length > 1000 ? '${data.substring(0, 1000)}...' : data;
      }
    }
    
    if (data is Map || data is List) {
      return _formatJson(data);
    }
    
    return data.toString();
  }
  
  /// 格式化JSON
  String _formatJson(dynamic json) {
    if (json == null) return 'null';
    
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final formatted = encoder.convert(json);
      
      // 限制输出长度
      if (formatted.length > 2000) {
        return '${formatted.substring(0, 2000)}... [truncated]';
      }
      
      return formatted;
    } catch (e) {
      return json.toString();
    }
  }
}