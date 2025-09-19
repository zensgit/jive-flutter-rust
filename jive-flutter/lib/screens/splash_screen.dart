import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    try {
      // 等待认证状态初始化完成
      int maxWaitTime = 5000; // 最多等待5秒
      int waitTime = 0;
      const checkInterval = 100;

      while (waitTime < maxWaitTime) {
        final authState = ref.read(authControllerProvider);

        // 如果状态不是初始状态，说明已经初始化完成
        if (authState.status != AuthStatus.initial) {
          debugPrint(
              'Auth state in splash: ${authState.status}, user: ${authState.user?.name}');

          if (authState.isAuthenticated) {
            context.go(AppRoutes.dashboard);
          } else {
            context.go(AppRoutes.login);
          }
          return;
        }

        await Future.delayed(const Duration(milliseconds: checkInterval));
        waitTime += checkInterval;
      }

      // 超时后默认跳转到登录页
      debugPrint('Auth state check timeout, redirecting to login');
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('Auth check error: $e');
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 60,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Jive Money',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '智能财务管理',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
