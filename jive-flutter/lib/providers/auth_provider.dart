// 认证状态管理
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/auth_service.dart';
import '../core/storage/hive_config.dart';
import '../core/network/http_client.dart';
import '../models/user.dart';

/// 认证状态枚举
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// 认证状态
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  String? get error => errorMessage;
}

/// 认证控制器
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState()) {
    _checkAuthStatus();
  }

  /// 检查认证状态
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // 检查本地存储的用户信息
      final cachedUser = HiveConfig.getCurrentUser();
      if (cachedUser != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: cachedUser,
        );

        // 后台刷新用户信息
        _refreshUserInfo();
      } else {
        // 检查是否有有效的token
        final hasValidToken = await _authService.hasValidToken();
        if (hasValidToken) {
          await _refreshUserInfo();
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated);
        }
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新用户信息
  Future<void> _refreshUserInfo() async {
    try {
      final user = await _authService.getCurrentUser();
      await HiveConfig.saveUser(user);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      debugPrint('刷新用户信息失败: $e');
    }
  }

  /// 登录
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    debugPrint('DEBUG Provider: Login method called with email=$email');
    state = state.copyWith(status: AuthStatus.loading);

    try {
      debugPrint('DEBUG Provider: Starting login for $email');
      final authResponse = await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      debugPrint('DEBUG Provider: Got auth response');
      debugPrint('DEBUG Provider: User = ${authResponse.user}');
      debugPrint(
          'DEBUG Provider: Token = ${authResponse.accessToken?.substring(0, 20) ?? 'null'}...');

      // 保存用户信息
      if (authResponse.user != null) {
        await HiveConfig.saveUser(authResponse.user!);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: authResponse.user,
        );

        debugPrint(
            'DEBUG: Login successful in provider, user: ${authResponse.user?.email}');
        return true;
      } else {
        debugPrint('DEBUG: Login failed - no user in response');
        debugPrint(
            'DEBUG: Auth response: token=${authResponse.accessToken?.substring(0, 20)}...');
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: '登录响应中缺少用户信息',
        );
        return false;
      }
    } catch (e, stack) {
      debugPrint('DEBUG Provider: Login exception: $e');
      debugPrint('DEBUG Provider: Stack: $stack');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  /// 注册
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final authResponse = await _authService.register(
        name: name,
        email: email,
        password: password,
      );

      // 保存用户信息
      if (authResponse.user != null) {
        await HiveConfig.saveUser(authResponse.user!);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: authResponse.user,
        );

        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: '注册响应中缺少用户信息',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseError(e),
      );
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authService.logout();
      await HiveConfig.clearAll();

      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('登出失败: $e');
      // 即使登出失败也清除本地数据
      await HiveConfig.clearAll();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 更新用户信息
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatar,
  }) async {
    if (state.user == null) return false;

    try {
      final updatedUser = await _authService.updateProfile(
        name: name,
        phone: phone,
        avatar: avatar,
      );

      await HiveConfig.saveUser(updatedUser);

      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
      return false;
    }
  }

  /// 修改密码
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
      return false;
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 解析错误信息
  String _parseError(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }
}

/// Provider定义
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService);
});

/// 当前用户Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user;
});

/// 是否已认证Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.status == AuthStatus.authenticated;
});

/// 为了兼容性，创建authProvider别名
final authProvider = authControllerProvider;
