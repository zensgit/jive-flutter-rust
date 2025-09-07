// Hive 本地存储配置
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../models/user.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../models/ledger.dart';
import 'adapters/user_adapter.dart';
import 'adapters/account_adapter.dart';
import 'adapters/transaction_adapter.dart';
import 'adapters/ledger_adapter.dart';

class HiveConfig {
  // Box 名称常量
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';
  static const String secureBox = 'secure_box';
  static const String accountsBox = 'accounts_box';
  static const String transactionsBox = 'transactions_box';
  static const String ledgersBox = 'ledgers_box';
  static const String categoriesBox = 'categories_box';
  static const String preferencesBox = 'preferences'; // For currency preferences

  // 类型ID常量
  static const int userTypeId = 0;
  static const int accountTypeId = 1;
  static const int transactionTypeId = 2;
  static const int ledgerTypeId = 3;
  static const int categoryTypeId = 4;
  static const int accountGroupTypeId = 5;
  static const int attachmentTypeId = 6;
  static const int scheduledTransactionTypeId = 7;

  /// 初始化 Hive 配置
  static Future<void> init() async {
    // Flutter环境初始化
    await Hive.initFlutter();
    
    // Web平台不需要设置路径
    if (!kIsWeb) {
      // 获取文档目录路径
      final appDocumentDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDocumentDir.path}/hive_data');
      if (!await hiveDir.exists()) {
        await hiveDir.create(recursive: true);
      }
    }
    
    // 注册适配器（如果尚未注册）
    _registerAdapters();
    
    // 打开常用的 Box
    await Future.wait([
      Hive.openBox<User>(userBox),
      Hive.openBox(settingsBox), 
      Hive.openBox(cacheBox),
      Hive.openBox(preferencesBox), // Open preferences box for currency
      Hive.openBox<Account>(accountsBox),
      Hive.openBox<Transaction>(transactionsBox),
      Hive.openBox<Ledger>(ledgersBox),
      Hive.openBox<TransactionCategory>(categoriesBox),
    ]);
  }
  
  /// 注册类型适配器
  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(userTypeId)) {
      Hive.registerAdapter(UserAdapter());
    }
    if (!Hive.isAdapterRegistered(accountTypeId)) {
      Hive.registerAdapter(AccountAdapter());
    }
    if (!Hive.isAdapterRegistered(transactionTypeId)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(ledgerTypeId)) {
      Hive.registerAdapter(LedgerAdapter());
    }
    if (!Hive.isAdapterRegistered(categoryTypeId)) {
      Hive.registerAdapter(TransactionCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(accountGroupTypeId)) {
      Hive.registerAdapter(AccountGroupAdapter());
    }
    if (!Hive.isAdapterRegistered(attachmentTypeId)) {
      Hive.registerAdapter(TransactionAttachmentAdapter());
    }
    if (!Hive.isAdapterRegistered(scheduledTransactionTypeId)) {
      Hive.registerAdapter(ScheduledTransactionAdapter());
    }
  }

  /// 获取用户数据 Box
  static Box<User> getUserBox() => Hive.box<User>(userBox);
  
  /// 获取设置数据 Box  
  static Box getSettingsBox() => Hive.box(settingsBox);
  
  /// 获取偏好设置数据 Box
  static Box getPreferencesBox() => Hive.box(preferencesBox);
  
  /// 获取缓存数据 Box
  static Box getCacheBox() => Hive.box(cacheBox);
  
  /// 获取账户数据 Box
  static Box<Account> getAccountsBox() => Hive.box<Account>(accountsBox);
  
  /// 获取交易数据 Box
  static Box<Transaction> getTransactionsBox() => Hive.box<Transaction>(transactionsBox);
  
  /// 获取账本数据 Box
  static Box<Ledger> getLedgersBox() => Hive.box<Ledger>(ledgersBox);
  
  /// 获取分类数据 Box
  static Box<TransactionCategory> getCategoriesBox() => Hive.box<TransactionCategory>(categoriesBox);
  
  /// 清理所有数据
  static Future<void> clearAll() async {
    await Future.wait([
      getUserBox().clear(),
      getSettingsBox().clear(),
      getCacheBox().clear(),
      getAccountsBox().clear(),
      getTransactionsBox().clear(),
      getLedgersBox().clear(),
      getCategoriesBox().clear(),
    ]);
  }
  
  /// 清理缓存数据
  static Future<void> clearCache() async {
    await getCacheBox().clear();
  }
  
  /// 保存用户数据
  static Future<void> saveUser(User user) async {
    await getUserBox().put('current_user', user);
  }
  
  /// 获取当前用户
  static User? getCurrentUser() {
    return getUserBox().get('current_user');
  }
  
  /// 保存设置
  static Future<void> saveSetting(String key, dynamic value) async {
    await getSettingsBox().put(key, value);
  }
  
  /// 获取设置
  static T? getSetting<T>(String key, {T? defaultValue}) {
    return getSettingsBox().get(key, defaultValue: defaultValue) as T?;
  }
  
  /// 缓存数据
  static Future<void> cacheData(String key, dynamic data, {Duration? expiry}) async {
    final cacheEntry = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    await getCacheBox().put(key, cacheEntry);
  }
  
  /// 获取缓存数据
  static T? getCachedData<T>(String key) {
    final cache = getCacheBox().get(key);
    if (cache == null) return null;
    
    final timestamp = cache['timestamp'] as int;
    final expiry = cache['expiry'] as int?;
    
    if (expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiry) {
        getCacheBox().delete(key);
        return null;
      }
    }
    
    return cache['data'] as T?;
  }
  
  /// 关闭所有Box
  static Future<void> closeAll() async {
    await Hive.close();
  }
}