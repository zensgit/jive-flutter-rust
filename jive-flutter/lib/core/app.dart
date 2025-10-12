import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../devtools/dev_quick_actions.dart';

import 'constants/app_constants.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'localization/app_localizations.dart';
import '../features/auth/providers/auth_provider.dart';
import 'storage/token_storage.dart';
import 'auth/auth_events.dart';
import '../features/settings/providers/settings_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/settings_provider.dart' as global_settings;

/// 主应用类
class JiveApp extends ConsumerStatefulWidget {
  final ProviderContainer? container;

  const JiveApp({super.key, this.container});

  @override
  ConsumerState<JiveApp> createState() => _JiveAppState();
}

class _JiveAppState extends ConsumerState<JiveApp> {
  @override
  void initState() {
    super.initState();
    // 在应用启动时自动更新汇率
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 延迟：等待路由/本地化就绪
    await Future.delayed(const Duration(milliseconds: 800));
    // 跳过未登录或 token 已过期场景下的自动请求，减少 401 噪音
    final token = await TokenStorage.getAccessToken();
    final expired = await TokenStorage.isTokenExpired();
    if (token == null || expired) {
      debugPrint(
          'ℹ️ Skip auto refresh (token ${token == null ? 'absent' : 'expired'})');
      return;
    }
    try {
      final settings = ref.read(global_settings.settingsProvider);
      final autoUpdateRates = settings.autoUpdateRates ?? true;
      if (autoUpdateRates && mounted) {
        debugPrint('@@ App.init -> refreshing exchange rates');
        await ref.read(currencyProvider.notifier).refreshExchangeRates();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update exchange rates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // 使用 MaterialApp.router 作为根，保持其提供的本地化 / 主题等
    final app = MaterialApp.router(
      // 应用基本信息
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // 路由配置
      routerConfig: router,

      // 主题配置
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // 国际化配置
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 构建器 - 添加文本缩放控制
      builder: (context, child) {
        debugPrint(
            '@@ App.builder start (has Directionality=${Directionality.maybeOf(context) != null})');

        // Ensure child is never null and has proper constraints
        final safeChild = child ?? const SizedBox.expand();

        // Wrap in a layout builder to ensure proper constraints
        return LayoutBuilder(
          builder: (context, constraints) {
            // Apply density and corner radius from settings
            final settings = ref.watch(settingsProvider);
            final isCompact = settings.listDensity == 'compact';
            final radius = settings.cornerRadius == 'small'
                ? 8.0
                : settings.cornerRadius == 'large'
                    ? 16.0
                    : 12.0;
            final mediaWrapped = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  MediaQuery.of(context).textScaler.scale(1.0).clamp(0.9, 1.15),
                ),
                padding: MediaQuery.of(context).padding,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  visualDensity: isCompact
                      ? const VisualDensity(horizontal: -2, vertical: -2)
                      : VisualDensity.adaptivePlatformDensity,
                  cardTheme: Theme.of(context).cardTheme.copyWith(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                  inputDecorationTheme:
                      Theme.of(context).inputDecorationTheme.copyWith(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(radius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(radius),
                              borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                  checkboxTheme: Theme.of(context).checkboxTheme.copyWith(
                        visualDensity: isCompact
                            ? const VisualDensity(horizontal: -2, vertical: -2)
                            : null,
                      ),
                  listTileTheme: Theme.of(context).listTileTheme.copyWith(
                        dense: isCompact,
                        contentPadding: isCompact
                            ? const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4)
                            : null,
                      ),
                ),
                child: safeChild,
              ),
            );
            // 将开发调试悬浮控件放入 MaterialApp 内部，确保 Directionality / Theme 等已就绪
            // 注意：SelectionArea 需要 Overlay 祖先，不能包裹在 MaterialApp.builder 外层
            // 已在错误页和关键位置提供可选文本/复制按钮
            return DevQuickActions(child: mediaWrapped);
          },
        );
      },
    );
    // 监听认证事件：未授权时跳转登录（假设路由有 /login）
    AuthEvents.stream.listen((event) {
      if (event == AuthEvent.unauthorized) {
        // 提示并跳转登录
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('登录已过期，请重新登录'), duration: Duration(seconds: 2)),
          );
        }
        router.go('/login');
      }
    });
    // DevQuickActions 已在 builder 内包裹，直接返回 app 即可
    return app;
  }
}

/// 主题模式提供器
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref),
);

/// 主题模式状态管理
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// 加载保存的主题模式
  Future<void> _loadThemeMode() async {
    final settings = _ref.read(settingsProvider);
    final savedTheme = await settings.getThemeMode();
    state = _parseThemeMode(savedTheme);
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final settings = _ref.read(settingsProvider);
    await settings.setThemeMode(_themeModeToString(mode));
  }

  /// 解析主题模式字符串
  ThemeMode _parseThemeMode(String? theme) {
    switch (theme) {
      case AppConstants.lightTheme:
        return ThemeMode.light;
      case AppConstants.darkTheme:
        return ThemeMode.dark;
      case AppConstants.systemTheme:
      default:
        return ThemeMode.system;
    }
  }

  /// 主题模式转换为字符串
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppConstants.lightTheme;
      case ThemeMode.dark:
        return AppConstants.darkTheme;
      case ThemeMode.system:
        return AppConstants.systemTheme;
    }
  }
}

/// 语言设置提供器
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(ref),
);

/// 语言设置状态管理
class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(const Locale('en')) {
    _loadLocale();
  }

  /// 加载保存的语言设置
  Future<void> _loadLocale() async {
    final settings = _ref.read(settingsProvider);
    final savedLanguage = await settings.getLanguage();
    if (savedLanguage != null &&
        AppConstants.supportedLanguages.contains(savedLanguage)) {
      state = Locale(savedLanguage);
    }
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    if (AppConstants.supportedLanguages.contains(locale.languageCode)) {
      state = locale;
      final settings = _ref.read(settingsProvider);
      await settings.setLanguage(locale.languageCode);
    }
  }
}

/// 应用状态提供器
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(ref),
);

/// 应用状态
enum AppState {
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// 应用状态管理
class AppStateNotifier extends StateNotifier<AppState> {
  final Ref _ref;

  AppStateNotifier(this._ref) : super(AppState.loading) {
    _init();
  }

  /// 初始化应用状态
  Future<void> _init() async {
    try {
      // 检查认证状态
      final authState = _ref.read(authProvider);

      if (authState.isAuthenticated) {
        state = AppState.authenticated;
      } else {
        state = AppState.unauthenticated;
      }
    } catch (error) {
      state = AppState.error;
    }
  }

  /// 设置认证状态
  void setAuthenticated() {
    state = AppState.authenticated;
  }

  /// 设置未认证状态
  void setUnauthenticated() {
    state = AppState.unauthenticated;
  }

  /// 设置错误状态
  void setError() {
    state = AppState.error;
  }

  /// 设置加载状态
  void setLoading() {
    state = AppState.loading;
  }
}
