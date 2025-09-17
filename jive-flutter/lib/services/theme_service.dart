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
  List<models.CustomThemeData> get customThemes =>
      List.unmodifiable(_customThemes);

  /// 预设主题列表
  List<models.CustomThemeData> get presetThemes =>
      List.unmodifiable(_presetThemes);

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

  /// 应用“护眼主题”（低饱和、低对比、柔和背景）
  Future<void> applyEyeComfortTheme() async {
    final theme = models.CustomThemeData(
      id: _generateThemeId(),
      name: '护眼主题',
      author: 'Jive Money',
      description: '低饱和、低对比、柔和灰背景，长时间阅读更舒适',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 5.0,
      primaryColor: const Color(0xFF6B8FB3), // 柔和蓝灰
      primaryVariant: const Color(0xFF5F7FA0),
      secondary: const Color(0xFF7FA6B8),
      secondaryVariant: const Color(0xFF6E95A8),
      background: const Color(0xFFFAFAFA),
      surface: const Color(0xFFF3F4F6),
      surfaceVariant: const Color(0xFFE5E7EB),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onBackground: const Color(0xFF2C3E50),
      onSurface: const Color(0xFF34495E),
      error: const Color(0xFFE57373),
      onError: Colors.white,
      success: const Color(0xFF81C784),
      warning: const Color(0xFFFFB74D),
      info: const Color(0xFF64B5F6),
      cardColor: const Color(0xFFF8FAFC),
      dividerColor: const Color(0xFFE2E8F0),
      borderColor: const Color(0xFFD1D5DB),
      buttonPrimary: const Color(0xFF445D74),
      buttonSecondary: Colors.white,
      buttonText: Colors.white,
      navigationBar: const Color(0xFFF3F4F6),
      navigationBarText: const Color(0xFF475569),
      navigationBarSelected: const Color(0xFF6B8FB3),
      listDensity: 'comfortable',
      cornerRadius: 'large',
    );
    _customThemes.add(theme);
    await _saveCustomThemes();
    await applyCustomTheme(theme.id);
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
        ) ??
        _createDefaultCustomTheme(
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
  Future<void> updateCustomTheme(
      String themeId, models.CustomThemeData updatedTheme) async {
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

      // 护眼蓝灰（低饱和、柔和背景）
      models.CustomThemeData(
        id: 'preset_eye_bluegrey',
        name: '护眼·蓝灰',
        author: 'Jive Money',
        description: '低饱和蓝灰，柔和灰白背景，长时间阅读舒适',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isShared: false,
        downloads: 0,
        rating: 5.0,
        primaryColor: const Color(0xFF6B8FB3),
        primaryVariant: const Color(0xFF5F7FA0),
        secondary: const Color(0xFF7FA6B8),
        secondaryVariant: const Color(0xFF6E95A8),
        background: const Color(0xFFFAFAFA),
        surface: const Color(0xFFF4F6F8),
        surfaceVariant: const Color(0xFFE8ECEF),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: const Color(0xFF2E3A46),
        onSurface: const Color(0xFF334155),
        error: const Color(0xFFE57373),
        onError: Colors.white,
        success: const Color(0xFF81C784),
        warning: const Color(0xFFFFB74D),
        info: const Color(0xFF64B5F6),
        cardColor: const Color(0xFFF8FAFC),
        dividerColor: const Color(0xFFE2E8F0),
        borderColor: const Color(0xFFD1D5DB),
        buttonPrimary: const Color(0xFF4B6B88),
        buttonSecondary: Colors.white,
        buttonText: Colors.white,
        navigationBar: const Color(0xFFF3F4F6),
        navigationBarText: const Color(0xFF475569),
        navigationBarSelected: const Color(0xFF6B8FB3),
        listDensity: 'comfortable',
        cornerRadius: 'large',
      ),

      // 护眼青绿（低饱和、柔和背景）
      models.CustomThemeData(
        id: 'preset_eye_green',
        name: '护眼·青绿',
        author: 'Jive Money',
        description: '低饱和青绿，柔和灰白背景，降低对比度刺眼感',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isShared: false,
        downloads: 0,
        rating: 5.0,
        primaryColor: const Color(0xFF6BAE9C),
        primaryVariant: const Color(0xFF5D9E8D),
        secondary: const Color(0xFF88C0B3),
        secondaryVariant: const Color(0xFF77B0A3),
        background: const Color(0xFFFAFAFA),
        surface: const Color(0xFFF5F7F6),
        surfaceVariant: const Color(0xFFE7ECEA),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: const Color(0xFF2F3A34),
        onSurface: const Color(0xFF3B4A43),
        error: const Color(0xFFE57373),
        onError: Colors.white,
        success: const Color(0xFF7CB342),
        warning: const Color(0xFFFFB74D),
        info: const Color(0xFF4DB6AC),
        cardColor: const Color(0xFFF8FAF9),
        dividerColor: const Color(0xFFDDE5E2),
        borderColor: const Color(0xFFC8D4CF),
        buttonPrimary: const Color(0xFF4E8677),
        buttonSecondary: Colors.white,
        buttonText: Colors.white,
        navigationBar: const Color(0xFFF1F5F3),
        navigationBarText: const Color(0xFF50665E),
        navigationBarSelected: const Color(0xFF6BAE9C),
        listDensity: 'comfortable',
        cornerRadius: 'large',
      ),

      // 夜间护眼（深色低对比）
      models.CustomThemeData(
        id: 'preset_eye_dark',
        name: '护眼·夜间',
        author: 'Jive Money',
        description: '深色低对比，适合夜间使用',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isShared: false,
        downloads: 0,
        rating: 5.0,
        primaryColor: const Color(0xFF7A90A5),
        primaryVariant: const Color(0xFF6A7F93),
        secondary: const Color(0xFF8EA3B5),
        secondaryVariant: const Color(0xFF7B8FA0),
        background: const Color(0xFF0F1419),
        surface: const Color(0xFF151B22),
        surfaceVariant: const Color(0xFF1C242C),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: const Color(0xFFE5EAF0),
        onSurface: const Color(0xFFD8DEE5),
        error: const Color(0xFFE57373),
        onError: Colors.white,
        success: const Color(0xFF81C784),
        warning: const Color(0xFFFFB74D),
        info: const Color(0xFF64B5F6),
        cardColor: const Color(0xFF171E26),
        dividerColor: const Color(0xFF253241),
        borderColor: const Color(0xFF243140),
        buttonPrimary: const Color(0xFF4B647E),
        buttonSecondary: const Color(0xFF10161B),
        buttonText: Colors.white,
        navigationBar: const Color(0xFF121820),
        navigationBarText: const Color(0xFFB7C4D1),
        navigationBarSelected: const Color(0xFF7A90A5),
        listDensity: 'comfortable',
        cornerRadius: 'large',
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
      listDensity: 'comfortable',
      cornerRadius: 'medium',
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
      listDensity: 'comfortable',
      cornerRadius: 'medium',
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
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}
