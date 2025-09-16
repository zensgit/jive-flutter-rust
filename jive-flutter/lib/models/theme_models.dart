import 'package:flutter/material.dart';

/// 主题模式枚举
enum ThemeMode {
  light('light', '浅色'),
  dark('dark', '深色'), 
  system('system', '跟随系统');

  const ThemeMode(this.value, this.displayName);
  
  final String value;
  final String displayName;
}

/// 主题类型枚举
enum ThemeType {
  system('system', '系统主题'),
  preset('preset', '预设主题'),
  custom('custom', '自定义主题');

  const ThemeType(this.value, this.displayName);
  
  final String value;
  final String displayName;
}

/// 自定义主题数据模型
class CustomThemeData {
  final String id;
  final String name;
  final String author;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isShared;
  final int downloads;
  final double rating;
  
  // 主色调
  final Color primaryColor;
  final Color primaryVariant;
  final Color secondary;
  final Color secondaryVariant;
  
  // 背景色
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  
  // 文字色
  final Color onPrimary;
  final Color onSecondary;
  final Color onBackground;
  final Color onSurface;
  
  // 状态色
  final Color error;
  final Color onError;
  final Color success;
  final Color warning;
  final Color info;
  
  // 卡片和边框
  final Color cardColor;
  final Color dividerColor;
  final Color borderColor;
  
  // 按钮样式
  final Color buttonPrimary;
  final Color buttonSecondary;
  final Color buttonText;
  
  // 导航栏
  final Color navigationBar;
  final Color navigationBarText;
  final Color navigationBarSelected;
  // UI extensions
  final String listDensity; // 'comfortable' | 'compact'
  final String cornerRadius; // 'small' | 'medium' | 'large'

  const CustomThemeData({
    required this.id,
    required this.name,
    required this.author,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.isShared = false,
    this.downloads = 0,
    this.rating = 0.0,
    required this.primaryColor,
    required this.primaryVariant,
    required this.secondary,
    required this.secondaryVariant,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onPrimary,
    required this.onSecondary,
    required this.onBackground,
    required this.onSurface,
    required this.error,
    required this.onError,
    required this.success,
    required this.warning,
    required this.info,
    required this.cardColor,
    required this.dividerColor,
    required this.borderColor,
    required this.buttonPrimary,
    required this.buttonSecondary,
    required this.buttonText,
    required this.navigationBar,
    required this.navigationBarText,
    required this.navigationBarSelected,
    this.listDensity = 'comfortable',
    this.cornerRadius = 'medium',
  });

  /// 转换为Flutter ThemeData
  ThemeData toFlutterThemeData({bool isDark = false}) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        surface: surface,
        onSurface: onSurface,
        error: error,
        onError: onError,
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      dividerColor: dividerColor,
      
