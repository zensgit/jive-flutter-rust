import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/ledger_service.dart' as api;
import '../models/ledger.dart';

// 账本服务Provider
final ledgerServiceProvider = Provider<api.LedgerService>((ref) {
  return api.LedgerService();
});

// 所有账本列表
final ledgersProvider = FutureProvider<List<Ledger>>((ref) async {
  final service = ref.watch(ledgerServiceProvider);
  return await service.getAllLedgers();
});

// 当前账本状态
class CurrentLedgerNotifier extends StateNotifier<Ledger?> {
  final Ref ref;
  
  CurrentLedgerNotifier(this.ref) : super(null) {
    _loadCurrentLedger();
  }

  Future<void> _loadCurrentLedger() async {
    try {
      final service = ref.read(ledgerServiceProvider);
      final ledger = await service.getCurrentLedger();
      state = ledger;
    } catch (e) {
      // 如果没有当前账本，创建默认账本
      await _createDefaultLedger();
    }
  }

  Future<void> _createDefaultLedger() async {
    try {
      final service = ref.read(ledgerServiceProvider);
      final ledger = await service.createLedger(
        Ledger(
          name: '默认账本',
          type: LedgerType.personal,
          description: '个人日常收支',
          currency: 'CNY',
          isDefault: true,
        ),
      );
      state = ledger;
    } catch (e) {
      // 处理错误
      print('创建默认账本失败: $e');
    }
  }

  Future<void> switchLedger(Ledger ledger) async {
    try {
      final service = ref.read(ledgerServiceProvider);
      await service.setCurrentLedger(ledger.id!);
      state = ledger;
      
      // 刷新相关数据
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(budgetsProvider);
    } catch (e) {
      print('切换账本失败: $e');
    }
  }

  Future<void> createLedger({
    required String name,
    required LedgerType type,
    String? description,
    String currency = 'CNY',
  }) async {
    try {
      final service = ref.read(ledgerServiceProvider);
      final ledger = await service.createLedger(
        Ledger(
          name: name,
          type: type,
          description: description,
          currency: currency,
          isDefault: false,
        ),
      );
      
      // 刷新账本列表
      ref.invalidate(ledgersProvider);
      
      // 如果是第一个账本，设为当前
      if (state == null) {
        await switchLedger(ledger);
      }
    } catch (e) {
      throw Exception('创建账本失败: $e');
    }
  }

  Future<void> updateLedger(Ledger ledger) async {
    try {
      final service = ref.read(ledgerServiceProvider);
      await service.updateLedger(ledger);
      
      // 如果更新的是当前账本，更新状态
      if (state?.id == ledger.id) {
        state = ledger;
      }
      
      // 刷新账本列表
      ref.invalidate(ledgersProvider);
    } catch (e) {
      throw Exception('更新账本失败: $e');
    }
  }

  Future<void> deleteLedger(String ledgerId) async {
    try {
      final service = ref.read(ledgerServiceProvider);
      await service.deleteLedger(ledgerId);
      
      // 如果删除的是当前账本，切换到其他账本
      if (state?.id == ledgerId) {
        final ledgers = await ref.read(ledgersProvider.future);
        if (ledgers.isNotEmpty) {
          await switchLedger(ledgers.first);
        } else {
          await _createDefaultLedger();
        }
      }
      
      // 刷新账本列表
      ref.invalidate(ledgersProvider);
    } catch (e) {
      throw Exception('删除账本失败: $e');
    }
  }
}

// 当前账本Provider
final currentLedgerProvider = StateNotifierProvider<CurrentLedgerNotifier, Ledger?>((ref) {
  return CurrentLedgerNotifier(ref);
});

// 账本统计信息
final ledgerStatisticsProvider = FutureProvider.family<api.LedgerStatistics, String>((ref, ledgerId) async {
  final service = ref.watch(ledgerServiceProvider);
  return await service.getLedgerStatistics(ledgerId);
});

// 账本共享成员
final ledgerMembersProvider = FutureProvider.family<List<api.LedgerMember>, String>((ref, ledgerId) async {
  final service = ref.watch(ledgerServiceProvider);
  return await service.getLedgerMembers(ledgerId);
});

// 依赖的导入
// 需要导入account_provider, transaction_provider, budget_provider
final accountsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 实现账户数据获取
  return [];
});

final transactionsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 实现交易数据获取
  return [];
});

final budgetsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 实现预算数据获取
  return [];
});