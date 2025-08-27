// 预算状态管理
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/budget_service.dart';
import '../models/budget.dart';

/// 预算状态
class BudgetState {
  final List<Budget> budgets;
  final Budget? selectedBudget;
  final bool isLoading;
  final String? error;
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;

  const BudgetState({
    this.budgets = const [],
    this.selectedBudget,
    this.isLoading = false,
    this.error,
    this.totalBudgeted = 0.0,
    this.totalSpent = 0.0,
    this.totalRemaining = 0.0,
  });

  BudgetState copyWith({
    List<Budget>? budgets,
    Budget? selectedBudget,
    bool? isLoading,
    String? error,
    double? totalBudgeted,
    double? totalSpent,
    double? totalRemaining,
  }) {
    return BudgetState(
      budgets: budgets ?? this.budgets,
      selectedBudget: selectedBudget ?? this.selectedBudget,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalBudgeted: totalBudgeted ?? this.totalBudgeted,
      totalSpent: totalSpent ?? this.totalSpent,
      totalRemaining: totalRemaining ?? this.totalRemaining,
    );
  }
}

/// 预算控制器
class BudgetController extends StateNotifier<BudgetState> {
  final BudgetService _budgetService;

  BudgetController(this._budgetService) : super(const BudgetState()) {
    loadBudgets();
  }

  /// 加载预算列表
  Future<void> loadBudgets() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final budgets = await _budgetService.getBudgets();
      await _updateBudgetSpending(budgets);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新预算列表
  Future<void> refresh() async {
    await loadBudgets();
  }

