import 'package:flutter/material.dart';

void main() {
  runApp(const JiveApp());
}

class JiveApp extends StatelessWidget {
  const JiveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jive - 个人财务管理',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Transaction> _transactions = [
    Transaction(id: '1', description: '午餐', amount: -28.50, category: '餐饮', date: DateTime.now().subtract(const Duration(days: 1))),
    Transaction(id: '2', description: '工资', amount: 8500.00, category: '收入', date: DateTime.now().subtract(const Duration(days: 5))),
    Transaction(id: '3', description: '地铁卡充值', amount: -100.00, category: '交通', date: DateTime.now().subtract(const Duration(days: 2))),
    Transaction(id: '4', description: '购物', amount: -259.80, category: '购物', date: DateTime.now().subtract(const Duration(days: 3))),
    Transaction(id: '5', description: '电影票', amount: -68.00, category: '娱乐', date: DateTime.now().subtract(const Duration(days: 1))),
  ];

  final List<Account> _accounts = [
    Account(id: '1', name: '工商银行', type: '储蓄卡', balance: 15680.50, currency: 'CNY'),
    Account(id: '2', name: '支付宝', type: '电子钱包', balance: 892.30, currency: 'CNY'),
    Account(id: '3', name: '招商银行信用卡', type: '信用卡', balance: -2150.00, currency: 'CNY'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jive 财务管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            transactions: _transactions,
            accounts: _accounts,
          ),
          TransactionsScreen(transactions: _transactions),
          AccountsScreen(accounts: _accounts),
          const BudgetsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: '仪表板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: '交易',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '账户',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: '预算',
          ),
        ],
      ),
    );
  }
}

// 数据模型
class Transaction {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });
}

class Account {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String currency;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.currency,
  });
}

// 仪表板界面
class DashboardScreen extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Account> accounts;

  const DashboardScreen({
    Key? key,
    required this.transactions,
    required this.accounts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalBalance = accounts.fold(0.0, (sum, account) => sum + account.balance);
    final thisMonthSpending = transactions
        .where((t) => t.amount < 0 && isThisMonth(t.date))
        .fold(0.0, (sum, t) => sum + t.amount.abs());
    final thisMonthIncome = transactions
        .where((t) => t.amount > 0 && isThisMonth(t.date))
        .fold(0.0, (sum, t) => sum + t.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总览卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总资产',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${totalBalance.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: totalBalance >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 本月统计
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本月收入',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '¥${thisMonthIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本月支出',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '¥${thisMonthSpending.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 最近交易
          Text(
            '最近交易',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.take(5).length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: transaction.amount >= 0 ? Colors.green : Colors.red,
                    child: Icon(
                      transaction.amount >= 0 ? Icons.add : Icons.remove,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(transaction.description),
                  subtitle: Text(transaction.category),
                  trailing: Text(
                    '${transaction.amount >= 0 ? '+' : ''}¥${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: transaction.amount >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }
}

// 交易界面
class TransactionsScreen extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionsScreen({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '交易记录',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => _showAddTransactionDialog(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: transaction.amount >= 0 ? Colors.green : Colors.red,
                    child: Icon(
                      _getCategoryIcon(transaction.category),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(transaction.description),
                  subtitle: Text(
                    '${transaction.category} • ${_formatDate(transaction.date)}',
                  ),
                  trailing: Text(
                    '${transaction.amount >= 0 ? '+' : ''}¥${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: transaction.amount >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '餐饮': return Icons.restaurant;
      case '交通': return Icons.directions_car;
      case '购物': return Icons.shopping_bag;
      case '娱乐': return Icons.movie;
      case '收入': return Icons.monetization_on;
      default: return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  void _showAddTransactionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加交易'),
        content: const Text('交易添加功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// 账户界面
class AccountsScreen extends StatelessWidget {
  final List<Account> accounts;

  const AccountsScreen({Key? key, required this.accounts}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '账户管理',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => _showAddAccountDialog(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: accounts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAccountTypeColor(account.type),
                    child: Icon(
                      _getAccountTypeIcon(account.type),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(account.name),
                  subtitle: Text(account.type),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${account.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: account.balance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        account.currency,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getAccountTypeColor(String type) {
    switch (type) {
      case '储蓄卡': return Colors.blue;
      case '信用卡': return Colors.orange;
      case '电子钱包': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case '储蓄卡': return Icons.account_balance;
      case '信用卡': return Icons.credit_card;
      case '电子钱包': return Icons.account_balance_wallet;
      default: return Icons.account_box;
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加账户'),
        content: const Text('账户添加功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// 预算界面
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final budgets = [
      {'category': '餐饮', 'budgeted': 2000.0, 'spent': 1250.0},
      {'category': '交通', 'budgeted': 500.0, 'spent': 380.0},
      {'category': '购物', 'budgeted': 1500.0, 'spent': 1680.0},
      {'category': '娱乐', 'budgeted': 800.0, 'spent': 520.0},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '预算管理',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => _showAddBudgetDialog(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final budgeted = budget['budgeted'] as double;
              final spent = budget['spent'] as double;
              final progress = spent / budgeted;
              final isOverBudget = progress > 1.0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            budget['category'] as String,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '¥${spent.toStringAsFixed(0)} / ¥${budgeted.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: isOverBudget ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% ${isOverBudget ? '(超支)' : ''}',
                        style: TextStyle(
                          color: isOverBudget ? Colors.red : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加预算'),
        content: const Text('预算添加功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}