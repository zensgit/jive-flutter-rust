import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const JiveApp());
}

class JiveApp extends StatelessWidget {
  const JiveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jive Money - 个人财务管理',
      theme: ThemeData(
        // 现代金融应用风格主题
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0), // 深蓝色，更专业
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF43A047),
          surface: const Color(0xFFF8FAF9),
          background: const Color(0xFFFFFFFF),
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.25),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 0),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.1),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const ResponsiveMainScreen(),
    );
  }
}

class ResponsiveMainScreen extends StatefulWidget {
  const ResponsiveMainScreen({Key? key}) : super(key: key);

  @override
  State<ResponsiveMainScreen> createState() => _ResponsiveMainScreenState();
}

class _ResponsiveMainScreenState extends State<ResponsiveMainScreen> {
  int _selectedIndex = 0;
  
  // 模拟数据
  final List<Transaction> _transactions = [
    Transaction(id: '1', description: '星巴克咖啡', amount: -35.80, category: '餐饮', date: DateTime.now().subtract(const Duration(hours: 2))),
    Transaction(id: '2', description: '工资发放', amount: 12500.00, category: '收入', date: DateTime.now().subtract(const Duration(days: 1))),
    Transaction(id: '3', description: '地铁充值', amount: -50.00, category: '交通', date: DateTime.now().subtract(const Duration(hours: 5))),
    Transaction(id: '4', description: '超市购物', amount: -128.60, category: '购物', date: DateTime.now().subtract(const Duration(days: 1))),
    Transaction(id: '5', description: '理财收益', amount: 85.30, category: '投资', date: DateTime.now().subtract(const Duration(days: 2))),
  ];

  final List<Account> _accounts = [
    Account(id: '1', name: '招商银行', type: '储蓄账户', balance: 25680.50, color: const Color(0xFF3B82F6)),
    Account(id: '2', name: '支付宝余额宝', type: '货币基金', balance: 8920.30, color: const Color(0xFF10B981)),
    Account(id: '3', name: '中信信用卡', type: '信用卡', balance: -3250.00, color: const Color(0xFFEF4444)),
    Account(id: '4', name: '微信零钱', type: '电子钱包', balance: 156.88, color: const Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 768;
        
        if (isDesktop) {
          // 桌面端：侧边栏 + 主内容区域（类似 Maybe）
          return _buildDesktopLayout();
        } else {
          // 移动端：底部导航栏
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // 左侧边栏 - 现代金融风格
          Container(
            width: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(2, 0),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo 区域 - 优化设计
                Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              offset: const Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/images/jive_money_logo.svg',
                          width: 32,
                          height: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Jive Money',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          Text(
                            '个人财务管理',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 导航菜单
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildNavItem(0, Icons.dashboard_outlined, '概览'),
                      _buildNavItem(1, Icons.receipt_long_outlined, '交易'),
                      _buildNavItem(2, Icons.account_balance_wallet_outlined, '账户'),
                      _buildNavItem(3, Icons.pie_chart_outline, '预算'),
                      _buildNavItem(4, Icons.trending_up_outlined, '投资'),
                      _buildNavItem(5, Icons.analytics_outlined, '报表'),
                      const SizedBox(height: 24),
                      
                      // 账户快览 - 现代卡片设计
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1565C0).withOpacity(0.05),
                              const Color(0xFF43A047).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF1565C0).withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    size: 12,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '我的账户',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF1565C0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._accounts.take(3).map((account) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: account.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '¥${_formatAmount(account.balance)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: account.balance >= 0 ? Colors.black : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 主内容区域
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildMainContent(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              child: SvgPicture.asset(
                'assets/images/jive_money_logo.svg',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Jive Money'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: _buildMainContent(false),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: '概览'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: '交易'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: '账户'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: '预算'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF1565C0).withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(color: const Color(0xFF1565C0).withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF43A047),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          transactions: _transactions,
          accounts: _accounts,
          isDesktop: isDesktop,
        );
      case 1:
        return TransactionsScreen(
          transactions: _transactions,
          isDesktop: isDesktop,
        );
      case 2:
        return AccountsScreen(
          accounts: _accounts,
          isDesktop: isDesktop,
        );
      case 3:
        return BudgetsScreen(isDesktop: isDesktop);
      default:
        return DashboardScreen(
          transactions: _transactions,
          accounts: _accounts,
          isDesktop: isDesktop,
        );
    }
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 10000) {
      return '${(amount / 10000).toStringAsFixed(1)}万';
    }
    return amount.toStringAsFixed(2);
  }

  String _formatAmountWithCommas(double amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = amount.toStringAsFixed(2);
    return result.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  IconData _getAccountIcon(String accountType) {
    switch (accountType) {
      case '储蓄账户': return Icons.savings;
      case '信用卡': return Icons.credit_card;
      case '货币基金': return Icons.trending_up;
      case '电子钱包': return Icons.account_balance_wallet;
      case '投资账户': return Icons.show_chart;
      default: return Icons.account_balance;
    }
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
  final Color color;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
  });
}

// 概览页面 - Maybe 风格
class DashboardScreen extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Account> accounts;
  final bool isDesktop;

  const DashboardScreen({
    Key? key,
    required this.transactions,
    required this.accounts,
    required this.isDesktop,
  }) : super(key: key);

