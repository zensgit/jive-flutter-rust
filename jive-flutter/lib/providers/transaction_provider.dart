// 交易状态管理
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/services/api/transaction_service.dart';
import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/models/transaction_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jive_money/providers/ledger_provider.dart';

enum TransactionGrouping { date, category, account }

/// 交易状态
class TransactionState {
  final List<Transaction> transactions;
  final List<Transaction> filteredTransactions;
  final TransactionFilterData? filter;
  final bool isLoading;
  final String? error;
  final int totalCount;
  final double totalIncome;
  final double totalExpense;
  final TransactionGrouping grouping;
  final Set<String> groupCollapse;

  const TransactionState({
    this.transactions = const [],
    this.filteredTransactions = const [],
    this.filter,
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.grouping = TransactionGrouping.date,
    this.groupCollapse = const {},
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    List<Transaction>? filteredTransactions,
    TransactionFilterData? filter,
    bool? isLoading,
    String? error,
    int? totalCount,
    double? totalIncome,
    double? totalExpense,
    TransactionGrouping? grouping,
    Set<String>? groupCollapse,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalCount: totalCount ?? this.totalCount,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      grouping: grouping ?? this.grouping,
      groupCollapse: groupCollapse ?? this.groupCollapse,
    );
  }
}

/// 交易控制器
class TransactionController extends StateNotifier<TransactionState> {
  final TransactionService _transactionService;

  TransactionController(this._transactionService)
      : super(const TransactionState()) {
    loadTransactions();
  }

