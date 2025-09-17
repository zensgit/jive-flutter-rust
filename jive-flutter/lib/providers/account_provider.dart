// 账户状态管理
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api/account_service.dart';
import '../services/sync/sync_service.dart';
import '../models/account.dart';

/// 账户状态
class AccountState {
  final List<Account> accounts;
  final List<AccountGroup> groups;
  final Account? selectedAccount;
  final bool isLoading;
  final String? errorMessage;
  final String? currentLedgerId;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  const AccountState({
    this.accounts = const [],
    this.groups = const [],
    this.selectedAccount,
    this.isLoading = false,
    this.errorMessage,
    this.currentLedgerId,
    this.totalAssets = 0.0,
    this.totalLiabilities = 0.0,
    this.netWorth = 0.0,
  });

  AccountState copyWith({
    List<Account>? accounts,
    List<AccountGroup>? groups,
    Account? selectedAccount,
    bool? isLoading,
    String? errorMessage,
    String? currentLedgerId,
    double? totalAssets,
    double? totalLiabilities,
    double? netWorth,
  }) {
    return AccountState(
      accounts: accounts ?? this.accounts,
      groups: groups ?? this.groups,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      currentLedgerId: currentLedgerId ?? this.currentLedgerId,
      totalAssets: totalAssets ?? this.totalAssets,
      totalLiabilities: totalLiabilities ?? this.totalLiabilities,
      netWorth: netWorth ?? this.netWorth,
    );
  }
}

/// 账户Provider
class AccountNotifier extends StateNotifier<AccountState> {
  final AccountService _accountService;
  final SyncService _syncService;

  AccountNotifier(this._accountService, this._syncService)
      : super(const AccountState()) {
    loadAccounts();
  }

  /// 加载账户列表
  Future<void> loadAccounts({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      // 先从缓存加载
      if (!refresh) {
        final cachedAccounts = await _loadCachedAccounts();
        if (cachedAccounts.isNotEmpty) {
          state = state.copyWith(
            accounts: cachedAccounts,
            isLoading: false,
          );
        }
      }

      // 从 API加载
      final accounts = await _accountService.getAllAccounts(
        ledgerId: state.currentLedgerId,
      );

      // 缓存数据
      await _cacheAccounts(accounts);

      state = state.copyWith(
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新账户列表
  Future<void> refresh() async {
    await loadAccounts(refresh: true);
  }

  /// 创建账户
  Future<bool> createAccount(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Convert the data to Account object
      final account = Account.fromJson(data);
      final response = await _accountService.createAccount(account);
      final updatedAccounts = [...state.accounts, response];
      _updateState(updatedAccounts);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 更新账户
  Future<bool> updateAccount(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

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
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 删除账户
  Future<bool> deleteAccount(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _accountService.deleteAccount(id);
      final updatedAccounts = state.accounts.where((a) => a.id != id).toList();
      _updateState(updatedAccounts);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
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
  Future<bool> transfer(
      String fromId, String toId, double amount, String? note) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // TODO: Implement transfer method in AccountService
      // await _accountService.transfer(fromId, toId, amount, note);
      await loadAccounts(); // 重新加载以更新余额
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// 加载缓存的账户
  Future<List<Account>> _loadCachedAccounts() async {
    // TODO: 实现从Hive加载缓存
    return [];
  }

  /// 缓存账户数据
  Future<void> _cacheAccounts(List<Account> accounts) async {
    // TODO: 实现保存到Hive缓存
  }

  /// 更新状态并计算统计数据
  void _updateState(List<Account> accounts) {
    double totalAssets = 0;
    double totalLiabilities = 0;

    for (final account in accounts) {
      if (account.type == AccountType.checking ||
          account.type == AccountType.savings ||
          account.type == AccountType.cash ||
          account.type == AccountType.investment) {
        totalAssets += account.balance;
      } else if (account.type == AccountType.creditCard ||
          account.type == AccountType.loan) {
        totalLiabilities += account.balance.abs();
      }
    }

    state = state.copyWith(
      accounts: accounts,
      isLoading: false,
      errorMessage: null,
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

final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  final accountService = ref.watch(accountServiceProvider);
  final syncService = SyncService.instance;
  return AccountNotifier(accountService, syncService);
});

/// 便捷访问
final accountsProvider = Provider<List<Account>>((ref) {
  return ref.watch(accountProvider).accounts;
});

final selectedAccountProvider = Provider<Account?>((ref) {
  return ref.watch(accountProvider).selectedAccount;
});

final netWorthProvider = Provider<double>((ref) {
  return ref.watch(accountProvider).netWorth;
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
  final state = ref.watch(accountProvider);
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
