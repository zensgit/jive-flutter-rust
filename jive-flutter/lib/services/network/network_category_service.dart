import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/category_template.dart';
import '../../models/category.dart';
import '../cache/cache_manager.dart';
import '../../utils/logger.dart';

/// 网络分类服务 - 从服务器动态加载分类模板
///
/// 借鉴钱记APP的网络加载机制，实现动态分类管理
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
          // 本地测试环境，不需要备用域名
          _logger.warning('Local server connection failed, retrying...');
          final options = error.requestOptions;
          final response = await _dio.request(
            options.path,
            options: Options(
              method: options.method,
              headers: options.headers,
            ),
            data: options.data,
            queryParameters: options.queryParameters,
          );
          return handler.resolve(response);
        }
        return handler.next(error);
      },
    ));
  }

  /// 获取系统模板列表
  Future<List<SystemCategoryTemplate>> getTemplates({
    bool forceRefresh = false,
    String? language,
    CategoryClassification? classification,
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

      // 检查网络连接
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        _logger.warning('No network connection, using local templates');
        return _getLocalTemplates();
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
          .map((json) => SystemCategoryTemplate.fromNetworkJson(json))
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

  /// 增量同步
  Future<void> incrementalSync() async {
    try {
      final lastSync = await _getLastSyncTime();
      if (lastSync == null) {
        // 首次同步，执行完整同步
        await fullSync();
        return;
      }

      // 获取更新
      final response = await _dio.get(
        '/api/v1/templates/updates',
        queryParameters: {
          'since': lastSync.toIso8601String(),
        },
      );

      final List<dynamic> updates = response.data['updates'] ?? [];
      if (updates.isEmpty) {
        _logger.info('No updates available');
        return;
      }

      // 应用更新
      await _applyUpdates(updates);
      await _updateLastSyncTime();

      _logger.info('Applied ${updates.length} template updates');
    } catch (e) {
      _logger.error('Incremental sync failed: $e');
    }
  }

  /// 完整同步
  Future<void> fullSync() async {
    try {
      // WiFi环境下执行
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.wifi) {
        _logger.info('Skipping full sync - not on WiFi');
        return;
      }

      // 获取所有模板
      final templates = await getTemplates(forceRefresh: true);

      // 获取所有图标
      final icons = await getIconUrls(forceRefresh: true);

      // 预加载热门图标
      await _preloadPopularIcons(templates, icons);

      _logger.info('Full sync completed: ${templates.length} templates');
    } catch (e) {
      _logger.error('Full sync failed: $e');
    }
  }

  /// 智能同步（根据网络状态）
  Future<void> smartSync() async {
    final connectivity = await Connectivity().checkConnectivity();

    switch (connectivity) {
      case ConnectivityResult.wifi:
        // WiFi下执行完整同步
        await fullSync();
        break;
      case ConnectivityResult.mobile:
        // 移动网络只做增量同步
        await incrementalSync();
        break;
      case ConnectivityResult.none:
        // 无网络，跳过同步
        _logger.info('No network, skipping sync');
        break;
      default:
        break;
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

  /// 获取上次同步时间
  Future<DateTime?> _getLastSyncTime() async {
    return _cacheManager.getDateTime(_keyLastSync);
  }

  /// 更新同步时间
  Future<void> _updateLastSyncTime() async {
    await _cacheManager.setDateTime(_keyLastSync, DateTime.now());
  }

  /// 应用更新
  Future<void> _applyUpdates(List<dynamic> updates) async {
    final cached = await _getCachedTemplates() ?? [];
    final Map<String, SystemCategoryTemplate> templateMap = {
      for (var t in cached) t.id: t
    };

    for (final update in updates) {
      final String action = update['action'];
      final String templateId = update['template_id'];

      switch (action) {
        case 'add':
        case 'update':
          final template =
              SystemCategoryTemplate.fromNetworkJson(update['template']);
          templateMap[templateId] = template;
          break;
        case 'delete':
          templateMap.remove(templateId);
          break;
      }
    }

    await _saveTemplatesToCache(templateMap.values.toList());
  }

  /// 预加载热门图标
  Future<void> _preloadPopularIcons(
    List<SystemCategoryTemplate> templates,
    Map<String, String> iconUrls,
  ) async {
    // 获取前20个最热门的模板图标
    final popularTemplates = templates.where((t) => t.isFeatured).take(20);

    for (final template in popularTemplates) {
      if (template.icon != null && iconUrls.containsKey(template.icon)) {
        // 预加载图标（实际实现需要图片缓存库）
        _logger.debug('Preloading icon: ${template.icon}');
      }
    }
  }

  /// 获取本地预设模板
  List<SystemCategoryTemplate> _getLocalTemplates() {
    // 返回本地内置的模板
    return SystemCategoryTemplate.getDefaultTemplates();
  }

  /// 获取默认图标URL
  Map<String, String> _getDefaultIconUrls() {
    return {
      'salary': '$_cdnUrl/icons/salary.png',
      'food': '$_cdnUrl/icons/food.png',
      'transport': '$_cdnUrl/icons/transport.png',
      'shopping': '$_cdnUrl/icons/shopping.png',
      'entertainment': '$_cdnUrl/icons/entertainment.png',
      'health': '$_cdnUrl/icons/health.png',
      'education': '$_cdnUrl/icons/education.png',
      'finance': '$_cdnUrl/icons/finance.png',
      // ... 更多默认图标
    };
  }

  /// 检查用户是否登录
  bool _isUserLoggedIn() {
    // TODO: 实现实际的登录状态检查
    return true;
  }

  /// 分类类型转字符串
  String _classificationToString(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return 'income';
      case CategoryClassification.expense:
        return 'expense';
      case CategoryClassification.transfer:
        return 'transfer';
    }
  }
}

/// 网络模板扩展
extension NetworkTemplateExtension on SystemCategoryTemplate {
  /// 从网络JSON创建模板
  static SystemCategoryTemplate fromNetworkJson(Map<String, dynamic> json) {
    return SystemCategoryTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameEn: json['name_en'],
      nameZh: json['name_zh'],
      description: json['description'],
      classification: _parseClassification(json['classification']),
      color: json['color'] ?? '#6B7280',
      icon: json['icon'],
      categoryGroup: _parseGroup(json['group']),
      isFeatured: json['is_featured'] ?? false,
      isActive: json['is_active'] ?? true,
      tags: List<String>.from(json['tags'] ?? []),
      globalUsageCount: json['popularity'] ?? 0,
      version: json['version'] ?? '1.0.0',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  static CategoryClassification _parseClassification(String? value) {
    switch (value) {
      case 'income':
        return CategoryClassification.income;
      case 'expense':
        return CategoryClassification.expense;
      case 'transfer':
        return CategoryClassification.transfer;
      default:
        return CategoryClassification.expense;
    }
  }

  static CategoryGroup _parseGroup(String? value) {
    return CategoryGroup.fromString(value ?? 'other') ?? CategoryGroup.other;
  }

  /// 获取默认模板（离线使用）
  static List<SystemCategoryTemplate> getDefaultTemplates() {
    // 返回内置的基础模板
    return [
      SystemCategoryTemplate(
        id: 'local_salary',
        name: '工资收入',
        nameEn: 'Salary',
        classification: CategoryClassification.income,
        color: '#10B981',
        icon: '💰',
        categoryGroup: CategoryGroup.income,
        isFeatured: true,
        tags: ['必备', '常用'],
      ),
      SystemCategoryTemplate(
        id: 'local_food',
        name: '餐饮美食',
        nameEn: 'Food & Dining',
        classification: CategoryClassification.expense,
        color: '#EF4444',
        icon: '🍽️',
        categoryGroup: CategoryGroup.dailyExpense,
        isFeatured: true,
        tags: ['热门', '必备'],
      ),
      // ... 更多基础模板
    ];
  }
}