      // 应用栏主题
      appBarTheme: AppBarTheme(
        backgroundColor: navigationBar,
        foregroundColor: navigationBarText,
        elevation: 0,
        centerTitle: true,
      ),
      
      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navigationBar,
        selectedItemColor: navigationBarSelected,
        unselectedItemColor: navigationBarText.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
      ),
      
      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonPrimary,
          foregroundColor: buttonText,
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonPrimary,
          side: BorderSide(color: buttonPrimary),
        ),
      ),
      
      // 卡片主题
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            cornerRadius == 'small' ? 8 : (cornerRadius == 'large' ? 16 : 12),
          ),
          side: BorderSide(color: borderColor.withOpacity(0.1)),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(
            cornerRadius == 'small' ? 8 : (cornerRadius == 'large' ? 16 : 12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
          borderRadius: BorderRadius.circular(
            cornerRadius == 'small' ? 8 : (cornerRadius == 'large' ? 16 : 12),
          ),
        ),
      ),
      visualDensity: listDensity == 'compact'
          ? const VisualDensity(horizontal: -2, vertical: -2)
          : VisualDensity.adaptivePlatformDensity,
    );
  }

  /// 从JSON创建主题
  factory CustomThemeData.fromJson(Map<String, dynamic> json) {
    return CustomThemeData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      isShared: json['isShared'] ?? false,
      downloads: json['downloads'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      primaryColor: Color(json['primaryColor'] ?? 0xFF2196F3),
      primaryVariant: Color(json['primaryVariant'] ?? 0xFF1976D2),
      secondary: Color(json['secondary'] ?? 0xFF03DAC6),
      secondaryVariant: Color(json['secondaryVariant'] ?? 0xFF018786),
      background: Color(json['background'] ?? 0xFFFFFFFF),
      surface: Color(json['surface'] ?? 0xFFFFFFFF),
      surfaceVariant: Color(json['surfaceVariant'] ?? 0xFFF5F5F5),
      onPrimary: Color(json['onPrimary'] ?? 0xFFFFFFFF),
      onSecondary: Color(json['onSecondary'] ?? 0xFF000000),
      onBackground: Color(json['onBackground'] ?? 0xFF000000),
      onSurface: Color(json['onSurface'] ?? 0xFF000000),
      error: Color(json['error'] ?? 0xFFB00020),
      onError: Color(json['onError'] ?? 0xFFFFFFFF),
      success: Color(json['success'] ?? 0xFF4CAF50),
      warning: Color(json['warning'] ?? 0xFFFF9800),
      info: Color(json['info'] ?? 0xFF2196F3),
      cardColor: Color(json['cardColor'] ?? 0xFFFFFFFF),
      dividerColor: Color(json['dividerColor'] ?? 0xFFE0E0E0),
      borderColor: Color(json['borderColor'] ?? 0xFFE0E0E0),
      buttonPrimary: Color(json['buttonPrimary'] ?? 0xFF000000),
      buttonSecondary: Color(json['buttonSecondary'] ?? 0xFFFFFFFF),
      buttonText: Color(json['buttonText'] ?? 0xFFFFFFFF),
      navigationBar: Color(json['navigationBar'] ?? 0xFFFFFFFF),
      navigationBarText: Color(json['navigationBarText'] ?? 0xFF000000),
      navigationBarSelected: Color(json['navigationBarSelected'] ?? 0xFF2196F3),
      listDensity: json['listDensity'] ?? 'comfortable',
      cornerRadius: json['cornerRadius'] ?? 'medium',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isShared': isShared,
      'downloads': downloads,
      'rating': rating,
      'primaryColor': primaryColor.value,
      'primaryVariant': primaryVariant.value,
      'secondary': secondary.value,
      'secondaryVariant': secondaryVariant.value,
      'background': background.value,
      'surface': surface.value,
      'surfaceVariant': surfaceVariant.value,
      'onPrimary': onPrimary.value,
      'onSecondary': onSecondary.value,
      'onBackground': onBackground.value,
      'onSurface': onSurface.value,
      'error': error.value,
      'onError': onError.value,
      'success': success.value,
      'warning': warning.value,
      'info': info.value,
      'cardColor': cardColor.value,
      'dividerColor': dividerColor.value,
      'borderColor': borderColor.value,
      'buttonPrimary': buttonPrimary.value,
      'buttonSecondary': buttonSecondary.value,
      'buttonText': buttonText.value,
      'navigationBar': navigationBar.value,
      'navigationBarText': navigationBarText.value,
      'navigationBarSelected': navigationBarSelected.value,
      'listDensity': listDensity,
      'cornerRadius': cornerRadius,
    };
  }

  /// 复制并更新主题
  CustomThemeData copyWith({
    String? id,
    String? name,
    String? author,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isShared,
    int? downloads,
    double? rating,
    Color? primaryColor,
    Color? primaryVariant,
    Color? secondary,
    Color? secondaryVariant,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? onPrimary,
    Color? onSecondary,
    Color? onBackground,
    Color? onSurface,
    Color? error,
    Color? onError,
    Color? success,
    Color? warning,
    Color? info,
    Color? cardColor,
    Color? dividerColor,
    Color? borderColor,
    Color? buttonPrimary,
    Color? buttonSecondary,
    Color? buttonText,
    Color? navigationBar,
    Color? navigationBarText,
    Color? navigationBarSelected,
    String? listDensity,
    String? cornerRadius,
  }) {
    return CustomThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isShared: isShared ?? this.isShared,
      downloads: downloads ?? this.downloads,
      rating: rating ?? this.rating,
      primaryColor: primaryColor ?? this.primaryColor,
      primaryVariant: primaryVariant ?? this.primaryVariant,
      secondary: secondary ?? this.secondary,
      secondaryVariant: secondaryVariant ?? this.secondaryVariant,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onPrimary: onPrimary ?? this.onPrimary,
      onSecondary: onSecondary ?? this.onSecondary,
      onBackground: onBackground ?? this.onBackground,
      onSurface: onSurface ?? this.onSurface,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      cardColor: cardColor ?? this.cardColor,
      dividerColor: dividerColor ?? this.dividerColor,
      borderColor: borderColor ?? this.borderColor,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonSecondary: buttonSecondary ?? this.buttonSecondary,
      buttonText: buttonText ?? this.buttonText,
      navigationBar: navigationBar ?? this.navigationBar,
      navigationBarText: navigationBarText ?? this.navigationBarText,
      navigationBarSelected: navigationBarSelected ?? this.navigationBarSelected,
      listDensity: listDensity ?? this.listDensity,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }
}

/// 应用主题设置
class AppThemeSettings {
  final ThemeMode themeMode;
  final ThemeType themeType;
  final String? customThemeId;
  final String? presetThemeId;

  const AppThemeSettings({
    this.themeMode = ThemeMode.system,
    this.themeType = ThemeType.system,
    this.customThemeId,
    this.presetThemeId,
  });

  factory AppThemeSettings.fromJson(Map<String, dynamic> json) {
    return AppThemeSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.value == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      themeType: ThemeType.values.firstWhere(
        (type) => type.value == json['themeType'],
        orElse: () => ThemeType.system,
      ),
      customThemeId: json['customThemeId'],
      presetThemeId: json['presetThemeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.value,
      'themeType': themeType.value,
      'customThemeId': customThemeId,
      'presetThemeId': presetThemeId,
    };
  }

  AppThemeSettings copyWith({
    ThemeMode? themeMode,
    ThemeType? themeType,
    String? customThemeId,
    String? presetThemeId,
  }) {
    return AppThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      themeType: themeType ?? this.themeType,
      customThemeId: customThemeId ?? this.customThemeId,
      presetThemeId: presetThemeId ?? this.presetThemeId,
    );
  }
}

/// 主题分享数据
class SharedThemeData {
  final String shareCode;
  final CustomThemeData themeData;
  final DateTime sharedAt;
  final DateTime expiresAt;

  const SharedThemeData({
    required this.shareCode,
    required this.themeData,
    required this.sharedAt,
    required this.expiresAt,
  });

  factory SharedThemeData.fromJson(Map<String, dynamic> json) {
    return SharedThemeData(
      shareCode: json['shareCode'],
      themeData: CustomThemeData.fromJson(json['themeData']),
      sharedAt: DateTime.parse(json['sharedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareCode': shareCode,
      'themeData': themeData.toJson(),
      'sharedAt': sharedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  /// 生成分享链接
  String get shareUrl => 'https://jivemoney.com/theme/import/$shareCode';

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
