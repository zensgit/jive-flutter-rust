import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/category.dart' as models;
export '../../models/category.dart' show CategoryClassification;
import '../../models/category_template.dart';
import '../network/network_category_service_simple.dart';
import '../cache/cache_manager.dart';
import '../../utils/logger.dart';

/// 简化版集成分类服务
class CategoryServiceIntegrated extends ChangeNotifier {
  final NetworkCategoryService _networkService;
  final CacheManager _cacheManager;
  final Logger _logger;

  // 数据存储
  List<models.Category> _userCategories = [];
  List<SystemCategoryTemplate> _systemTemplates = [];
  Map<String, String> _iconUrls = {};

  // 状态标志
  bool _isLoading = false;
  bool _hasNetworkData = false;
  String? _error;
  DateTime? _lastSync;

  // 单例模式
  static CategoryServiceIntegrated? _instance;
  factory CategoryServiceIntegrated() {
    _instance ??= CategoryServiceIntegrated._internal();
    return _instance!;
  }

  CategoryServiceIntegrated._internal()
      : _networkService = NetworkCategoryService(),
        _cacheManager = CacheManager(),
        _logger = Logger('CategoryServiceIntegrated') {
    _initialize();
  }

  // ========== Getters ==========

  List<models.Category> get userCategories => _userCategories;
  List<SystemCategoryTemplate> get systemTemplates => _systemTemplates;
  Map<String, String> get iconUrls => _iconUrls;
  bool get isLoading => _isLoading;
  bool get hasNetworkData => _hasNetworkData;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;

  // ========== 初始化 ==========

  Future<void> _initialize() async {
    // 1. 加载本地缓存数据
    await _loadLocalData();

    // 2. 后台同步网络数据
    _syncInBackground();
  }

  /// 加载本地数据
  Future<void> _loadLocalData() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 加载用户分类
      _userCategories = await _loadUserCategoriesFromCache();

      // 加载系统模板（优先缓存）
      _systemTemplates = await _loadTemplatesFromCache();
      if (_systemTemplates.isEmpty) {
        // 使用内置模板
        _systemTemplates = _getBuiltInTemplates();
      }

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to load local data: $e');
      _error = '加载本地数据失败';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 后台同步网络数据
  Future<void> _syncInBackground() async {
    try {
      _logger.info('Starting background sync...');

      // 获取最新模板
      final networkTemplates = await _networkService.getTemplates();
      if (networkTemplates.isNotEmpty) {
        _mergeTemplates(networkTemplates);
        _hasNetworkData = true;
      }

      // 获取图标URL
      _iconUrls = await _networkService.getIconUrls();

      // 更新同步时间
      _lastSync = DateTime.now();
      await _cacheManager.setDateTime('last_sync', _lastSync!);

      _logger.info('Background sync completed');
      notifyListeners();
    } catch (e) {
      _logger.error('Background sync failed: $e');
      // 静默失败，不影响用户使用
    }
  }

  // ========== 公共方法 ==========

  /// 获取所有模板
  Future<List<SystemCategoryTemplate>> getAllTemplates({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh || _systemTemplates.isEmpty) {
      await refreshTemplates();
    }
    return _systemTemplates;
  }

  /// 按分类类型获取模板
  Future<List<SystemCategoryTemplate>> getTemplatesByClassification(
    models.CategoryClassification classification, {
    bool forceRefresh = false,
  }) async {
    final templates = await getAllTemplates(forceRefresh: forceRefresh);
    return templates.where((t) => t.classification == classification).toList();
  }

  /// 按分组获取模板
  Future<List<SystemCategoryTemplate>> getTemplatesByGroup(
    CategoryGroup group, {
    bool forceRefresh = false,
  }) async {
    final templates = await getAllTemplates(forceRefresh: forceRefresh);
    return templates.where((t) => t.categoryGroup == group).toList();
  }

  /// 获取精选模板
  Future<List<SystemCategoryTemplate>> getFeaturedTemplates({
    bool forceRefresh = false,
  }) async {
    final templates = await getAllTemplates(forceRefresh: forceRefresh);
    return templates.where((t) => t.isFeatured).toList();
  }

