import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/category_template.dart';
import '../../models/category.dart' as models;
export '../../models/category.dart' show CategoryClassification;
import '../cache/cache_manager.dart';
import '../../utils/logger.dart';

/// 简化版网络分类服务 - 不依赖connectivity_plus
class NetworkCategoryService {
  static const String _baseUrl = 'http://127.0.0.1:8080';
  static const String _cdnUrl = 'http://127.0.0.1:8080/static';

  // 缓存时长
  static const Duration _loggedInCacheDuration = Duration(minutes: 30);
  static const Duration _guestCacheDuration = Duration(hours: 2);
  static const Duration _iconCacheDuration = Duration(days: 7);

  // 缓存键
  static const String _keyTemplates = 'network_templates';
  static const String _keyIcons = 'network_icons';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyVersion = 'template_version';

  final Dio _dio;
  final CacheManager _cacheManager;
  final Logger _logger;

  // 单例模式
  static NetworkCategoryService? _instance;
  factory NetworkCategoryService() {
    _instance ??= NetworkCategoryService._internal();
    return _instance!;
  }

  NetworkCategoryService._internal()
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'JiveMoney/1.0',
          },
        )),
        _cacheManager = CacheManager(),
        _logger = Logger('NetworkCategoryService') {
    _setupInterceptors();
  }

  /// 设置拦截器
  void _setupInterceptors() {
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (log) => _logger.debug(log.toString()),
    ));

    // 重试拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 503 ||
            error.type == DioExceptionType.connectionTimeout) {
          _logger.warning('Local server connection failed, retrying...');
          // 简单重试逻辑
          return handler.next(error);
        }
        return handler.next(error);
      },
    ));
  }

  /// 获取系统模板列表
  Future<List<SystemCategoryTemplate>> getTemplates({
    bool forceRefresh = false,
    String? language,
    models.CategoryClassification? classification,
    CategoryGroup? group,
    bool? featuredOnly,
  }) async {
    try {
      // 检查是否需要刷新
      if (!forceRefresh && !_shouldRefresh()) {
        final cached = await _getCachedTemplates();
        if (cached != null && cached.isNotEmpty) {
          _logger.info('Using cached templates: ${cached.length} items');
          return cached;
        }
      }

      // 发起网络请求
      _logger.info('Fetching templates from network...');
      final response = await _dio.get(
        '/api/v1/templates/list',
        queryParameters: {
          if (language != null) 'lang': language,
          if (classification != null)
            'type': _classificationToString(classification),
          if (group != null) 'group': group.key,
          if (featuredOnly != null) 'featured': featuredOnly,
        },
      );

      // 解析响应
      final List<dynamic> data = response.data['templates'] ?? [];
      final templates = data
          .map((json) =>
              SystemCategoryTemplate.fromJson(json as Map<String, dynamic>))
          .toList();

      // 保存到缓存
      await _saveTemplatesToCache(templates);
      await _updateLastSyncTime();

      _logger.info('Successfully fetched ${templates.length} templates');
      return templates;
    } catch (e) {
      _logger.error('Failed to fetch templates: $e');

      // 降级到缓存数据
      final cached = await _getCachedTemplates();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      // 最终降级到本地预设
      return _getLocalTemplates();
    }
  }

  /// 获取图标列表
  Future<Map<String, String>> getIconUrls({
    bool forceRefresh = false,
  }) async {
    try {
      // 检查缓存
      if (!forceRefresh) {
        final cached = await _getCachedIcons();
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
      }

      // 网络请求
      final response = await _dio.get('/api/v1/icons/list');
      final Map<String, dynamic> data = response.data['icons'] ?? {};

      // 转换为图标URL映射
      final Map<String, String> iconUrls = {};
      data.forEach((key, value) {
        iconUrls[key] = '$_cdnUrl/icons/$value';
      });

      // 保存到缓存
      await _saveIconsToCache(iconUrls);

      return iconUrls;
    } catch (e) {
      _logger.error('Failed to fetch icons: $e');

      // 使用缓存或默认图标
      final cached = await _getCachedIcons();
      return cached ?? _getDefaultIconUrls();
    }
  }

  /// 提交用户分类统计
  Future<void> submitUsageStats(String templateId) async {
    try {
      // 异步提交，不影响用户操作
      _dio.post(
        '/api/v1/templates/usage',
        data: {
          'template_id': templateId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ).catchError((e) {
        // 静默失败
        _logger.debug('Failed to submit usage stats: $e');
      });
    } catch (e) {
      // 忽略错误
    }
  }

  // ========== 私有方法 ==========

  /// 检查是否需要刷新
  bool _shouldRefresh() {
    final lastSync = _cacheManager.getDateTime(_keyLastSync);
    if (lastSync == null) return true;

    final isLoggedIn = _isUserLoggedIn();
    final cacheDuration =
        isLoggedIn ? _loggedInCacheDuration : _guestCacheDuration;

    return DateTime.now().difference(lastSync) > cacheDuration;
  }

  /// 获取缓存的模板
  Future<List<SystemCategoryTemplate>?> _getCachedTemplates() async {
    try {
      final json = _cacheManager.getString(_keyTemplates);
      if (json == null) return null;

      final List<dynamic> data = jsonDecode(json);
      return data.map((item) => SystemCategoryTemplate.fromJson(item)).toList();
    } catch (e) {
      _logger.error('Failed to load cached templates: $e');
      return null;
    }
  }

  /// 保存模板到缓存
  Future<void> _saveTemplatesToCache(
      List<SystemCategoryTemplate> templates) async {
    try {
      final json = jsonEncode(templates.map((t) => t.toJson()).toList());
      await _cacheManager.setString(_keyTemplates, json);
    } catch (e) {
      _logger.error('Failed to save templates to cache: $e');
    }
  }

  /// 获取缓存的图标
  Future<Map<String, String>?> _getCachedIcons() async {
    try {
      final json = _cacheManager.getString(_keyIcons);
      if (json == null) return null;

      final Map<String, dynamic> data = jsonDecode(json);
      return data.cast<String, String>();
    } catch (e) {
      _logger.error('Failed to load cached icons: $e');
      return null;
    }
  }

  /// 保存图标到缓存
  Future<void> _saveIconsToCache(Map<String, String> icons) async {
    try {
      final json = jsonEncode(icons);
      await _cacheManager.setString(_keyIcons, json);
    } catch (e) {
      _logger.error('Failed to save icons to cache: $e');
    }
  }

  /// 更新同步时间
  Future<void> _updateLastSyncTime() async {
    await _cacheManager.setDateTime(_keyLastSync, DateTime.now());
  }

  /// 获取本地预设模板
  List<SystemCategoryTemplate> _getLocalTemplates() {
    return CategoryTemplateLibrary.getDefaultTemplates();
  }

  /// 获取默认图标URL
  Map<String, String> _getDefaultIconUrls() {
    return {
      '💰': '$_cdnUrl/icons/salary.png',
      '🍽️': '$_cdnUrl/icons/food.png',
      '🚗': '$_cdnUrl/icons/transport.png',
      '🛒': '$_cdnUrl/icons/shopping.png',
      '🎬': '$_cdnUrl/icons/entertainment.png',
      '🏥': '$_cdnUrl/icons/health.png',
      '📚': '$_cdnUrl/icons/education.png',
      '💼': '$_cdnUrl/icons/finance.png',
    };
  }

  /// 检查用户是否登录
  bool _isUserLoggedIn() {
    // TODO: 实现实际的登录状态检查
    return true;
  }

  /// 分类类型转字符串
  String _classificationToString(models.CategoryClassification classification) {
    switch (classification) {
      case models.CategoryClassification.income:
        return 'income';
      case models.CategoryClassification.expense:
        return 'expense';
      case models.CategoryClassification.transfer:
        return 'transfer';
    }
  }
}
