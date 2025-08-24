// 账户状态管理
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/account_service.dart';
import '../models/account.dart';

/// 账户状态
class AccountState {
  final List<Account> accounts;
  final Account? selectedAccount;
  final bool isLoading;
  final String? error;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  const AccountState({
    this.accounts = const [],
    this.selectedAccount,
    this.isLoading = false,
    this.error,
    this.totalAssets = 0.0,
    this.totalLiabilities = 0.0,
    this.netWorth = 0.0,
  });

  AccountState copyWith({
    List<Account>? accounts,
    Account? selectedAccount,
    bool? isLoading,
    String? error,
    double? totalAssets,
    double? totalLiabilities,
    double? netWorth,
  }) {
    return AccountState(
      accounts: accounts ?? this.accounts,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      totalAssets: totalAssets ?? this.totalAssets,
      totalLiabilities: totalLiabilities ?? this.totalLiabilities,
      netWorth: netWorth ?? this.netWorth,
    );
  }
}

/// 账户控制器
class AccountController extends StateNotifier<AccountState> {
  final AccountService _accountService;

  AccountController(this._accountService) : super(const AccountState()) {
    loadAccounts();
  }

  /// 加载账户列表
  Future<void> loadAccounts() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final accounts = await _accountService.getAccounts();
      _updateState(accounts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新账户列表
  Future<void> refresh() async {
    await loadAccounts();
  }

  /// 创建账户
  Future<bool> createAccount(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final account = await _accountService.createAccount(data);
      final updatedAccounts = [...state.accounts, account];
      _updateState(updatedAccounts);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 更新账户
  Future<bool> updateAccount(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final updatedAccount = await _accountService.updateAccount(id, data);
      final updatedAccounts = state.accounts.map((a) {
        return a.id == id ? updatedAccount : a;
      }).toList();
      _updateState(updatedAccounts);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 删除账户
  Future<bool> deleteAccount(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _accountService.deleteAccount(id);
      final updatedAccounts = state.accounts.where((a) => a.id != id).toList();
      _updateState(updatedAccounts);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 选择账户
  void selectAccount(Account? account) {
    state = state.copyWith(selectedAccount: account);
  }

  /// 更新账户余额
  Future<bool> updateBalance(String id, double balance) async {
    return updateAccount(id, {'balance': balance});
  }

  /// 转账
  Future<bool> transfer(String fromId, String toId, double amount, String? note) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _accountService.transfer(fromId, toId, amount, note);
      await loadAccounts(); // 重新加载以更新余额
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 更新状态并计算统计数据
  void _updateState(List<Account> accounts) {
    double totalAssets = 0;
    double totalLiabilities = 0;

    for (final account in accounts) {
      if (account.type == AccountType.asset) {
        totalAssets += account.balance;
      } else if (account.type == AccountType.liability) {
        totalLiabilities += account.balance.abs();
      }
    }

    state = state.copyWith(
      accounts: accounts,
      isLoading: false,
      error: null,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: totalAssets - totalLiabilities,
    );
  }
}

/// Provider定义
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService();
});

final accountControllerProvider = 
    StateNotifierProvider<AccountController, AccountState>((ref) {
  final service = ref.watch(accountServiceProvider);
  return AccountController(service);
});

/// 便捷访问
final accountsProvider = Provider<List<Account>>((ref) {
  return ref.watch(accountControllerProvider).accounts;
});

final selectedAccountProvider = Provider<Account?>((ref) {
  return ref.watch(accountControllerProvider).selectedAccount;
});

final netWorthProvider = Provider<double>((ref) {
  return ref.watch(accountControllerProvider).netWorth;
});

/// 按类型分组的账户Provider
final accountsByTypeProvider = Provider<Map<AccountType, List<Account>>>((ref) {
  final accounts = ref.watch(accountsProvider);
  final Map<AccountType, List<Account>> grouped = {};
  
  for (final account in accounts) {
    grouped.putIfAbsent(account.type, () => []).add(account);
  }
  
  return grouped;
});

/// 账户统计Provider
final accountStatsProvider = Provider<AccountStats>((ref) {
  final state = ref.watch(accountControllerProvider);
  return AccountStats(
    totalAccounts: state.accounts.length,
    totalAssets: state.totalAssets,
    totalLiabilities: state.totalLiabilities,
    netWorth: state.netWorth,
  );
});

/// 账户统计数据
class AccountStats {
  final int totalAccounts;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  const AccountStats({
    required this.totalAccounts,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });
}