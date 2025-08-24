// Hive 本地存储配置
import 'package:hive/hive.dart';

class HiveConfig {
  // Box 名称常量
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';
  static const String secureBox = 'secure_box';

  /// 初始化 Hive 配置
  static Future<void> init() async {
    // 注册适配器（如果有自定义类型）
    // Hive.registerAdapter(UserModelAdapter());
    
    // 打开常用的 Box
    await Future.wait([
      Hive.openBox(userBox),
      Hive.openBox(settingsBox), 
      Hive.openBox(cacheBox),
    ]);
  }

  /// 获取用户数据 Box
  static Box getUserBox() => Hive.box(userBox);
  
  /// 获取设置数据 Box  
  static Box getSettingsBox() => Hive.box(settingsBox);
  
  /// 获取缓存数据 Box
  static Box getCacheBox() => Hive.box(cacheBox);
  
  /// 清理所有数据
  static Future<void> clearAll() async {
    await Future.wait([
      getUserBox().clear(),
      getSettingsBox().clear(),
      getCacheBox().clear(),
    ]);
  }
}