# Jive Money 网络分类加载系统设计

## 概述
基于钱记APP的网络分类加载机制，为Jive Money设计一个类似的动态分类管理系统，支持从服务器动态加载分类模板和图标资源。

## 架构设计

### 1. API端点设计

#### 主要API域名
```yaml
生产环境: https://api.jivemoney.app/
备用域名: https://api-backup.jivemoney.app/
CDN资源: https://cdn.jivemoney.app/
```

#### 分类相关API
```yaml
# 获取系统模板列表
GET /api/v1/templates/list
  参数:
    - lang: 语言 (zh/en)
    - type: 分类类型 (income/expense/transfer/all)
    - featured: 是否仅精选 (true/false)
    - group: 分类组 (可选)
  响应: SystemCategoryTemplate[]

# 获取用户自定义分类
GET /api/v1/categories/list
  参数:
    - ledger_id: 账本ID
    - type: 分类类型
    - include_stats: 包含统计信息
  响应: Category[]

# 获取图标集合
GET /api/v1/icons/list
  参数:
    - group: 图标组
    - version: 版本号
  响应: IconSet[]

# 获取分类更新
GET /api/v1/templates/updates
  参数:
    - last_sync: 上次同步时间戳
    - version: 当前版本
  响应: TemplateUpdate[]
```

### 2. 数据结构设计

```dart
// 网络模板响应
class NetworkTemplateResponse {
  final String version;
  final DateTime lastUpdated;
  final List<NetworkCategoryTemplate> templates;
  final Map<String, String> iconUrls;
  final Map<String, List<String>> groupedTemplates;
}

// 网络分类模板
class NetworkCategoryTemplate {
  final String id;
  final String name;
  final Map<String, String> localizedNames; // {"zh": "工资", "en": "Salary"}
  final String classification;
  final String color;
  final String iconUrl; // CDN URL
  final String iconName; // 本地图标名
  final String group;
  final bool isFeatured;
  final bool isActive;
  final List<String> tags;
  final int popularity; // 全球使用人数
  final DateTime createdAt;
  final DateTime updatedAt;
}

// 图标集合
class IconSet {
  final String group;
  final String version;
  final List<IconInfo> icons;
}

class IconInfo {
  final String name;
  final String url;
  final String emoji;
  final List<String> keywords;
  final String category;
}
```

### 3. 缓存策略

```dart
class CategoryCacheManager {
  static const Duration LOGGED_IN_CACHE = Duration(minutes: 30);
  static const Duration GUEST_CACHE = Duration(hours: 2);
  static const Duration ICON_CACHE = Duration(days: 7);
  
  // 缓存键
  static const String KEY_TEMPLATES = 'cached_templates';
  static const String KEY_ICONS = 'cached_icons';
  static const String KEY_LAST_SYNC = 'last_sync_time';
  static const String KEY_VERSION = 'template_version';
  
  // 检查是否需要更新
  bool shouldRefresh(bool isLoggedIn) {
    final lastSync = _getLastSyncTime();
    if (lastSync == null) return true;
    
    final cacheDuration = isLoggedIn ? LOGGED_IN_CACHE : GUEST_CACHE;
    return DateTime.now().difference(lastSync) > cacheDuration;
  }
  
  // 增量同步
  Future<void> incrementalSync() async {
    final lastSync = _getLastSyncTime();
    final updates = await _fetchUpdates(lastSync);
    await _applyUpdates(updates);
  }
}
```

### 4. 网络服务实现

```dart
class NetworkCategoryService {
  final String baseUrl;
  final Dio dio;
  final CategoryCacheManager cache;
  
  // 获取模板列表（带缓存）
  Future<List<SystemCategoryTemplate>> getTemplates({
    bool forceRefresh = false,
    String? language,
    AccountClassification? type,
  }) async {
    // 检查缓存
    if (!forceRefresh && !cache.shouldRefresh(isLoggedIn)) {
      final cached = await cache.getTemplates();
      if (cached != null) return cached;
    }
    
    // 网络请求
    try {
      final response = await dio.get('/api/v1/templates/list', 
        queryParameters: {
          'lang': language ?? _getCurrentLanguage(),
          'type': type?.toString() ?? 'all',
        },
      );
      
      final templates = _parseTemplates(response.data);
      await cache.saveTemplates(templates);
      return templates;
      
    } catch (e) {
      // 网络失败，返回缓存
      final cached = await cache.getTemplates();
      if (cached != null) return cached;
      
      // 无缓存，返回本地预设
      return _getLocalPresets();
    }
  }
  
  // 预加载图标
  Future<void> preloadIcons(List<String> iconUrls) async {
    for (final url in iconUrls) {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (e) {
        // 忽略单个图标加载失败
      }
    }
  }
  
  // 智能同步
  Future<void> smartSync() async {
    // 检查网络状态
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;
    
    // WiFi环境下进行完整同步
    if (connectivity == ConnectivityResult.wifi) {
      await fullSync();
    } else {
      // 移动网络只做增量同步
      await incrementalSync();
    }
  }
}
```

### 5. Flutter集成

