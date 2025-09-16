import 'dart:async';

/// 简单的全局认证事件广播器，用于在拦截器检测到失效 Token 后通知 UI。
class AuthEvents {
  AuthEvents._();

  static final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  static Stream<AuthEvent> get stream => _controller.stream;

  static void notify(AuthEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
}

enum AuthEvent { unauthorized }
