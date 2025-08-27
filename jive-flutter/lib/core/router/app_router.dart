// 应用路由配置
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/transactions/transactions_screen.dart';
import '../../screens/accounts/accounts_screen.dart';
import '../../screens/budgets/budgets_screen.dart';
import '../../screens/settings/settings_screen.dart';

/// 路由路径常量
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const transactionDetail = '/transactions/:id';
  static const transactionAdd = '/transactions/add';
  static const accounts = '/accounts';
  static const accountDetail = '/accounts/:id';
  static const accountAdd = '/accounts/add';
  static const budgets = '/budgets';
  static const budgetDetail = '/budgets/:id';
  static const budgetAdd = '/budgets/add';
  static const settings = '/settings';
  static const profile = '/settings/profile';
  static const security = '/settings/security';
  static const preferences = '/settings/preferences';
}

/// 路由Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final currentPath = state.uri.path;
      final isAuthRoute = currentPath == AppRoutes.login || 
                         currentPath == AppRoutes.register;
      
      // 如果未认证且不在认证页面，重定向到登录页
      if (!isAuthenticated && !isAuthRoute && currentPath != AppRoutes.splash) {
        return AppRoutes.login;
      }
      
      // 如果已认证且在认证页面，重定向到主页
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }
      
      return null;
    },
    routes: [
      // 启动页
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      
      // 认证相关
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // 主页（带底部导航）
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          // 仪表板
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          
          // 交易
          GoRoute(
            path: AppRoutes.transactions,
            builder: (context, state) => const TransactionsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const TransactionAddScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return TransactionDetailScreen(transactionId: id);
                },
              ),
            ],
          ),
          
          // 账户
          GoRoute(
            path: AppRoutes.accounts,
            builder: (context, state) => const AccountsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AccountAddScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return AccountDetailScreen(accountId: id);
                },
              ),
            ],
          ),
          
          // 预算
          GoRoute(
            path: AppRoutes.budgets,
            builder: (context, state) => const BudgetsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const BudgetAddScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return BudgetDetailScreen(budgetId: id);
                },
              ),
            ],
          ),
          
          // 设置
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'security',
                builder: (context, state) => const SecurityScreen(),
              ),
              GoRoute(
                path: 'preferences',
                builder: (context, state) => const PreferencesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    
    // 错误页面
    errorBuilder: (context, state) => ErrorPage(error: state.error),
  );
});

/// 认证状态监听器
class _AuthStateNotifier extends ChangeNotifier {
  final Ref _ref;
  
  _AuthStateNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// 错误页面
class ErrorPage extends StatelessWidget {
  final Exception? error;
  
  const ErrorPage({super.key, this.error});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错误')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              '页面加载失败',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '未知错误',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}

// 占位屏幕（用于尚未实现的页面）
class TransactionAddScreen extends StatelessWidget {
  const TransactionAddScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('添加交易')));
  }
}

class TransactionDetailScreen extends StatelessWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('交易详情: $transactionId')));
  }
}

class AccountAddScreen extends StatelessWidget {
  const AccountAddScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('添加账户')));
  }
}

class AccountDetailScreen extends StatelessWidget {
  final String accountId;
  const AccountDetailScreen({super.key, required this.accountId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('账户详情: $accountId')));
  }
}

class BudgetAddScreen extends StatelessWidget {
  const BudgetAddScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('添加预算')));
  }
}

class BudgetDetailScreen extends StatelessWidget {
  final String budgetId;
  const BudgetDetailScreen({super.key, required this.budgetId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('预算详情: $budgetId')));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('个人资料')));
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('安全设置')));
  }
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('偏好设置')));
  }
}