import 'dart:async';
import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// 简单的 API 就绪探测器：启动阶段在首次关键请求前调用
class ApiReadiness {
  ApiReadiness._();

  static bool _ready = false;
  static DateTime? _firstAttempt;
  static int _attempts = 0;

  /// 最长等待时长
  static const Duration maxWait = Duration(seconds: 25);

  /// 轮询间隔（指数退避上限）
  static const Duration maxInterval = Duration(seconds: 3);

  /// 探测 /health，成功即标记 ready
  static Future<bool> ensureReady(Dio dio) async {
    if (_ready) return true;
    _firstAttempt ??= DateTime.now();

    while (true) {
      final elapsed = DateTime.now().difference(_firstAttempt!);
      if (elapsed > maxWait) {
        return false; // 放弃，交给 UI 提示
      }

      try {
        final resp = await dio.get('${ApiConfig.baseUrl}/health',
            options: Options(
                sendTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3)));
        if (resp.statusCode == 200) {
          _ready = true;
          return true;
        }
      } catch (_) {
        // ignore
      }

      _attempts++;
      final backoffMs =
          (400 * (_attempts + 1)).clamp(400, maxInterval.inMilliseconds);
      await Future.delayed(Duration(milliseconds: backoffMs));
    }
  }
}
