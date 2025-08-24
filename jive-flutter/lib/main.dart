import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/hive_config.dart';
import 'core/utils/logger.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志
  AppLogger.init();
  AppLogger.info('🚀 Jive App starting...');

  try {
    // 初始化本地存储
    await _initializeStorage();
    
    // 设置系统UI样式
    await _setupSystemUI();
    
    // 运行应用
    runApp(
      ProviderScope(
        child: JiveApp(),
      ),
    );
    
    AppLogger.info('✅ Jive App initialized successfully');
  } catch (error, stackTrace) {
    AppLogger.error('❌ Failed to initialize app', error, stackTrace);
    
    // 显示错误页面
    runApp(
      MaterialApp(
        title: 'Jive - Error',
        home: ErrorScreen(error: error.toString()),
      ),
    );
  }
}

/// 初始化存储系统
Future<void> _initializeStorage() async {
  AppLogger.info('📦 Initializing storage...');
  
  // 初始化 Hive
  await Hive.initFlutter();
  await HiveConfig.init();
  
  // 初始化 SharedPreferences
  await SharedPreferences.getInstance();
  
  AppLogger.info('✅ Storage initialized');
}

/// 设置系统UI样式
Future<void> _setupSystemUI() async {
  AppLogger.info('🎨 Setting up system UI...');
  
  // 设置状态栏和导航栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 设置首选方向（主要是竖屏）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  AppLogger.info('✅ System UI configured');
}

/// 错误显示页面
class ErrorScreen extends StatelessWidget {
  final String error;
  
  const ErrorScreen({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.error,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'App Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // 重启应用
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Restart App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 应用颜色常量
class AppColors {
  static const Color primary = Color(0xFF3B82F6);
  static const Color error = Color(0xFFEF4444);
}