  /// 设置分组方式并持久化
  Future<void> setGrouping(TransactionGrouping grouping) async {
    // 更新状态
    state = state.copyWith(grouping: grouping);

    // 持久化到 SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (grouping) {
        TransactionGrouping.date => 'date',
        TransactionGrouping.category => 'category',
        TransactionGrouping.account => 'account',
      };
      await prefs.setString('tx_grouping', value);
    } catch (_) {
      // 忽略持久化异常以避免影响 UI 流程
    }
  }

  /// 切换某个分组的折叠状态并持久化
  Future<void> toggleGroupCollapse(String key) async {
    final next = Set<String>.from(state.groupCollapse);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }

    // 更新状态
    state = state.copyWith(groupCollapse: next);

    // 持久化到 SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tx_group_collapse', next.toList());
    } catch (_) {
      // 忽略持久化异常
    }
  }

  /// 加载交易列表
  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _transactionService.getTransactions();
      _updateState(response.data);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新交易列表
  Future<void> refresh() async {
    await loadTransactions();
  }

  /// 添加交易
  Future<bool> addTransaction(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Convert the data to Transaction object
      final transaction = Transaction.fromJson(data);
      final createdTransaction =
          await _transactionService.createTransaction(transaction);
      final updatedTransactions = [createdTransaction, ...state.transactions];
      _updateState(updatedTransactions);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 更新交易
  Future<bool> updateTransaction(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedTransaction =
          await _transactionService.updateTransaction(id, data);
      final updatedTransactions = state.transactions.map((t) {
        return t.id == id ? updatedTransaction : t;
      }).toList();
      _updateState(updatedTransactions);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 删除交易
  Future<bool> deleteTransaction(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _transactionService.deleteTransaction(id);
      final updatedTransactions =
          state.transactions.where((t) => t.id != id).toList();
      _updateState(updatedTransactions);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 批量删除交易
  Future<bool> deleteTransactions(List<String> ids) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _transactionService.deleteBulkTransactions(ids);
      final updatedTransactions =
          state.transactions.where((t) => !ids.contains(t.id)).toList();
      _updateState(updatedTransactions);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 应用筛选
  void applyFilter(TransactionFilterData filter) {
    final filteredTransactions =
        _filterTransactions(state.transactions, filter);
    state = state.copyWith(
      filter: filter,
      filteredTransactions: filteredTransactions,
    );
  }

  /// 清除筛选
  void clearFilter() {
    state = state.copyWith(
      filter: null,
      filteredTransactions: state.transactions,
    );
  }

  /// 搜索交易
  void search(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        filteredTransactions: state.filter != null
            ? _filterTransactions(state.transactions, state.filter!)
            : state.transactions,
      );
      return;
    }

    final filtered = state.transactions.where((t) {
      final searchLower = query.toLowerCase();
      return t.description.toLowerCase().contains(searchLower) ||
          (t.note?.toLowerCase().contains(searchLower) ?? false) ||
          (t.payee?.toLowerCase().contains(searchLower) ?? false);
    }).toList();

    state = state.copyWith(filteredTransactions: filtered);
  }

  /// 按日期范围筛选
  void filterByDateRange(DateTime start, DateTime end) {
    final filtered = state.transactions.where((t) {
      return t.date.isAfter(start.subtract(const Duration(days: 1))) &&
          t.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    state = state.copyWith(filteredTransactions: filtered);
  }

  /// 按分类筛选
  void filterByCategory(String category) {
    final filtered = state.transactions.where((t) {
      return t.category == category;
    }).toList();

    state = state.copyWith(filteredTransactions: filtered);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 更新状态并计算统计数据
  void _updateState(List<Transaction> transactions) {
    final filteredTransactions = state.filter != null
        ? _filterTransactions(transactions, state.filter!)
        : transactions;

    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }

    state = state.copyWith(
      transactions: transactions,
      filteredTransactions: filteredTransactions,
      isLoading: false,
      error: null,
      totalCount: transactions.length,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  /// 筛选交易
  List<Transaction> _filterTransactions(
      List<Transaction> transactions, TransactionFilterData filter) {
    return transactions.where((t) {
      // 类型筛选
      if (filter.types.isNotEmpty && !filter.types.contains(t.type)) {
        return false;
      }

      // 日期范围筛选
      if (filter.startDate != null && t.date.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && t.date.isAfter(filter.endDate!)) {
        return false;
      }

      // 金额范围筛选
      if (filter.minAmount != null && t.amount < filter.minAmount!) {
        return false;
      }
      if (filter.maxAmount != null && t.amount > filter.maxAmount!) {
        return false;
      }

      // 账户筛选
      if (filter.accounts.isNotEmpty &&
          !filter.accounts.contains(t.accountId)) {
        return false;
      }

      // 分类筛选
      if (filter.categories.isNotEmpty &&
          !filter.categories.contains(t.category)) {
        return false;
      }

      // 标签筛选
      if (filter.tags.isNotEmpty) {
        final hasTag = filter.tags.any((tag) => t.tags?.contains(tag) == true);
        if (!hasTag) return false;
      }

      // 搜索文本
      if (filter.searchText != null && filter.searchText!.isNotEmpty) {
        final searchLower = filter.searchText!.toLowerCase();
        final matchesSearch =
            t.description.toLowerCase().contains(searchLower) ||
                (t.note?.toLowerCase().contains(searchLower) ?? false) ||
                (t.payee?.toLowerCase().contains(searchLower) ?? false);
        if (!matchesSearch) return false;
      }

      return true;
    }).toList();
  }
}

/// Provider定义
final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService();
});

final transactionControllerProvider =
    StateNotifierProvider<TransactionController, TransactionState>((ref) {
  final service = ref.watch(transactionServiceProvider);
  return TransactionController(service);
});

/// 便捷访问
final transactionsProvider = Provider<List<Transaction>>((ref) {
  return ref.watch(transactionControllerProvider).filteredTransactions;
});

final transactionStatsProvider = Provider<TransactionStats>((ref) {
  final state = ref.watch(transactionControllerProvider);
  return TransactionStats(
    totalCount: state.totalCount,
    totalIncome: state.totalIncome,
    totalExpense: state.totalExpense,
    netIncome: state.totalIncome - state.totalExpense,
  );
});

/// 最近交易Provider
final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  return transactions.take(10).toList();
});

/// 按月份分组的交易Provider
final transactionsByMonthProvider =
    Provider<Map<String, List<Transaction>>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final Map<String, List<Transaction>> grouped = {};

  for (final transaction in transactions) {
    final key =
        '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
    grouped.putIfAbsent(key, () => []).add(transaction);
  }

  return grouped;
});

/// 交易统计数据
class TransactionStats {
  final int totalCount;
  final double totalIncome;
  final double totalExpense;
  final double netIncome;

  const TransactionStats({
    required this.totalCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.netIncome,
  });
}
