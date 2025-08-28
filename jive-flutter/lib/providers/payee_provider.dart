import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payee.dart';

/// 交易对方状态管理 - 基于Riverpod
class PayeeNotifier extends StateNotifier<List<Payee>> {
  PayeeNotifier() : super([]) {
    _loadPayees();
  }

  void _loadPayees() {
    // TODO: 从存储加载交易对方，目前使用示例数据
    state = [
      // 家庭成员
      Payee(
        id: '1',
        name: '张三',
        color: PayeeColors.colors[0],
        payeeType: PayeeType.familyPayee,
        source: PayeeSource.manual,
        transactionsCount: 25,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      Payee(
        id: '2',
        name: '李四',
        color: PayeeColors.colors[1], 
        payeeType: PayeeType.familyPayee,
        source: PayeeSource.manual,
        transactionsCount: 18,
        createdAt: DateTime.now().subtract(const Duration(days: 50)),
      ),
      
      // 商户
      Payee(
        id: '3',
        name: '星巴克',
        color: PayeeColors.colors[2],
        payeeType: PayeeType.providerPayee,
        source: PayeeSource.ai,
        logo: 'starbucks_logo.png',
        website: 'https://starbucks.com',
        transactionsCount: 42,
        primaryCategoryId: 'dining',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      Payee(
        id: '4',
        name: '中国移动',
        color: PayeeColors.colors[3],
        payeeType: PayeeType.providerPayee,
        source: PayeeSource.manual,
        transactionsCount: 12,
        primaryCategoryId: 'utilities',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Payee(
        id: '5',
        name: '超市购物',
        color: PayeeColors.colors[4],
        payeeType: PayeeType.providerPayee,
        source: PayeeSource.synth,
        transactionsCount: 67,
        primaryCategoryId: 'groceries',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ];
  }

  /// 添加交易对方
  void addPayee(Payee payee) {
    final newPayee = payee.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = [...state, newPayee];
    // TODO: 保存到存储
  }

  /// 更新交易对方
  void updatePayee(Payee updatedPayee) {
    state = state.map((payee) {
      if (payee.id == updatedPayee.id) {
        return updatedPayee.copyWith(updatedAt: DateTime.now());
      }
      return payee;
    }).toList();
    // TODO: 保存到存储
  }

  /// 删除交易对方
  void deletePayee(String payeeId) {
    state = state.where((payee) => payee.id != payeeId).toList();
    // TODO: 保存到存储
  }

  /// 合并交易对方
  void mergePayees(String fromPayeeId, String toPayeeId) {
    final fromPayee = state.firstWhere((p) => p.id == fromPayeeId);
    final toPayee = state.firstWhere((p) => p.id == toPayeeId);
    
    // 更新目标交易对方的交易次数
    final updatedToPayee = toPayee.copyWith(
      transactionsCount: toPayee.transactionsCount + fromPayee.transactionsCount,
      updatedAt: DateTime.now(),
    );
    
    updatePayee(updatedToPayee);
    
    // TODO: 更新所有使用fromPayee的交易
    
    // 删除源交易对方
    deletePayee(fromPayeeId);
  }

  /// 更新交易次数
  void incrementTransactionCount(String payeeId) {
    state = state.map((payee) {
      if (payee.id == payeeId) {
        return payee.copyWith(
          transactionsCount: payee.transactionsCount + 1,
          updatedAt: DateTime.now(),
        );
      }
      return payee;
    }).toList();
    // TODO: 保存到存储
  }

  /// 设置主要分类
  void setPrimaryCategory(String payeeId, String categoryId) {
    state = state.map((payee) {
      if (payee.id == payeeId) {
        return payee.copyWith(
          primaryCategoryId: categoryId,
          updatedAt: DateTime.now(),
        );
      }
      return payee;
    }).toList();
    // TODO: 保存到存储
  }

  /// 重新排序交易对方
  void reorderPayees(List<Payee> reorderedPayees) {
    final updatedPayees = <Payee>[];
    for (int i = 0; i < reorderedPayees.length; i++) {
      updatedPayees.add(reorderedPayees[i].copyWith(
        position: i,
        updatedAt: DateTime.now(),
      ));
    }
    state = updatedPayees;
    // TODO: 保存到存储
  }

  /// 搜索交易对方
  List<Payee> searchPayees(String query) {
    if (query.isEmpty) return state;
    
    final lowerQuery = query.toLowerCase();
    return state.where((payee) =>
      payee.name.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}

/// 交易对方Provider
final payeesProvider = StateNotifierProvider<PayeeNotifier, List<Payee>>((ref) {
  return PayeeNotifier();
});

/// 按类型过滤的交易对方Provider
final payeesByTypeProvider = Provider.family<List<Payee>, PayeeType>((ref, type) {
  final payees = ref.watch(payeesProvider);
  return payees.where((payee) => payee.payeeType == type).toList();
});

/// 家庭成员Provider
final familyPayeesProvider = Provider<List<Payee>>((ref) {
  return ref.watch(payeesByTypeProvider(PayeeType.familyPayee));
});

/// 商户Provider
final providerPayeesProvider = Provider<List<Payee>>((ref) {
  return ref.watch(payeesByTypeProvider(PayeeType.providerPayee));
});

/// 常用交易对方Provider（按交易次数排序）
final popularPayeesProvider = Provider<List<Payee>>((ref) {
  final payees = ref.watch(payeesProvider);
  final sortedPayees = [...payees];
  sortedPayees.sort((a, b) => b.transactionsCount.compareTo(a.transactionsCount));
  return sortedPayees.take(10).toList();
});

/// 最近添加的交易对方Provider
final recentPayeesProvider = Provider<List<Payee>>((ref) {
  final payees = ref.watch(payeesProvider);
  final sortedPayees = [...payees];
  sortedPayees.sort((a, b) {
    final aTime = a.createdAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return sortedPayees.take(5).toList();
});

/// 按来源分类的交易对方Provider
final payeesBySourceProvider = Provider.family<List<Payee>, PayeeSource>((ref, source) {
  final payees = ref.watch(payeesProvider);
  return payees.where((payee) => payee.source == source).toList();
});