```dart
// Provider状态管理
class CategoryTemplateProvider extends ChangeNotifier {
  final NetworkCategoryService _networkService;
  final LocalCategoryRepository _localRepo;
  
  List<SystemCategoryTemplate> _templates = [];
  bool _isLoading = false;
  bool _hasNetworkTemplates = false;
  
  // 初始化
  Future<void> initialize() async {
    // 先加载本地数据
    _templates = await _localRepo.getTemplates();
    notifyListeners();
    
    // 后台同步网络数据
    _syncInBackground();
  }
  
  // 后台同步
  Future<void> _syncInBackground() async {
    try {
      final networkTemplates = await _networkService.getTemplates();
      
      // 合并网络和本地数据
      _templates = _mergeTemplates(_templates, networkTemplates);
      _hasNetworkTemplates = true;
      notifyListeners();
      
    } catch (e) {
      // 静默失败，使用本地数据
    }
  }
  
  // 合并策略
  List<SystemCategoryTemplate> _mergeTemplates(
    List<SystemCategoryTemplate> local,
    List<SystemCategoryTemplate> network,
  ) {
    // 网络模板优先，但保留用户自定义的本地模板
    final Map<String, SystemCategoryTemplate> merged = {};
    
    // 添加本地模板
    for (final template in local) {
      merged[template.id] = template;
    }
    
    // 覆盖或添加网络模板
    for (final template in network) {
      merged[template.id] = template;
    }
    
    return merged.values.toList()
      ..sort((a, b) => b.popularity.compareTo(a.popularity));
  }
}
```

### 6. 图标加载优化

```dart
class IconLoader {
  static const Map<String, String> ICON_MAPPING = {
    '工资': 'salary',
    '餐饮': 'dining',
    '交通': 'transport',
    // ...
  };
  
  // 智能图标加载
  Widget buildIcon(String iconIdentifier, {double size = 24}) {
    // 1. 优先使用Emoji
    if (_isEmoji(iconIdentifier)) {
      return Text(iconIdentifier, style: TextStyle(fontSize: size));
    }
    
    // 2. 使用本地图标
    if (ICON_MAPPING.containsKey(iconIdentifier)) {
      return Icon(
        _getIconData(ICON_MAPPING[iconIdentifier]!),
        size: size,
      );
    }
    
    // 3. 加载网络图标
    if (iconIdentifier.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: iconIdentifier,
        width: size,
        height: size,
        placeholder: (context, url) => Icon(Icons.category, size: size),
        errorWidget: (context, url, error) => Icon(Icons.error, size: size),
      );
    }
    
    // 4. 默认图标
    return Icon(Icons.folder, size: size);
  }
}
```

### 7. 离线支持

```dart
class OfflineTemplateManager {
  // 导出模板包
  Future<File> exportTemplatePackage() async {
    final templates = await _getAllTemplates();
    final icons = await _getAllIcons();
    
    final package = {
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'templates': templates.map((t) => t.toJson()).toList(),
      'icons': icons,
    };
    
    final file = File('${await _getExportPath()}/templates.json');
    await file.writeAsString(jsonEncode(package));
    return file;
  }
  
  // 导入模板包
  Future<void> importTemplatePackage(File file) async {
    final content = await file.readAsString();
    final package = jsonDecode(content);
    
    // 验证版本兼容性
    if (!_isCompatibleVersion(package['version'])) {
      throw Exception('Incompatible template version');
    }
    
    // 导入模板
    final templates = (package['templates'] as List)
      .map((json) => SystemCategoryTemplate.fromJson(json))
      .toList();
    
    await _saveTemplates(templates);
  }
}
```

## 实施计划

### 第一阶段：基础网络加载
1. 实现网络API客户端
2. 添加基础缓存机制
3. 实现模板列表加载

### 第二阶段：智能同步
1. 实现增量同步
2. 添加版本控制
3. 优化缓存策略

### 第三阶段：图标优化
1. 实现图标CDN加载
2. 添加图标预加载
3. 实现离线图标包

### 第四阶段：高级功能
1. 实现模板推荐算法
2. 添加用户使用统计
3. 实现A/B测试支持

## 优势对比

### 相比钱记的改进
1. **更智能的缓存**: 基于网络状态的智能同步策略
2. **更好的离线支持**: 完整的离线模板包导入导出
3. **多语言优化**: 动态语言切换，无需重新加载
4. **渐进式加载**: 先本地后网络，用户体验更流畅
5. **版本控制**: 支持模板版本管理和回滚

### 安全性增强
1. **API签名验证**: 防止数据篡改
2. **HTTPS强制**: 所有API通信使用HTTPS
3. **域名白名单**: 只信任官方域名
4. **数据完整性检查**: MD5/SHA256校验

## 服务端实现建议

### API服务 (Rust/Axum)
```rust
// 模板API处理器
async fn get_templates(
    Query(params): Query<TemplateParams>,
    State(pool): State<PgPool>,
) -> Result<Json<Vec<Template>>> {
    let templates = match params.cache_key {
        Some(key) if is_cache_valid(&key) => {
            // 返回304 Not Modified
            return Ok(StatusCode::NOT_MODIFIED);
        }
        _ => {
            // 查询数据库
            query_templates(&pool, &params).await?
        }
    };
    
    Ok(Json(templates))
}

// CDN配置
async fn get_icon_url(icon_name: &str) -> String {
    format!("{}/icons/{}.png", CDN_BASE_URL, icon_name)
}
```

### 数据库优化
```sql
-- 添加索引优化查询
CREATE INDEX idx_templates_featured ON system_category_templates(is_featured) 
  WHERE is_featured = true;
  
CREATE INDEX idx_templates_popularity ON system_category_templates(global_usage_count DESC);

-- 添加缓存表
CREATE TABLE template_cache (
    cache_key VARCHAR(64) PRIMARY KEY,
    data JSONB NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

## 总结

通过借鉴钱记的网络分类加载机制，Jive Money可以实现：

1. **动态更新**: 无需发布新版本即可更新分类模板
2. **全球化支持**: 根据用户语言动态加载对应模板
3. **性能优化**: 智能缓存和预加载机制
4. **离线可用**: 完善的离线支持方案
5. **个性化推荐**: 基于使用数据的智能推荐

这种架构既保证了用户体验的流畅性，又提供了运营的灵活性。