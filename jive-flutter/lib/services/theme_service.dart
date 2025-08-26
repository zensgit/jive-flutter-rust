import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import '../models/theme_models.dart' as models;
import 'storage_service.dart';

/// 主题管理服务
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final StorageService _storage = StorageService();
  
  models.AppThemeSettings _currentSettings = const models.AppThemeSettings();
  List<models.CustomThemeData> _customThemes = [];
  List<models.CustomThemeData> _presetThemes = [];
  models.CustomThemeData? _activeTheme;
  bool _systemIsDark = false;

  /// 当前主题设置
  models.AppThemeSettings get currentSettings => _currentSettings;
  
  /// 自定义主题列表
  List<models.CustomThemeData> get customThemes => List.unmodifiable(_customThemes);
  
  /// 预设主题列表
  List<models.CustomThemeData> get presetThemes => List.unmodifiable(_presetThemes);
  
  /// 当前激活的主题
  models.CustomThemeData? get activeTheme => _activeTheme;
  
  /// 系统是否为深色模式
  bool get systemIsDark => _systemIsDark;

  /// 初始化主题服务
  Future<void> initialize() async {
    try {
      // 加载保存的主题设置
      await _loadThemeSettings();
      
      // 加载自定义主题
      await _loadCustomThemes();
      
      // 初始化预设主题
      _initializePresetThemes();
      
      // 设置当前激活主题
      await _setActiveTheme();
      
      // 监听系统主题变化
      _listenToSystemTheme();
    } catch (e) {
      debugPrint('主题服务初始化失败: $e');
    }
  }

  /// 获取当前应该使用的ThemeData
  ThemeData getCurrentThemeData() {
    if (_activeTheme != null) {
      bool shouldUseDark = _shouldUseDarkTheme();
      return _activeTheme!.toFlutterThemeData(isDark: shouldUseDark);
    }
    
    // 默认主题
    return _shouldUseDarkTheme() ? ThemeData.dark() : ThemeData.light();
  }

  /// 判断是否应该使用深色主题
  bool _shouldUseDarkTheme() {
    switch (_currentSettings.themeMode) {
      case models.ThemeMode.light:
        return false;
      case models.ThemeMode.dark:
        return true;
      case models.ThemeMode.system:
        return _systemIsDark;
    }
  }

  /// 切换主题模式 (Light/Dark/System)
  Future<void> setThemeMode(models.ThemeMode mode) async {
    _currentSettings = _currentSettings.copyWith(themeMode: mode);
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 应用预设主题
  Future<void> applyPresetTheme(String presetThemeId) async {
    _currentSettings = _currentSettings.copyWith(
      themeType: models.ThemeType.preset,
      presetThemeId: presetThemeId,
      customThemeId: null,
    );
    await _setActiveTheme();
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 应用自定义主题
  Future<void> applyCustomTheme(String customThemeId) async {
    _currentSettings = _currentSettings.copyWith(
      themeType: models.ThemeType.custom,
      customThemeId: customThemeId,
      presetThemeId: null,
    );
    await _setActiveTheme();
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 重置为系统默认主题
  Future<void> resetToSystemTheme() async {
    _currentSettings = const models.AppThemeSettings();
    _activeTheme = null;
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 创建新的自定义主题
  Future<models.CustomThemeData> createCustomTheme({
    required String name,
    String author = '我',
    String description = '',
    models.CustomThemeData? baseTheme,
  }) async {
    final theme = baseTheme?.copyWith(
      id: _generateThemeId(),
      name: name,
      author: author,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 0.0,
    ) ?? _createDefaultCustomTheme(
      id: _generateThemeId(),
      name: name,
      author: author,
      description: description,
    );

    _customThemes.add(theme);
    await _saveCustomThemes();
    notifyListeners();
    
    return theme;
  }

  /// 更新自定义主题
  Future<void> updateCustomTheme(String themeId, models.CustomThemeData updatedTheme) async {
    final index = _customThemes.indexWhere((theme) => theme.id == themeId);
    if (index != -1) {
      _customThemes[index] = updatedTheme.copyWith(updatedAt: DateTime.now());
      await _saveCustomThemes();
      
      // 如果更新的是当前激活主题，重新设置
      if (_currentSettings.customThemeId == themeId) {
        await _setActiveTheme();
      }
      
      notifyListeners();
    }
  }

  /// 删除自定义主题
  Future<void> deleteCustomTheme(String themeId) async {
    _customThemes.removeWhere((theme) => theme.id == themeId);
    await _saveCustomThemes();
    
    // 如果删除的是当前激活主题，重置为系统主题
    if (_currentSettings.customThemeId == themeId) {
      await resetToSystemTheme();
    }
    
    notifyListeners();
  }

  /// 分享主题
  Future<String> shareTheme(String themeId) async {
    models.CustomThemeData? theme = _customThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => _presetThemes.firstWhere((t) => t.id == themeId),
    );
    
    if (theme == null) {
      throw Exception('主题不存在');
    }

    final shareCode = _generateShareCode();
    final sharedTheme = models.SharedThemeData(
      shareCode: shareCode,
      themeData: theme.copyWith(isShared: true),
      sharedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)), // 30天有效期
    );

    // 保存分享数据
    await _storage.saveSharedTheme(shareCode, sharedTheme);
    
    return shareCode;
  }

  /// 导入分享的主题
  Future<models.CustomThemeData> importSharedTheme(String shareCode) async {
    final sharedTheme = await _storage.getSharedTheme(shareCode);
    if (sharedTheme == null) {
      throw Exception('分享码无效或已过期');
    }

    if (sharedTheme.isExpired) {
      throw Exception('分享已过期');
    }

    // 创建新主题（重新生成ID，避免冲突）
    final importedTheme = sharedTheme.themeData.copyWith(
      id: _generateThemeId(),
      name: '${sharedTheme.themeData.name}（导入）',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 0.0,
    );

    _customThemes.add(importedTheme);
    await _saveCustomThemes();
    notifyListeners();

    return importedTheme;
  }

  /// 从URL导入主题
  Future<models.CustomThemeData> importThemeFromUrl(String url) async {
    // 从URL提取分享码
    final shareCode = url.split('/').last;
    return await importSharedTheme(shareCode);
  }

  /// 导出主题为JSON字符串
  String exportThemeToJson(String themeId) {
    models.CustomThemeData? theme = _customThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => _presetThemes.firstWhere((t) => t.id == themeId),
    );
    
    if (theme == null) {
      throw Exception('主题不存在');
    }

    return jsonEncode(theme.toJson());
  }

  /// 从JSON字符串导入主题
  Future<models.CustomThemeData> importThemeFromJson(String jsonString) async {
    try {
      final json = jsonDecode(jsonString);
      final theme = models.CustomThemeData.fromJson(json).copyWith(
        id: _generateThemeId(),
        name: '${json['name']}（导入）',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isShared: false,
        downloads: 0,
        rating: 0.0,
      );

      _customThemes.add(theme);
      await _saveCustomThemes();
      notifyListeners();

      return theme;
    } catch (e) {
      throw Exception('无效的主题文件格式');
    }
  }

  /// 复制主题到剪贴板
  Future<void> copyThemeToClipboard(String themeId) async {
    final jsonString = exportThemeToJson(themeId);
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// 从剪贴板导入主题
  Future<models.CustomThemeData?> importThemeFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        return await importThemeFromJson(clipboardData!.text!);
      }
    } catch (e) {
      debugPrint('从剪贴板导入主题失败: $e');
    }
    return null;
  }

  // 私有方法

  /// 加载主题设置
  Future<void> _loadThemeSettings() async {
    try {
      final settings = await _storage.getThemeSettings();
      if (settings != null) {
        _currentSettings = settings;
      }
    } catch (e) {
      debugPrint('加载主题设置失败: $e');
    }
  }

  /// 保存主题设置
  Future<void> _saveThemeSettings() async {
    try {
      await _storage.saveThemeSettings(_currentSettings);
    } catch (e) {
      debugPrint('保存主题设置失败: $e');
    }
  }

  /// 加载自定义主题
  Future<void> _loadCustomThemes() async {
    try {
      final themes = await _storage.getCustomThemes();
      _customThemes = themes;
    } catch (e) {
      debugPrint('加载自定义主题失败: $e');
    }
  }

  /// 保存自定义主题
  Future<void> _saveCustomThemes() async {
    try {
      await _storage.saveCustomThemes(_customThemes);
    } catch (e) {
      debugPrint('保存自定义主题失败: $e');
    }
  }

  /// 设置当前激活主题
  Future<void> _setActiveTheme() async {
    switch (_currentSettings.themeType) {
      case models.ThemeType.custom:
        if (_currentSettings.customThemeId != null) {
          _activeTheme = _customThemes.firstWhere(
            (theme) => theme.id == _currentSettings.customThemeId,
            orElse: () => _presetThemes.first,
          );
        }
        break;
      case models.ThemeType.preset:
        if (_currentSettings.presetThemeId != null) {
          _activeTheme = _presetThemes.firstWhere(
            (theme) => theme.id == _currentSettings.presetThemeId,
            orElse: () => _presetThemes.first,
          );
        }
        break;
      case models.ThemeType.system:
        _activeTheme = null;
        break;
    }
  }

  /// 监听系统主题变化
  void _listenToSystemTheme() {
    // Flutter会通过MediaQuery.of(context).platformBrightness自动检测
    // 这里我们模拟系统主题变化监听
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final window = WidgetsBinding.instance.window;
      _systemIsDark = window.platformBrightness == Brightness.dark;
    });
  }

  /// 初始化预设主题
  void _initializePresetThemes() {
    _presetThemes = [
      // 经典蓝色主题
      _createPresetTheme(
        id: 'preset_blue',
        name: '经典蓝',
        primaryColor: const Color(0xFF2196F3),
        secondaryColor: const Color(0xFF03DAC6),
      ),
      
      // 温暖橙色主题
      _createPresetTheme(
        id: 'preset_orange',
        name: '温暖橙',
        primaryColor: const Color(0xFFFF9800),
        secondaryColor: const Color(0xFFFF5722),
      ),
      
      // 清新绿色主题
      _createPresetTheme(
        id: 'preset_green',
        name: '清新绿',
        primaryColor: const Color(0xFF4CAF50),
        secondaryColor: const Color(0xFF8BC34A),
      ),
      
      // 优雅紫色主题
      _createPresetTheme(
        id: 'preset_purple',
        name: '优雅紫',
        primaryColor: const Color(0xFF9C27B0),
        secondaryColor: const Color(0xFFE91E63),
      ),
      
      // 深邃蓝色主题
      _createPresetTheme(
        id: 'preset_indigo',
        name: '深邃蓝',
        primaryColor: const Color(0xFF3F51B5),
        secondaryColor: const Color(0xFF2196F3),
      ),
      
      // 活力红色主题
      _createPresetTheme(
        id: 'preset_red',
        name: '活力红',
        primaryColor: const Color(0xFFF44336),
        secondaryColor: const Color(0xFFE91E63),
      ),
      
      // 自然棕色主题
      _createPresetTheme(
        id: 'preset_brown',
        name: '自然棕',
        primaryColor: const Color(0xFF795548),
        secondaryColor: const Color(0xFF8D6E63),
      ),
      
      // 科技青色主题
      _createPresetTheme(
        id: 'preset_cyan',
        name: '科技青',
        primaryColor: const Color(0xFF00BCD4),
        secondaryColor: const Color(0xFF4DD0E1),
      ),
    ];
  }

  /// 创建预设主题
  models.CustomThemeData _createPresetTheme({
    required String id,
    required String name,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return models.CustomThemeData(
      id: id,
      name: name,
      author: 'Jive Money',
      description: '$name 预设主题',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 5.0,
      primaryColor: primaryColor,
      primaryVariant: primaryColor.withOpacity(0.8),
      secondary: secondaryColor,
      secondaryVariant: secondaryColor.withOpacity(0.8),
      background: Colors.white,
      surface: Colors.white,
      surfaceVariant: const Color(0xFFF5F5F5),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      success: const Color(0xFF4CAF50),
      warning: const Color(0xFFFF9800),
      info: primaryColor,
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE0E0E0),
      borderColor: const Color(0xFFE0E0E0),
      buttonPrimary: Colors.black,
      buttonSecondary: Colors.white,
      buttonText: Colors.white,
      navigationBar: Colors.white,
      navigationBarText: Colors.black87,
      navigationBarSelected: primaryColor,
    );
  }

  /// 创建默认自定义主题
  models.CustomThemeData _createDefaultCustomTheme({
    required String id,
    required String name,
    required String author,
    required String description,
  }) {
    return models.CustomThemeData(
      id: id,
      name: name,
      author: author,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 0.0,
      primaryColor: const Color(0xFF2196F3),
      primaryVariant: const Color(0xFF1976D2),
      secondary: const Color(0xFF03DAC6),
      secondaryVariant: const Color(0xFF018786),
      background: Colors.white,
      surface: Colors.white,
      surfaceVariant: const Color(0xFFF5F5F5),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      success: const Color(0xFF4CAF50),
      warning: const Color(0xFFFF9800),
      info: const Color(0xFF2196F3),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE0E0E0),
      borderColor: const Color(0xFFE0E0E0),
      buttonPrimary: Colors.black,
      buttonSecondary: Colors.white,
      buttonText: Colors.white,
      navigationBar: Colors.white,
      navigationBarText: Colors.black87,
      navigationBarSelected: const Color(0xFF2196F3),
    );
  }

  /// 生成主题ID
  String _generateThemeId() {
    return 'theme_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// 生成分享码
  String _generateShareCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      8, (_) => chars.codeUnitAt(random.nextInt(chars.length))
    ));
  }
}