  /// 创建预算
  Future<bool> createBudget(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final budget = await _budgetService.createBudget(data);
      final updatedBudgets = [...state.budgets, budget];
      await _updateBudgetSpending(updatedBudgets);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 更新预算
  Future<bool> updateBudget(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final updatedBudget = await _budgetService.updateBudget(id, data);
      final updatedBudgets = state.budgets.map((b) {
        return b.id == id ? updatedBudget : b;
      }).toList();
      await _updateBudgetSpending(updatedBudgets);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 删除预算
  Future<bool> deleteBudget(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _budgetService.deleteBudget(id);
      final updatedBudgets = state.budgets.where((b) => b.id != id).toList();
      await _updateBudgetSpending(updatedBudgets);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 选择预算
  void selectBudget(Budget? budget) {
    state = state.copyWith(selectedBudget: budget);
  }

  /// 获取预算进度
  double getBudgetProgress(Budget budget) {
    if (budget.amount <= 0) return 0;
    return (budget.spent / budget.amount).clamp(0.0, 1.5);
  }

  /// 获取预算状态
  BudgetStatus getBudgetStatus(Budget budget) {
    final progress = getBudgetProgress(budget);
    if (progress >= 1.0) {
      return BudgetStatus.overBudget;
    } else if (progress >= 0.8) {
      return BudgetStatus.warning;
    } else if (progress >= 0.6) {
      return BudgetStatus.normal;
    } else {
      return BudgetStatus.good;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 更新预算支出并计算统计数据
  Future<void> _updateBudgetSpending(List<Budget> budgets) async {
    try {
      // 获取每个预算的实际支出
      final updatedBudgets = await Future.wait(
        budgets.map((budget) async {
          final spending = await _budgetService.getBudgetSpending(
            budget.id,
            budget.startDate,
            budget.endDate ?? DateTime.now(),
          );
          return budget.copyWith(spent: spending);
        }),
      );

      double totalBudgeted = 0;
      double totalSpent = 0;

      for (final budget in updatedBudgets) {
        totalBudgeted += budget.amount;
        totalSpent += budget.spent;
      }

      state = state.copyWith(
        budgets: updatedBudgets,
        isLoading: false,
        error: null,
        totalBudgeted: totalBudgeted,
        totalSpent: totalSpent,
        totalRemaining: totalBudgeted - totalSpent,
      );
    } catch (e) {
      state = state.copyWith(
        budgets: budgets,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// 预算状态枚举
enum BudgetStatus {
  good,      // 0-60%
  normal,    // 60-80%
  warning,   // 80-100%
  overBudget // >100%
}

/// Provider定义
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService();
});

final budgetControllerProvider = 
    StateNotifierProvider<BudgetController, BudgetState>((ref) {
  final service = ref.watch(budgetServiceProvider);
  return BudgetController(service);
});

/// 便捷访问
final budgetsProvider = Provider<List<Budget>>((ref) {
  return ref.watch(budgetControllerProvider).budgets;
});

final selectedBudgetProvider = Provider<Budget?>((ref) {
  return ref.watch(budgetControllerProvider).selectedBudget;
});

/// 活跃预算Provider（当前周期内的预算）
final activeBudgetsProvider = Provider<List<Budget>>((ref) {
  final budgets = ref.watch(budgetsProvider);
  final now = DateTime.now();
  
  return budgets.where((budget) {
    final isStarted = budget.startDate.isBefore(now) || 
                     budget.startDate.isAtSameMomentAs(now);
    final isNotEnded = budget.endDate == null || 
                       budget.endDate!.isAfter(now) ||
                       budget.endDate!.isAtSameMomentAs(now);
    return isStarted && isNotEnded;
  }).toList();
});

/// 超支预算Provider
final overBudgetsProvider = Provider<List<Budget>>((ref) {
  final budgets = ref.watch(activeBudgetsProvider);
  final controller = ref.read(budgetControllerProvider.notifier);
  
  return budgets.where((budget) {
    return controller.getBudgetStatus(budget) == BudgetStatus.overBudget;
  }).toList();
});

/// 预算统计Provider
final budgetStatsProvider = Provider<BudgetStats>((ref) {
  final state = ref.watch(budgetControllerProvider);
  final controller = ref.read(budgetControllerProvider.notifier);
  
  int overBudgetCount = 0;
  int warningCount = 0;
  int normalCount = 0;
  int goodCount = 0;
  
  for (final budget in state.budgets) {
    final status = controller.getBudgetStatus(budget);
    switch (status) {
      case BudgetStatus.overBudget:
        overBudgetCount++;
        break;
      case BudgetStatus.warning:
        warningCount++;
        break;
      case BudgetStatus.normal:
        normalCount++;
        break;
      case BudgetStatus.good:
        goodCount++;
        break;
    }
  }
  
  return BudgetStats(
    totalBudgets: state.budgets.length,
    totalBudgeted: state.totalBudgeted,
    totalSpent: state.totalSpent,
    totalRemaining: state.totalRemaining,
    overBudgetCount: overBudgetCount,
    warningCount: warningCount,
    normalCount: normalCount,
    goodCount: goodCount,
  );
});

/// 预算统计数据
class BudgetStats {
  final int totalBudgets;
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;
  final int overBudgetCount;
  final int warningCount;
  final int normalCount;
  final int goodCount;

  const BudgetStats({
    required this.totalBudgets,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overBudgetCount,
    required this.warningCount,
    required this.normalCount,
    required this.goodCount,
  });

  double get spentPercentage => 
      totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0;
}

// 当前月份预算Provider
final currentMonthBudgetsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 从API获取当前月份的预算
  return [
    {
      'id': '1',
      'name': '餐饮预算',
      'category': '餐饮',
      'amount': 3000.0,
      'spent': 1500.0,
    },
    {
      'id': '2',
      'name': '交通预算',
      'category': '交通',
      'amount': 800.0,
      'spent': 650.0,
    },
    {
      'id': '3',
      'name': '购物预算',
      'category': '购物',
      'amount': 2000.0,
      'spent': 1800.0,
    },
  ];
});

// 简单的budgets列表provider（用于兼容旧代码）
final simpleBudgetsProvider = FutureProvider<List<dynamic>>((ref) async {
  // TODO: 从API获取所有预算
  return ref.watch(currentMonthBudgetsProvider).value ?? [];
});