  String _formatAmountWithCommas(double amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = amount.toStringAsFixed(2);
    return result.replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  IconData _getAccountIcon(String accountType) {
    switch (accountType) {
      case '储蓄账户': return Icons.savings;
      case '信用卡': return Icons.credit_card;
      case '货币基金': return Icons.trending_up;
      case '电子钱包': return Icons.account_balance_wallet;
      case '投资账户': return Icons.show_chart;
      default: return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = accounts.fold(0.0, (sum, account) => sum + account.balance);
    
    return CustomScrollView(
      slivers: [
        if (!isDesktop) 
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '总资产',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (isDesktop) ...[
                // 桌面端顶部统计卡片
                Row(
                  children: [
                    Expanded(child: Text('概览', style: Theme.of(context).textTheme.headlineMedium)),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('添加交易'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatsCards(context, isDesktop),
                const SizedBox(height: 32),
              ],
              
              // 账户卡片
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '账户',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('查看全部'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAccountsGrid(context, isDesktop),
              
              const SizedBox(height: 32),
              
              // 最近交易
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '最近交易',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('查看全部'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRecentTransactions(context, isDesktop),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context, bool isDesktop) {
    final thisMonthIncome = transactions.where((t) => t.amount > 0).fold(0.0, (sum, t) => sum + t.amount);
    final thisMonthExpense = transactions.where((t) => t.amount < 0).fold(0.0, (sum, t) => sum + t.amount.abs());
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(context, '总资产', accounts.fold(0.0, (sum, a) => sum + a.balance), Colors.blue),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(context, '本月收入', thisMonthIncome, Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(context, '本月支出', thisMonthExpense, Colors.red),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(context, '净收入', thisMonthIncome - thisMonthExpense, Colors.orange),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${_formatAmountWithCommas(amount)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '较上月 +12.5%',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsGrid(BuildContext context, bool isDesktop) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 2 : 1,
        childAspectRatio: isDesktop ? 3.5 : 4.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                account.color.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: account.color.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: account.color.withOpacity(0.1),
                offset: const Offset(0, 4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      account.color.withOpacity(0.1),
                      account.color.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: account.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _getAccountIcon(account.type),
                  color: account.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.type,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '¥${account.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: account.balance >= 0 ? Colors.black : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions(BuildContext context, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.take(5).length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade100,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: transaction.amount >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: transaction.amount >= 0 ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              transaction.description,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${transaction.category} • ${_formatDate(transaction.date)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            trailing: Text(
              '${transaction.amount >= 0 ? '+' : ''}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: transaction.amount >= 0 ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '餐饮': return Icons.restaurant;
      case '交通': return Icons.directions_car;
      case '购物': return Icons.shopping_bag;
      case '投资': return Icons.trending_up;
      case '收入': return Icons.monetization_on;
      default: return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

// 交易页面
class TransactionsScreen extends StatelessWidget {
  final List<Transaction> transactions;
  final bool isDesktop;

  const TransactionsScreen({
    Key? key,
    required this.transactions,
    required this.isDesktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('交易记录'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Row(
                children: [
                  Expanded(child: Text('交易记录', style: Theme.of(context).textTheme.headlineMedium)),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('添加交易'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: transaction.amount >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(transaction.category),
                          color: transaction.amount >= 0 ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        transaction.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${transaction.category} • ${_formatDate(transaction.date)}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Text(
                        '${transaction.amount >= 0 ? '+' : ''}¥${transaction.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: transaction.amount >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '餐饮': return Icons.restaurant;
      case '交通': return Icons.directions_car;
      case '购物': return Icons.shopping_bag;
      case '投资': return Icons.trending_up;
      case '收入': return Icons.monetization_on;
      default: return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

// 账户页面
class AccountsScreen extends StatelessWidget {
  final List<Account> accounts;
  final bool isDesktop;

  const AccountsScreen({
    Key? key,
    required this.accounts,
    required this.isDesktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('账户管理'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Row(
                children: [
                  Expanded(child: Text('账户管理', style: Theme.of(context).textTheme.headlineMedium)),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('添加账户'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 2 : 1,
                  childAspectRatio: isDesktop ? 3.5 : 4.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: account.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              account.type,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          account.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¥${account.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: account.balance >= 0 ? Colors.black : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 预算页面
class BudgetsScreen extends StatelessWidget {
  final bool isDesktop;

  const BudgetsScreen({Key? key, required this.isDesktop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final budgets = [
      {'category': '餐饮', 'budgeted': 2000.0, 'spent': 1250.0, 'color': Colors.orange},
      {'category': '交通', 'budgeted': 500.0, 'spent': 380.0, 'color': Colors.blue},
      {'category': '购物', 'budgeted': 1500.0, 'spent': 1680.0, 'color': Colors.purple},
      {'category': '娱乐', 'budgeted': 800.0, 'spent': 520.0, 'color': Colors.green},
    ];

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('预算管理'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Row(
                children: [
                  Expanded(child: Text('预算管理', style: Theme.of(context).textTheme.headlineMedium)),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('添加预算'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 2 : 1,
                  childAspectRatio: isDesktop ? 2.5 : 2.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: budgets.length,
                itemBuilder: (context, index) {
                  final budget = budgets[index];
                  final budgeted = budget['budgeted'] as double;
                  final spent = budget['spent'] as double;
                  final progress = spent / budgeted;
                  final isOverBudget = progress > 1.0;
                  final color = budget['color'] as Color;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              budget['category'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isOverBudget ? Colors.red : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '¥${spent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? Colors.red : Colors.black,
                          ),
                        ),
                        Text(
                          '预算 ¥${budgeted.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget ? Colors.red : color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}