  /// 搜索模板
  Future<List<SystemCategoryTemplate>> searchTemplates(
    String query, {
    bool forceRefresh = false,
  }) async {
    final templates = await getAllTemplates(forceRefresh: forceRefresh);
    final queryLower = query.toLowerCase();

    return templates.where((t) {
      return t.name.toLowerCase().contains(queryLower) ||
          (t.nameEn?.toLowerCase().contains(queryLower) ?? false) ||
          t.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }

  /// 刷新模板（强制从网络加载）
  Future<void> refreshTemplates() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 从网络加载
      final templates = await _networkService.getTemplates(forceRefresh: true);
      if (templates.isNotEmpty) {
        _systemTemplates = templates;
        _hasNetworkData = true;
        await _saveTemplatesToCache(templates);
      }

      // 同时更新图标
      _iconUrls = await _networkService.getIconUrls(forceRefresh: true);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to refresh templates: $e');
      _error = '刷新失败，请检查网络连接';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从模板导入为用户分类
  Future<models.Category> importTemplateAsCategory(
    SystemCategoryTemplate template,
    String ledgerId,
  ) async {
    try {
      // 创建分类
      final category = models.Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: template.name,
        nameEn: template.nameEn,
        classification: template.classification,
        color: template.color,
        icon: template.icon ?? '',
        createdAt: DateTime.now(),
      );

      // 添加到用户分类
      _userCategories.add(category);
      await _saveUserCategoriesToCache();

      // 提交使用统计
      _networkService.submitUsageStats(template.id).catchError((e) {
        // 静默失败
        _logger.debug('Failed to submit usage stats: $e');
      });

      notifyListeners();
      return category;
    } catch (e) {
      _logger.error('Failed to import template: $e');
      throw Exception('导入模板失败');
    }
  }

  /// 创建用户分类
  Future<models.Category> createCategory(models.Category category) async {
    _userCategories.add(category);
    await _saveUserCategoriesToCache();
    notifyListeners();
    return category;
  }

  /// 更新用户分类
  Future<void> updateCategory(models.Category category) async {
    final index = _userCategories.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      _userCategories[index] = category;
      await _saveUserCategoriesToCache();
      notifyListeners();
    }
  }

  /// 删除用户分类
  Future<void> deleteCategory(String categoryId) async {
    _userCategories.removeWhere((c) => c.id == categoryId);
    await _saveUserCategoriesToCache();
    notifyListeners();
  }

  /// 获取用户分类
  List<models.Category> getUserCategories({
    String? ledgerId,
    models.CategoryClassification? classification,
  }) {
    return _userCategories.where((c) {
      if (ledgerId != null && c.ledgerId != ledgerId) return false;
      if (classification != null && c.classification != classification)
        return false;
      return true;
    }).toList();
  }

  // ========== 私有方法 ==========

  /// 合并网络模板和本地模板
  void _mergeTemplates(List<SystemCategoryTemplate> networkTemplates) {
    final Map<String, SystemCategoryTemplate> merged = {};

    // 先添加本地模板
    for (final template in _systemTemplates) {
      merged[template.id] = template;
    }

    // 覆盖或添加网络模板
    for (final template in networkTemplates) {
      merged[template.id] = template;
    }

    // 按热度排序
    _systemTemplates = merged.values.toList()
      ..sort((a, b) {
        // 精选优先
        if (a.isFeatured != b.isFeatured) {
          return a.isFeatured ? -1 : 1;
        }
        // 然后按使用量
        return b.globalUsageCount.compareTo(a.globalUsageCount);
      });
  }

  /// 加载用户分类缓存
  Future<List<models.Category>> _loadUserCategoriesFromCache() async {
    // TODO: 实现从缓存加载
    return [];
  }

  /// 保存用户分类到缓存
  Future<void> _saveUserCategoriesToCache() async {
    // TODO: 实现保存到缓存
  }

  /// 加载模板缓存
  Future<List<SystemCategoryTemplate>> _loadTemplatesFromCache() async {
    // TODO: 实现从缓存加载
    return [];
  }

  /// 保存模板到缓存
  Future<void> _saveTemplatesToCache(
      List<SystemCategoryTemplate> templates) async {
    // TODO: 实现保存到缓存
  }

  /// 获取内置模板
  List<SystemCategoryTemplate> _getBuiltInTemplates() {
    return CategoryTemplateLibrary.getDefaultTemplates();
  }
}
