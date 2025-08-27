import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/storage/hive_config.dart';
import '../sync/sync_service.dart';
import '../api/auth_service.dart';

/// 应用初始化服务
class AppInitializationService {
  static final AppInitializationService instance = AppInitializationService._();
  AppInitializationService._();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  final List<String> _initializationSteps = [];
  List<String> get initializationSteps => _initializationSteps;
  
  /// 初始化应用
  Future<void> initialize({
    Function(String step)? onProgress,
  }) async {
    if (_isInitialized) return;
    
    try {
      _updateProgress('正在初始化存储系统...', onProgress);
      await _initializeStorage();
      
      _updateProgress('正在检查网络连接...', onProgress);
      await _checkConnectivity();
      
      _updateProgress('正在初始化同步服务...', onProgress);
      await _initializeSyncService();
      
      _updateProgress('正在检查用户认证...', onProgress);
      await _checkAuthentication();
      
      _updateProgress('正在预加载数据...', onProgress);
      await _preloadData();
      
      _updateProgress('正在配置应用设置...', onProgress);
      await _configureApp();
      
      _updateProgress('初始化完成', onProgress);
      _isInitialized = true;
    } catch (e) {
      debugPrint('应用初始化失败: $e');
      rethrow;
    }
  }
  
  /// 初始化存储系统
  Future<void> _initializeStorage() async {
    try {
      await HiveConfig.init();
      debugPrint('存储系统初始化完成');
    } catch (e) {
      debugPrint('存储系统初始化失败: $e');
      throw AppInitializationException('存储系统初始化失败', e);
    }
  }
  
  /// 检查网络连接
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;
      
      if (isConnected) {
        debugPrint('网络连接正常');
      } else {
        debugPrint('当前离线，将使用离线模式');
      }
    } catch (e) {
      debugPrint('网络检查失败: $e');
      // 网络检查失败不应该阻止应用启动
    }
  }
  
  /// 初始化同步服务
  Future<void> _initializeSyncService() async {
    try {
      await SyncService.instance.init();
      debugPrint('同步服务初始化完成');
    } catch (e) {
      debugPrint('同步服务初始化失败: $e');
      // 同步服务失败不应该阻止应用启动
    }
  }
  
  /// 检查用户认证状态
  Future<void> _checkAuthentication() async {
    try {
      final authService = AuthService();
      final hasValidToken = await authService.hasValidToken();
      
      if (hasValidToken) {
        debugPrint('用户已认证');
        // 可以在这里预加载用户相关数据
      } else {
        debugPrint('用户未认证');
      }
    } catch (e) {
      debugPrint('认证检查失败: $e');
      // 认证检查失败不应该阻止应用启动
    }
  }
  
  /// 预加载数据
  Future<void> _preloadData() async {
    try {
      // 预加载基础数据，如分类、账户类型等
      await _preloadCategories();
      await _preloadSettings();
      
      debugPrint('数据预加载完成');
    } catch (e) {
      debugPrint('数据预加载失败: $e');
      // 预加载失败不应该阻止应用启动
    }
  }
  
  /// 预加载分类数据
  Future<void> _preloadCategories() async {
    try {
      // 检查是否已有缓存的分类数据
      final categoriesBox = HiveConfig.getCategoriesBox();
      if (categoriesBox.isEmpty) {
        // 如果没有缓存数据，可以创建默认分类
        await _createDefaultCategories();
      }
    } catch (e) {
      debugPrint('预加载分类失败: $e');
    }
  }
  
  /// 创建默认分类
  Future<void> _createDefaultCategories() async {
    try {
      final defaultCategories = _getDefaultCategories();
      final categoriesBox = HiveConfig.getCategoriesBox();
      
      for (final category in defaultCategories) {
        await categoriesBox.put(category.id, category);
      }
      
      debugPrint('创建默认分类完成');
    } catch (e) {
      debugPrint('创建默认分类失败: $e');
    }
  }
  
  /// 获取默认分类列表
  List<dynamic> _getDefaultCategories() {
    // 这里应该返回TransactionCategory对象的列表
    // 由于没有导入模型，暂时返回空列表
    return [];
  }
  
  /// 预加载应用设置
  Future<void> _preloadSettings() async {
    try {
      // 检查是否是首次启动
      final isFirstLaunch = HiveConfig.getSetting<bool>('is_first_launch') ?? true;
      if (isFirstLaunch) {
        await _handleFirstLaunch();
      }
      
      // 加载其他设置
      await _loadAppSettings();
      
      debugPrint('应用设置加载完成');
    } catch (e) {
      debugPrint('应用设置加载失败: $e');
    }
  }
  
  /// 处理首次启动
  Future<void> _handleFirstLaunch() async {
    try {
      // 设置默认配置
      await HiveConfig.saveSetting('theme_mode', 'system');
      await HiveConfig.saveSetting('language', 'zh_CN');
      await HiveConfig.saveSetting('currency', 'CNY');
      await HiveConfig.saveSetting('date_format', 'yyyy-MM-dd');
      
      // 标记已不是首次启动
      await HiveConfig.saveSetting('is_first_launch', false);
      
      debugPrint('首次启动设置完成');
    } catch (e) {
      debugPrint('首次启动设置失败: $e');
    }
  }
  
  /// 加载应用设置
  Future<void> _loadAppSettings() async {
    try {
      // 这里可以加载各种应用设置
      final themeMode = HiveConfig.getSetting<String>('theme_mode') ?? 'system';
      final language = HiveConfig.getSetting<String>('language') ?? 'zh_CN';
      final currency = HiveConfig.getSetting<String>('currency') ?? 'CNY';
      
      debugPrint('当前设置: 主题=$themeMode, 语言=$language, 货币=$currency');
    } catch (e) {
      debugPrint('加载应用设置失败: $e');
    }
  }
  
  /// 配置应用
  Future<void> _configureApp() async {
    try {
      // 设置系统UI样式
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      
      // 设置首选方向
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      debugPrint('应用配置完成');
    } catch (e) {
      debugPrint('应用配置失败: $e');
    }
  }
  
  /// 更新进度
  void _updateProgress(String step, Function(String step)? onProgress) {
    _initializationSteps.add(step);
    debugPrint('初始化: $step');
    onProgress?.call(step);
  }
  
  /// 清理资源
  Future<void> dispose() async {
    try {
      await SyncService.instance.dispose();
      await HiveConfig.closeAll();
      _isInitialized = false;
      debugPrint('应用资源清理完成');
    } catch (e) {
      debugPrint('应用资源清理失败: $e');
    }
  }
}

/// 应用初始化异常
class AppInitializationException implements Exception {
  final String message;
  final dynamic cause;
  
  AppInitializationException(this.message, [this.cause]);
  
  @override
  String toString() {
    if (cause != null) {
      return 'AppInitializationException: $message\nCaused by: $cause';
    }
    return 'AppInitializationException: $message';
  }
}