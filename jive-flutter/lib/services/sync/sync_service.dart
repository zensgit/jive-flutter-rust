import 'dart:async';
// import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/storage/hive_config.dart';
import '../api/auth_service.dart';
import '../api/account_service.dart';
import '../api/transaction_service.dart';
import '../api/ledger_service.dart';

/// 数据同步服务
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _authService = AuthService();
  final _accountService = AccountService();
  final _transactionService = TransactionService();
  final _ledgerService = LedgerService();

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus get currentStatus => _currentStatus;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  Timer? _autoSyncTimer;
  bool _isInitialized = false;

  /// 初始化同步服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    _lastSyncTime = await _getLastSyncTime();

    // 监听网络状态变化 - 暂时禁用
    // _listenToConnectivity();

    // 启动自动同步
    _startAutoSync();
  }

  /// 监听网络连接状态 - 暂时禁用
  // void _listenToConnectivity() {
  //   Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
  //     if (result != ConnectivityResult.none && _shouldAutoSync()) {
  //       syncAll();
  //     }
  //   });
  // }

  /// 启动自动同步
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (_shouldAutoSync()) {
          syncAll();
        }
      },
    );
  }

  /// 是否应该自动同步
  bool _shouldAutoSync() {
    // 检查是否已登录
    if (!_authService.isAuthenticated) {
      return false;
    }

    // 检查距离上次同步的时间
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync.inMinutes < 5) {
        return false;
      }
    }

    return true;
  }

  /// 同步所有数据
  Future<SyncResult> syncAll() async {
    if (_currentStatus == SyncStatus.syncing) {
      return SyncResult(success: false, message: '正在同步中...');
    }

    _updateStatus(SyncStatus.syncing);

    try {
      // 检查网络连接 - 暂时总是返回true
      // final hasConnection = await _checkConnectivity();
      const hasConnection = true;

      if (!hasConnection) {
        _updateStatus(SyncStatus.offline);
        return SyncResult(success: false, message: '无网络连接');
      }

      // 检查登录状态
      if (!_authService.isAuthenticated) {
        _updateStatus(SyncStatus.error);
        return SyncResult(success: false, message: '未登录');
      }

      // 同步各类数据
      await _syncUserData();
      await _syncLedgers();
      await _syncAccounts();
      await _syncTransactions();

      // 更新同步时间
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime(_lastSyncTime!);

      _updateStatus(SyncStatus.completed);
      return SyncResult(success: true, message: '同步成功');
    } catch (e) {
      _updateStatus(SyncStatus.error);
      return SyncResult(
        success: false,
        message: '同步失败: ${e.toString()}',
      );
    }
  }

  /// 检查网络连接 - 暂时禁用
  // Future<bool> _checkConnectivity() async {
  //   final connectivityResult = await Connectivity().checkConnectivity();
  //   return connectivityResult != ConnectivityResult.none;
  // }

  /// 同步用户数据
  Future<void> _syncUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      await HiveConfig.saveUser(user);
    } catch (e) {
      debugPrint('同步用户数据失败: $e');
    }
  }

  /// 同步账本数据
  Future<void> _syncLedgers() async {
    try {
      final ledgers = await _ledgerService.getAllLedgers();

      // 清空本地数据
      await HiveConfig.getLedgersBox().clear();

      // 保存新数据
      for (final ledger in ledgers) {
        await HiveConfig.getLedgersBox().put(ledger.id, ledger);
      }
    } catch (e) {
      debugPrint('同步账本数据失败: $e');
    }
  }

  /// 同步账户数据
  Future<void> _syncAccounts() async {
    try {
      final accounts = await _accountService.getAllAccounts();

      // 清空本地数据
      await HiveConfig.getAccountsBox().clear();

      // 保存新数据
      for (final account in accounts) {
        await HiveConfig.getAccountsBox().put(account.id, account);
      }
    } catch (e) {
      debugPrint('同步账户数据失败: $e');
    }
  }

  /// 同步交易数据
  Future<void> _syncTransactions() async {
    try {
      // 获取最近的交易（例如最近3个月）
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 90));

      final response = await _transactionService.getTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      // 清空本地数据
      await HiveConfig.getTransactionsBox().clear();

      // 保存新数据
      for (final transaction in response.data) {
        await HiveConfig.getTransactionsBox().put(transaction.id, transaction);
      }
    } catch (e) {
      debugPrint('同步交易数据失败: $e');
    }
  }

  /// 获取最后同步时间
  Future<DateTime?> _getLastSyncTime() async {
    final timestamp = HiveConfig.getSetting<int>('last_sync_time');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// 保存最后同步时间
  Future<void> _saveLastSyncTime(DateTime time) async {
    await HiveConfig.saveSetting(
      'last_sync_time',
      time.millisecondsSinceEpoch,
    );
  }

  /// 更新同步状态
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _syncStatusController.add(status);
  }

  /// 清理资源
  void dispose() {
    _autoSyncTimer?.cancel();
    _syncStatusController.close();
  }
}

/// 同步状态
enum SyncStatus {
  idle, // 空闲
  syncing, // 同步中
  completed, // 完成
  error, // 错误
  offline, // 离线
}

/// 同步结果
class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  SyncResult({
    required this.success,
    required this.message,
    this.data,
  });
}
