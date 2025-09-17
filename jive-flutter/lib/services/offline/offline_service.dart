import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/storage/hive_config.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../sync/sync_service.dart';

/// 离线模式服务
class OfflineService {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  final List<PendingOperation> _pendingOperations = [];
  List<PendingOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// 初始化离线服务
  Future<void> init() async {
    // 检查初始连接状态
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(connectivityResult != ConnectivityResult.none);

    // 监听连接状态变化
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result != ConnectivityResult.none);
    });

    // 加载待处理的操作
    await _loadPendingOperations();
  }

  /// 更新连接状态
  void _updateConnectivityStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectivityController.add(isOnline);

      if (isOnline) {
        debugPrint('网络连接已恢复');
        _onNetworkReconnected();
      } else {
        debugPrint('网络连接已断开，进入离线模式');
        _onNetworkDisconnected();
      }
    }
  }

  /// 网络重新连接时的处理
  void _onNetworkReconnected() {
    // 自动同步待处理的操作
    _processPendingOperations();
  }

  /// 网络断开时的处理
  void _onNetworkDisconnected() {
    // 可以在这里做一些清理工作
  }

  /// 离线创建交易
  Future<String> createTransactionOffline(Transaction transaction) async {
    final localId =
        'offline_${DateTime.now().millisecondsSinceEpoch}_${transaction.hashCode}';
    final offlineTransaction = transaction.copyWith(id: localId);

    // 保存到本地存储
    await HiveConfig.getTransactionsBox().put(localId, offlineTransaction);

    // 添加到待处理操作
    final operation = PendingOperation(
      id: localId,
      type: OperationType.createTransaction,
      data: offlineTransaction.toJson(),
      timestamp: DateTime.now(),
    );

    _pendingOperations.add(operation);
    await _savePendingOperations();

    debugPrint('离线创建交易: $localId');
    return localId;
  }

  /// 离线更新交易
  Future<void> updateTransactionOffline(
      String id, Map<String, dynamic> updates) async {
    // 更新本地存储
    final box = HiveConfig.getTransactionsBox();
    final transaction = box.get(id);

    if (transaction != null) {
      // 应用更新
      final updatedData = transaction.toJson();
      updates.forEach((key, value) {
        updatedData[key] = value;
      });

      final updatedTransaction = Transaction.fromJson(updatedData);
      await box.put(id, updatedTransaction);

      // 添加到待处理操作
      final operation = PendingOperation(
        id: id,
        type: OperationType.updateTransaction,
        data: updates,
        timestamp: DateTime.now(),
      );

      _pendingOperations.add(operation);
      await _savePendingOperations();

      debugPrint('离线更新交易: $id');
    }
  }

  /// 离线删除交易
  Future<void> deleteTransactionOffline(String id) async {
    // 从本地存储删除
    await HiveConfig.getTransactionsBox().delete(id);

    // 如果是本地创建的交易，直接从待处理操作中移除
    if (id.startsWith('offline_')) {
      _pendingOperations.removeWhere((op) => op.id == id);
      await _savePendingOperations();
      debugPrint('删除离线交易: $id');
      return;
    }

    // 否则添加删除操作
    final operation = PendingOperation(
      id: id,
      type: OperationType.deleteTransaction,
      data: {'id': id},
      timestamp: DateTime.now(),
    );

    _pendingOperations.add(operation);
    await _savePendingOperations();

    debugPrint('离线删除交易: $id');
  }

  /// 离线创建账户
  Future<String> createAccountOffline(Account account) async {
    final localId =
        'offline_${DateTime.now().millisecondsSinceEpoch}_${account.hashCode}';
    final offlineAccount = account.copyWith(id: localId);

    // 保存到本地存储
    await HiveConfig.getAccountsBox().put(localId, offlineAccount);

    // 添加到待处理操作
    final operation = PendingOperation(
      id: localId,
      type: OperationType.createAccount,
      data: offlineAccount.toJson(),
      timestamp: DateTime.now(),
    );

    _pendingOperations.add(operation);
    await _savePendingOperations();

    debugPrint('离线创建账户: $localId');
    return localId;
  }

  /// 处理待处理的操作
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty || !_isOnline) {
      return;
    }

    debugPrint('开始处理${_pendingOperations.length}个待处理操作');

    final operations = List<PendingOperation>.from(_pendingOperations);
    final failedOperations = <PendingOperation>[];

    for (final operation in operations) {
      try {
        await _processOperation(operation);
        _pendingOperations.remove(operation);
        debugPrint('处理操作成功: ${operation.id}');
      } catch (e) {
        debugPrint('处理操作失败: ${operation.id}, 错误: $e');
        failedOperations.add(operation);
      }
    }

    // 保存失败的操作
    await _savePendingOperations();

    if (failedOperations.isEmpty) {
      debugPrint('所有待处理操作已成功处理');
    } else {
      debugPrint('${failedOperations.length}个操作处理失败，将稍后重试');
    }
  }

  /// 处理单个操作
  Future<void> _processOperation(PendingOperation operation) async {
    final syncService = SyncService.instance;

    switch (operation.type) {
      case OperationType.createTransaction:
        // 这里需要调用实际的API服务
        // final transactionService = TransactionService();
        // final transaction = Transaction.fromJson(operation.data);
        // await transactionService.createTransaction(transaction);
        break;

      case OperationType.updateTransaction:
        // final transactionService = TransactionService();
        // await transactionService.updateTransaction(operation.id, operation.data);
        break;

      case OperationType.deleteTransaction:
        // final transactionService = TransactionService();
        // await transactionService.deleteTransaction(operation.id);
        break;

      case OperationType.createAccount:
        // final accountService = AccountService();
        // final account = Account.fromJson(operation.data);
        // await accountService.createAccount(account);
        break;

      case OperationType.updateAccount:
        // final accountService = AccountService();
        // await accountService.updateAccount(operation.id, operation.data);
        break;

      case OperationType.deleteAccount:
        // final accountService = AccountService();
        // await accountService.deleteAccount(operation.id);
        break;
    }
  }

  /// 加载待处理操作
  Future<void> _loadPendingOperations() async {
    try {
      final operations =
          HiveConfig.getSetting<List>('pending_operations') ?? [];
      _pendingOperations.clear();

      for (final operationData in operations) {
        if (operationData is Map<String, dynamic>) {
          _pendingOperations.add(PendingOperation.fromJson(operationData));
        }
      }

      debugPrint('加载${_pendingOperations.length}个待处理操作');
    } catch (e) {
      debugPrint('加载待处理操作失败: $e');
    }
  }

  /// 保存待处理操作
  Future<void> _savePendingOperations() async {
    try {
      final operationsData =
          _pendingOperations.map((op) => op.toJson()).toList();
      await HiveConfig.saveSetting('pending_operations', operationsData);
    } catch (e) {
      debugPrint('保存待处理操作失败: $e');
    }
  }

  /// 清除所有待处理操作
  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    await _savePendingOperations();
    debugPrint('已清除所有待处理操作');
  }

  /// 手动同步待处理操作
  Future<void> syncPendingOperations() async {
    if (!_isOnline) {
      throw OfflineException('当前处于离线状态，无法同步');
    }

    await _processPendingOperations();
  }

  /// 获取离线数据统计
  OfflineDataStats getOfflineDataStats() {
    final transactionsBox = HiveConfig.getTransactionsBox();
    final accountsBox = HiveConfig.getAccountsBox();

    final offlineTransactions = transactionsBox.values
        .where((t) => t.id?.startsWith('offline_') == true)
        .length;

    final offlineAccounts = accountsBox.values
        .where((a) => a.id?.startsWith('offline_') == true)
        .length;

    return OfflineDataStats(
      pendingOperations: _pendingOperations.length,
      offlineTransactions: offlineTransactions,
      offlineAccounts: offlineAccounts,
      lastSyncTime: HiveConfig.getSetting<String>('last_sync_time') != null
          ? DateTime.parse(HiveConfig.getSetting<String>('last_sync_time')!)
          : null,
    );
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}

/// 待处理操作
class PendingOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'],
      type: OperationType.values.firstWhere(
        (t) => t.toString() == json['type'],
        orElse: () => OperationType.createTransaction,
      ),
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retry_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
    };
  }
}

/// 操作类型枚举
enum OperationType {
  createTransaction,
  updateTransaction,
  deleteTransaction,
  createAccount,
  updateAccount,
  deleteAccount,
}

/// 离线数据统计
class OfflineDataStats {
  final int pendingOperations;
  final int offlineTransactions;
  final int offlineAccounts;
  final DateTime? lastSyncTime;

  OfflineDataStats({
    required this.pendingOperations,
    required this.offlineTransactions,
    required this.offlineAccounts,
    this.lastSyncTime,
  });
}

/// 离线异常
class OfflineException implements Exception {
  final String message;

  OfflineException(this.message);

  @override
  String toString() => 'OfflineException: $message';
}
