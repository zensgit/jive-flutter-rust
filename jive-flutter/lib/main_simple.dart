import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/wechat_service.dart';
import 'services/theme_service.dart';
import 'screens/theme_management_screen.dart';
import 'models/theme_models.dart' as models;
import 'widgets/wechat_qr_binding_dialog.dart';
import 'screens/ai_assistant_page.dart';
import 'screens/add_transaction_page.dart';
import 'screens/management/currency_management_page.dart';
import 'screens/management/category_management_page.dart';
import 'screens/management/category_template_library.dart';
import 'screens/admin/template_admin_page.dart';
import 'screens/management/tag_management_page.dart';
import 'screens/management/payee_management_page.dart';
import 'screens/management/travel_event_management_page.dart';
import 'screens/management/rules_management_page.dart';
import 'screens/currency_converter_page.dart';
import 'widgets/invite_member_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Hive for currency preferences
  await Hive.initFlutter();
  await Hive.openBox('preferences');
  
  // 初始化服务
  await AuthService().initialize();
  await ThemeService().initialize();
  
  // 只在非Web环境下初始化微信服务
  if (!kIsWeb) {
    try {
      await WeChatService.initWeChat();
    } catch (e) {
      debugPrint('微信服务初始化失败: $e');
    }
  }
  
  runApp(const ProviderScope(child: JiveApp()));
}

class JiveApp extends StatefulWidget {
  const JiveApp({super.key});

  @override
  State<JiveApp> createState() => _JiveAppState();
}

class _JiveAppState extends State<JiveApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jive Money - 集腋记账',
      theme: _themeService.getCurrentThemeData(),
      darkTheme: _themeService.getCurrentThemeData().copyWith(
        brightness: Brightness.dark,
      ),
      themeMode: _getFlutterThemeMode(),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/home': (context) => const HomePage(),
        '/theme': (context) => const ThemeManagementScreen(),
        '/currency-converter': (context) => const CurrencyConverterPage(),
        '/settings/currency': (context) => const CurrencyManagementPage(),
        '/settings/categories': (context) => const CategoryManagementPage(),
        '/category/templates': (context) => const CategoryTemplateLibraryPage(),
        '/admin/templates': (context) => const TemplateAdminPage(),
        '/settings/tags': (context) => const TagManagementPage(),
        '/settings/payees': (context) => const PayeeManagementPage(),
        '/settings/travel-events': (context) => const TravelEventManagementPage(),
        '/settings/rules': (context) => const RulesManagementPage(),
      },
    );
  }

  ThemeMode _getFlutterThemeMode() {
    switch (_themeService.currentSettings.themeMode) {
      case models.ThemeMode.light:
        return ThemeMode.light;
      case models.ThemeMode.dark:
        return ThemeMode.dark;
      case models.ThemeMode.system:
        return ThemeMode.system;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const TransactionsPage(),
    const ReportsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 1,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipPath(
        clipper: _BottomNavClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, '仪表盘'),
              _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, '交易'),
              const SizedBox(width: 80), // 为中间按钮留更多空间
              _buildNavItem(2, Icons.analytics_outlined, Icons.analytics_rounded, '报表'),
              _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, '设置'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? filledIcon : outlinedIcon,
                key: ValueKey(isSelected),
                color: isSelected ? const Color(0xFF00E676) : Colors.grey[600],
                size: isSelected ? 26 : 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? const Color(0xFF00E676) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Transform.translate(
      offset: const Offset(0, -10), // 向上移动，让按钮更凸出
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00E676), // 更亮的绿色
              Color(0xFF00C853),
              Color(0xFF00A74C),
            ],
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            // 主阴影
            BoxShadow(
              color: const Color(0xFF00E676).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            // 内层光晕
            BoxShadow(
              color: const Color(0xFF00E676).withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 4),
              spreadRadius: 4,
            ),
            // 顶部高光
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(34),
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.1),
              onTap: () {
                // 添加触觉反馈
                // HapticFeedback.lightImpact(); // 如果需要的话可以取消注释
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 32,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 底部导航栏自定义剪裁器
class _BottomNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    final double centerX = size.width / 2;
    const double notchRadius = 36.0;
    const double notchMargin = 8.0;
    
    path.lineTo(centerX - notchRadius - notchMargin, 0);
    
    // 创建凸起按钮的凹槽
    path.quadraticBezierTo(
      centerX - notchRadius, 0,
      centerX - notchRadius, notchMargin,
    );
    path.arcToPoint(
      Offset(centerX + notchRadius, notchMargin),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(
      centerX + notchRadius, 0,
      centerX + notchRadius + notchMargin, 0,
    );
    
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// 仪表盘页面
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _accountingDays = 0;
  int _totalTransactions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  /// 加载用户统计数据
  Future<void> _loadUserStats() async {
    try {
      // 模拟从API或本地数据库加载数据
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 这里应该是实际的数据加载逻辑
      // 例如：从SharedPreferences、API或数据库获取数据
      final userRegistrationDate = await _getUserRegistrationDate();
      final transactionCount = await _getUserTransactionCount();
      
      setState(() {
        _accountingDays = DateTime.now().difference(userRegistrationDate).inDays + 1;
        _totalTransactions = transactionCount;
        _isLoading = false;
      });
    } catch (e) {
      // 如果加载失败，使用默认值
      setState(() {
        _accountingDays = 42;
        _totalTransactions = 100;
        _isLoading = false;
      });
    }
  }

  /// 获取用户注册日期（模拟数据）
  Future<DateTime> _getUserRegistrationDate() async {
    // 这里应该从实际的存储中获取用户注册日期
    // 暂时使用模拟数据：42天前
    return DateTime.now().subtract(const Duration(days: 41));
  }

  /// 获取用户交易记录总数（模拟数据）
  Future<int> _getUserTransactionCount() async {
    // 这里应该从实际的数据库中查询用户的交易记录数量
    // 暂时使用基于天数的模拟算法
    final days = _accountingDays > 0 ? _accountingDays : 42;
    // 模拟：平均每天1-3条记录，有些波动
    return (days * 1.5 + (days * 0.5 * (DateTime.now().millisecond % 100) / 100)).round();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 欢迎栏和logo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo - 可点击打开AI助理
              GestureDetector(
                onTap: () {
                  // 打开AI助理页面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIAssistantPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/Jiva.svg',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 右侧内容区域
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '欢迎回来！',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // 提示信息
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isLoading
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '正在加载统计信息...',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    '坚持记账第$_accountingDays天，已记录$_totalTransactions条账单，继续保持！',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 快速操作
          const Text(
            '快速操作',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(Icons.add_circle, '记账', Colors.green),
              _buildQuickAction(Icons.credit_card, '信用卡', Colors.blue),
              _buildQuickAction(Icons.savings, '储蓄', Colors.orange),
              _buildQuickAction(Icons.trending_up, '投资', Colors.purple),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 最近交易
          const Text(
            '最近交易',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _buildTransactionItem('星巴克', '咖啡', '-¥35.00', DateTime.now()),
                _buildTransactionItem('工资', '收入', '+¥15,000.00', DateTime.now().subtract(const Duration(days: 1))),
                _buildTransactionItem('滴滴出行', '交通', '-¥68.00', DateTime.now().subtract(const Duration(days: 2))),
                _buildTransactionItem('盒马鲜生', '购物', '-¥256.00', DateTime.now().subtract(const Duration(days: 3))),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTransactionItem(String title, String category, String amount, DateTime date) {
    final isExpense = amount.startsWith('-');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: isExpense ? Colors.red : Colors.green,
        ),
      ),
      title: Text(title),
      subtitle: Text(category),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.red : Colors.green,
            ),
          ),
          Text(
            '${date.month}/${date.day}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// 交易页面
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('交易记录', style: TextStyle(fontSize: 24)),
    );
  }
}

// 预算页面
class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('预算管理', style: TextStyle(fontSize: 24)),
    );
  }
}

// 报表页面
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('财务报表', style: TextStyle(fontSize: 24)),
    );
  }
}

// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 账户设置分组
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '账户设置',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('用户信息'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const UserProfilePage(),
              ),
            );
          },
        ),
        
        // 财务管理分组
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            '财务管理',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: const Text('货币管理'),
          subtitle: const Text('管理支持的货币类型'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CurrencyManagementPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.calculate),
          title: const Text('货币转换器'),
          subtitle: const Text('实时汇率转换工具'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CurrencyConverterPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.category),
          title: const Text('分类管理'),
          subtitle: const Text('自定义收支分类'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CategoryManagementPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.label),
          title: const Text('标签管理'),
          subtitle: const Text('创建和管理交易标签'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TagManagementPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('交易对方管理'),
          subtitle: const Text('管理常用交易对象'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PayeeManagementPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('旅行事件管理'),
          subtitle: const Text('管理旅行相关记录'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TravelEventManagementPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: const Text('规则管理'),
          subtitle: const Text('自动化记账规则'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RulesManagementPage(),
              ),
            );
          },
        ),
        
        // 应用设置分组
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            '应用设置',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('主题设置'),
          subtitle: const Text('自定义应用外观'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ThemeManagementScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('安全设置'),
          subtitle: const Text('多因素认证'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SecuritySettingsPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('通知设置'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationSettingsPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.import_export),
          title: const Text('数据导入导出'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const DataImportExportPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.help),
          title: const Text('帮助与支持'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('关于'),
          subtitle: const Text('版本 1.0.0'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AboutPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// 用户信息页面
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final AuthService _authService = AuthService();
  WeChatBindingData? _weChatInfo;
  bool _isLoading = false;
  bool _isEditing = false;
  
  // 编辑控制器
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWeChatInfo();
    _initializeControllers();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
  
  void _initializeControllers() {
    final user = _authService.currentUser;
    if (user != null) {
      _emailController.text = user.email;
      _nicknameController.text = _getDisplayName(user);
      _firstNameController.text = _getFirstName(user);
      _lastNameController.text = _getLastName(user);
    }
  }

  Future<void> _loadWeChatInfo() async {
    try {
      final wechatInfo = await _authService.getWeChatBinding();
      setState(() {
        _weChatInfo = wechatInfo;
      });
    } catch (e) {
      debugPrint('加载微信绑定信息失败: $e');
    }
  }

  Future<void> _logout() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      await _authService.logout();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      // 保存更改
      _saveProfile();
    } else {
      // 进入编辑模式
      setState(() {
        _isEditing = true;
      });
    }
  }
  
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    // 重置控制器到原始值
    _initializeControllers();
  }
  
  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 构建真实姓名
      String realName = '';
      if (_firstNameController.text.isNotEmpty || _lastNameController.text.isNotEmpty) {
        realName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      }
      
      // 调用更新用户信息的API
      final result = await _authService.updateUserInfo(
        realName: realName.isEmpty ? null : realName,
        email: _emailController.text.trim(),
        // 注意：昵称通常存储在username字段中，这里暂时通过realName处理
        // 如果需要单独的昵称字段，需要后端API支持
      );
      
      if (result.success) {
        setState(() {
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('用户信息更新成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '更新失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('更新用户信息时发生错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleWeChatBinding() async {
    if (_weChatInfo != null) {
      // 解绑微信
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认解绑'),
          content: const Text('解绑后将无法使用微信快速登录，确定要解绑吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('解绑'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          _isLoading = true;
        });

        try {
          final result = await _authService.unbindWechat();
          
          if (result.success) {
            setState(() {
              _weChatInfo = null;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? '微信账户解绑成功'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? '解绑失败'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // 绑定微信 - 显示二维码界面
      _showWeChatQRBindingDialog();
    }
  }

  String _getFirstName(UserData? user) {
    if (user?.realName != null && user!.realName!.isNotEmpty) {
      final parts = user.realName!.trim().split(RegExp(r'\s+'));
      return parts.isNotEmpty ? parts[0] : user.username;
    }
    return user?.username ?? 'Unknown';
  }

  String _getLastName(UserData? user) {
    if (user?.realName != null && user!.realName!.isNotEmpty) {
      final parts = user.realName!.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.sublist(1).join(' ');
      }
    }
    return '';
  }

  Future<void> _deleteAccount() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账户'),
        content: const Text('警告：删除账户将永久删除您的所有数据，此操作不可恢复！\n\n确定要删除账户吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 模拟删除账户操作
        await Future.delayed(const Duration(seconds: 2));
        
        // 清除所有本地数据
        await _authService.logout();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('账户已删除'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除账户时发生错误: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }


  // 获取显示名称
  String _getDisplayName(UserData? user) {
    return user?.realName ?? user?.username ?? '未设置昵称';
  }



  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户信息'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '个人资料设置和头像管理',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Avatar Upload Area
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: currentUser?.avatar != null 
                                  ? ClipOval(
                                      child: Image.network(
                                        currentUser!.avatar!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.image_outlined,
                                      size: 32,
                                      color: Colors.grey[400],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('头像上传功能开发中')),
                            );
                          },
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Upload photo (optional)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JPG or PNG. 5MB max.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Email Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Enter your email',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 14),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                currentUser?.email ?? 'user@example.com',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 昵称字段
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '昵称 (Nickname)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextFormField(
                              controller: _nicknameController,
                              decoration: InputDecoration(
                                hintText: 'Enter your nickname',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                _getDisplayName(currentUser),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Name Fields Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'First Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      hintText: 'First name',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Colors.blue),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      _getFirstName(currentUser),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _isEditing
                                ? TextFormField(
                                    controller: _lastNameController,
                                    decoration: InputDecoration(
                                      hintText: 'Last name',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Colors.blue),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      _getLastName(currentUser),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Button Row
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isEditing) ...[
                        // 取消按钮
                        OutlinedButton(
                          onPressed: _isLoading ? null : _cancelEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        // 保存按钮
                        ElevatedButton(
                          onPressed: _isLoading ? null : _toggleEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ] else ...[
                        // 编辑按钮
                        ElevatedButton(
                          onPressed: _toggleEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Edit'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Household Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Household',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      // 添加成员按钮
                      OutlinedButton.icon(
                        onPressed: _getUserRole() == 'Owner' ? _showAddMemberDialog : null,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Add Member'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _getUserRole() == 'Owner' ? Colors.black : Colors.grey,
                          side: BorderSide(
                            color: _getUserRole() == 'Owner' ? Colors.black : Colors.grey[400]!,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      if (_getUserRole() == 'Owner') ...[
                        const SizedBox(width: 8),
                        // 解散家庭按钮
                        OutlinedButton.icon(
                          onPressed: _showDissolveHouseholdDialog,
                          icon: const Icon(Icons.delete_forever, size: 16),
                          label: const Text('Dissolve'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.black),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '管理您的家庭成员，邀请或移除成员。家庭成员可以访问共享的财务数据。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 当前家庭信息
                  _buildCurrentHousehold(currentUser),
                  
                  const SizedBox(height: 24),
                  
                  // 家庭成员列表
                  const Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  ..._buildMembersList(),
                  
                  const SizedBox(height: 24),
                  
                  // 其他家庭
                  _buildOtherHouseholds(currentUser),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // WeChat Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wechat, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '微信账户',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _weChatInfo != null 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _weChatInfo != null ? '已绑定' : '未绑定',
                          style: TextStyle(
                            fontSize: 12,
                            color: _weChatInfo != null 
                                ? Colors.green[700]
                                : Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '绑定微信账户后，您可以使用微信快速登录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  if (_weChatInfo != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: _weChatInfo!.headImgUrl.isNotEmpty
                                ? NetworkImage(_weChatInfo!.headImgUrl)
                                : null,
                            child: _weChatInfo!.headImgUrl.isEmpty
                                ? const Icon(Icons.person, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _weChatInfo!.nickname,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${_weChatInfo!.country} ${_weChatInfo!.province} ${_weChatInfo!.city}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleWeChatBinding,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _weChatInfo != null 
                            ? Colors.red 
                            : Colors.black,
                        side: BorderSide(
                          color: _weChatInfo != null 
                              ? Colors.red 
                              : Colors.black,
                          width: 1.5,
                        ),
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _weChatInfo != null ? Colors.red : Colors.blue[600]!,
                                ),
                              ),
                            )
                          : Text(_weChatInfo != null ? '解绑微信' : '绑定微信'),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Danger Zone Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delete account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '删除您的账户将永久删除所有数据且无法撤销。',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Delete account'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _logout,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: Text(_isLoading ? '退出中...' : '退出登录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFamilyMember(String name, String role, IconData icon, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              Text(
                role,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return '未知';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  // 获取用户在当前家庭中的角色
  String _getUserRole() {
    // 模拟数据：从认证服务或用户数据中获取角色
    final user = _authService.currentUser;
    if (user != null && user.username == 'superadmin') {
      return 'Owner'; // 超级管理员作为测试Owner
    }
    return user?.role ?? 'Member';
  }
  
  // 显示添加成员对话框
  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => InviteMemberDialog(),
    );
  }
  
  // 构建当前家庭信息
  Widget _buildCurrentHousehold(UserData? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Current Household',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.username ?? 'Default Family', // 模拟家庭名称
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRoleBadge(_getUserRole()),
              const SizedBox(width: 12),
              Icon(Icons.person, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _getUserRole() == 'Owner' ? '4 members' : '1 member', // 动态成员数量
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 构建家庭成员列表
  List<Widget> _buildMembersList() {
    // 模拟成员数据
    final currentUser = _authService.currentUser;
    final members = <Map<String, dynamic>>[
      {
        'name': currentUser?.username ?? 'Current User',
        'email': currentUser?.email ?? 'user@example.com',
        'role': _getUserRole(),
        'isCurrentUser': true,
      },
      // 添加更多模拟成员
      if (_getUserRole() == 'Owner') ...[
        {
          'name': 'Alice Smith',
          'email': 'alice@example.com',
          'role': 'Admin',
          'isCurrentUser': false,
        },
        {
          'name': 'Bob Johnson',
          'email': 'bob@example.com',
          'role': 'Member',
          'isCurrentUser': false,
        },
        {
          'name': 'Carol Davis',
          'email': 'carol@example.com',
          'role': 'Viewer',
          'isCurrentUser': false,
        },
      ],
    ];
    
    return members.map((member) => _buildMemberTile(
      name: member['name'],
      email: member['email'],
      role: member['role'],
      isCurrentUser: member['isCurrentUser'],
    )).toList();
  }
  
  // 构建单个成员项
  Widget _buildMemberTile({
    required String name,
    required String email,
    required String role,
    bool isCurrentUser = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _getRoleColor(role).withOpacity(0.1),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getRoleColor(role),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          _buildRoleBadge(role),
          if (!isCurrentUser && _getUserRole() == 'Owner') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16),
              onSelected: (value) {
                if (value == 'remove') {
                  _showRemoveMemberDialog(name);
                } else if (value == 'change_role') {
                  _showChangeRoleDialog(name, role);
                } else if (value.startsWith('role_')) {
                  final newRole = value.replaceFirst('role_', '');
                  _changeMemberRole(name, newRole);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change_role',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 16),
                      SizedBox(width: 8),
                      Text('Change Role'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remove Member', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // 构建角色标签
  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          color: _getRoleColor(role),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  // 获取角色颜色
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.amber;
      case 'admin':
        return Colors.blue;
      case 'member':
        return Colors.green;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  // 显示移除成员对话框
  void _showRemoveMemberDialog(String memberName) {
    showDialog(
      context: context,
      builder: (context) => _RemoveMemberDialog(memberName: memberName),
    );
  }
  
  // 显示角色更改对话框
  void _showChangeRoleDialog(String memberName, String currentRole) {
    showDialog(
      context: context,
      builder: (context) => _ChangeRoleDialog(
        memberName: memberName,
        currentRole: currentRole,
        onRoleChanged: (newRole) => _changeMemberRole(memberName, newRole),
      ),
    );
  }
  
  // 更改成员角色
  void _changeMemberRole(String memberName, String newRole) {
    // 这里应该调用API更新成员角色
    setState(() {
      // 模拟更新逻辑
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$memberName\'s role has been changed to $newRole'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // 显示解散家庭对话框
  void _showDissolveHouseholdDialog() {
    showDialog(
      context: context,
      builder: (context) => const _DissolveHouseholdDialog(),
    );
  }
  
  // 构建其他家庭
  Widget _buildOtherHouseholds(UserData? user) {
    // 模拟其他家庭数据
    final otherHouseholds = <Map<String, dynamic>>[
      {
        'name': 'Smith Family Business',
        'role': 'Admin',
        'members': 5,
      },
    ];
    
    if (otherHouseholds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'You are not a member of any other households',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Other Households',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...otherHouseholds.map((household) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.business, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      household['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildRoleBadge(household['role']),
                        const SizedBox(width: 8),
                        Icon(Icons.person, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          '${household['members']} members',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showLeaveHouseholdDialog(household['name']),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: const Text(
                  'Leave',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  // 显示退出家庭对话框
  void _showLeaveHouseholdDialog(String householdName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Household'),
        content: Text('Are you sure you want to leave "$householdName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You have left "$householdName"'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
  
  // 显示微信二维码绑定对话框
  void _showWeChatQRBindingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WeChatQRBindingDialog(
        onSuccess: () async {
          Navigator.pop(context);
          await _loadWeChatInfo();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('微信绑定成功！'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}

// 安全设置页面
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _mfaEnabled = false;
  bool _biometricEnabled = false;
  String? _totpSecret;
  List<String>? _backupCodes;
  
  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }
  
  void _loadSecuritySettings() {
    // 从本地存储加载安全设置
    setState(() {
      // 这里模拟从存储加载
      _mfaEnabled = false;
      _biometricEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安全设置'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        children: [
          // 多因素认证部分
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '账户安全',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _mfaEnabled ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.security,
                      color: _mfaEnabled ? Colors.green[600] : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: const Text('多因素认证 (2FA)'),
                  subtitle: Text(
                    _mfaEnabled 
                      ? '已启用 - 您的账户已受到额外保护'
                      : '未启用 - 启用以增强账户安全',
                    style: TextStyle(
                      color: _mfaEnabled ? Colors.green[600] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  trailing: Switch(
                    value: _mfaEnabled,
                    onChanged: (value) {
                      if (value) {
                        _showEnableMFADialog();
                      } else {
                        _showDisableMFADialog();
                      }
                    },
                    activeThumbColor: Colors.green,
                  ),
                ),
                if (_mfaEnabled)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.backup_outlined,
                        color: Colors.orange[600],
                        size: 20,
                      ),
                    ),
                    title: const Text('备份代码'),
                    subtitle: const Text('查看或重新生成备份代码'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showBackupCodes,
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _biometricEnabled ? Colors.blue[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: _biometricEnabled ? Colors.blue[600] : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: const Text('生物识别认证'),
                  subtitle: Text(
                    _biometricEnabled
                      ? '已启用 - 使用指纹或面部识别快速登录'
                      : '未启用 - 启用以便快速安全登录',
                    style: TextStyle(
                      color: _biometricEnabled ? Colors.blue[600] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  trailing: Switch(
                    value: _biometricEnabled,
                    onChanged: (value) {
                      if (value) {
                        _enableBiometric();
                      } else {
                        _disableBiometric();
                      }
                    },
                    activeThumbColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          // 密码管理部分
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '密码管理',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.purple[600],
                      size: 20,
                    ),
                  ),
                  title: const Text('修改密码'),
                  subtitle: const Text('定期更改密码以保护账户安全'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // 设备和会话管理部分
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '设备与会话',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.devices_other,
                      color: Colors.indigo[600],
                      size: 20,
                    ),
                  ),
                  title: const Text('设备管理'),
                  subtitle: const Text('查看和管理已登录的设备'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '3 设备',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceManagementPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Colors.teal[600],
                      size: 20,
                    ),
                  ),
                  title: const Text('登录历史'),
                  subtitle: const Text('查看账户登录活动记录'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginHistoryPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 显示启用MFA对话框
  void _showEnableMFADialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MFASetupPage(
          onEnabled: (secret, backupCodes) {
            setState(() {
              _mfaEnabled = true;
              _totpSecret = secret;
              _backupCodes = backupCodes;
            });
          },
        ),
      ),
    );
  }
  
  // 显示禁用MFA对话框
  void _showDisableMFADialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('禁用多因素认证'),
        content: const Text('禁用多因素认证会降低您账户的安全性。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _mfaEnabled = false;
                _totpSecret = null;
                _backupCodes = null;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('多因素认证已禁用'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('禁用'),
          ),
        ],
      ),
    );
  }
  
  // 显示备份代码
  void _showBackupCodes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupCodesPage(
          backupCodes: _backupCodes ?? [],
          onRegenerate: (newCodes) {
            setState(() {
              _backupCodes = newCodes;
            });
          },
        ),
      ),
    );
  }
  
  // 启用生物识别
  void _enableBiometric() async {
    // 这里应该调用生物识别API
    setState(() {
      _biometricEnabled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('生物识别认证已启用'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // 禁用生物识别
  void _disableBiometric() {
    setState(() {
      _biometricEnabled = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('生物识别认证已禁用'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// MFA设置页面
class MFASetupPage extends StatefulWidget {
  final Function(String secret, List<String> backupCodes) onEnabled;
  
  const MFASetupPage({super.key, required this.onEnabled});
  
  @override
  State<MFASetupPage> createState() => _MFASetupPageState();
}

class _MFASetupPageState extends State<MFASetupPage> {
  int _currentStep = 0;
  String _totpSecret = '';
  String _verificationCode = '';
  List<String> _backupCodes = [];
  final _codeController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _generateSecret();
  }
  
  void _generateSecret() {
    // 生成TOTP密钥（实际应该从服务器获取）
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    _totpSecret = List.generate(32, (index) => 
      chars[Random().nextInt(chars.length)]).join();
    
    // 生成备份代码
    _backupCodes = List.generate(10, (index) => 
      (100000 + Random().nextInt(900000)).toString());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置多因素认证'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            setState(() {
              _currentStep++;
            });
          } else if (_currentStep == 1) {
            if (_verifyCode()) {
              setState(() {
                _currentStep++;
              });
            }
          } else {
            // 完成设置
            widget.onEnabled(_totpSecret, _backupCodes);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('多因素认证已成功启用'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          } else {
            Navigator.pop(context);
          }
        },
        steps: [
          Step(
            title: const Text('扫描二维码'),
            content: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 150, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '使用您的认证器应用扫描此二维码',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '推荐使用: Google Authenticator, Microsoft Authenticator, Authy',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          _totpSecret,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '无法扫描？手动输入上述密钥',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('验证'),
            content: Column(
              children: [
                const Text('输入您认证器应用中显示的6位数字代码'),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    counterText: '',
                  ),
                  onChanged: (value) {
                    _verificationCode = value;
                  },
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('保存备份代码'),
            content: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700], size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        '请保存这些备份代码',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '如果您无法访问认证器应用，可以使用这些代码登录',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _backupCodes.map((code) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // 复制到剪贴板
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('备份代码已复制')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制所有代码'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.indexed : StepState.complete,
          ),
        ],
      ),
    );
  }
  
  bool _verifyCode() {
    // 这里应该验证TOTP代码
    if (_verificationCode.length == 6) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('验证码无效，请重试'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}

// 备份代码页面
class BackupCodesPage extends StatelessWidget {
  final List<String> backupCodes;
  final Function(List<String>) onRegenerate;
  
  const BackupCodesPage({
    super.key,
    required this.backupCodes,
    required this.onRegenerate,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份代码'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '每个备份代码只能使用一次。请将它们保存在安全的地方。',
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '您的备份代码',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: backupCodes.map((code) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.fiber_manual_record, size: 8, color: Colors.grey[400]),
                        const SizedBox(width: 12),
                        Text(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 复制所有代码
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('备份代码已复制')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showRegenerateDialog(context);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重新生成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showRegenerateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成备份代码'),
        content: const Text('重新生成将使当前所有备份代码失效。确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCodes = List.generate(10, (index) => 
                (100000 + Random().nextInt(900000)).toString());
              onRegenerate(newCodes);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('备份代码已重新生成'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }
}

// 修改密码页面
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '建议使用包含大小写字母、数字和特殊字符的强密码',
                      style: TextStyle(color: Colors.amber[800], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 当前密码
            const Text(
              '当前密码',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                hintText: '输入当前密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showCurrentPassword = !_showCurrentPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 新密码
            const Text(
              '新密码',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                hintText: '输入新密码（至少8位）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showNewPassword = !_showNewPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 确认新密码
            const Text(
              '确认新密码',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                hintText: '再次输入新密码',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 密码强度指示
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: 32),
            
            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('修改密码'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPasswordStrengthIndicator() {
    final password = _newPasswordController.text;
    int strength = 0;
    String message = '';
    Color color = Colors.grey;
    
    if (password.isEmpty) {
      message = '请输入密码';
    } else if (password.length < 8) {
      strength = 1;
      message = '弱 - 密码太短';
      color = Colors.red;
    } else if (password.length < 12) {
      strength = 2;
      message = '中等 - 建议使用更长的密码';
      color = Colors.orange;
    } else {
      strength = 3;
      message = '强 - 密码强度良好';
      color = Colors.green;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '密码强度',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: strength / 3,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
  
  void _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写所有字段'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新密码两次输入不一致'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_newPasswordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新密码长度至少8位'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // 模拟API调用
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isLoading = false;
    });
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('密码修改成功'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// 设备管理页面
class DeviceManagementPage extends StatefulWidget {
  const DeviceManagementPage({super.key});
  
  @override
  State<DeviceManagementPage> createState() => _DeviceManagementPageState();
}

class _DeviceManagementPageState extends State<DeviceManagementPage> {
  
  final List<Map<String, dynamic>> devices = [
    {
      'id': 'session_001',
      'name': 'iPhone 14 Pro',
      'type': 'mobile',
      'os': 'iOS 17.2',
      'browser': 'Safari',
      'location': '北京市朝阳区',
      'ip': '192.168.1.100',
      'lastActive': DateTime.now(),
      'firstLogin': DateTime.now().subtract(const Duration(days: 30)),
      'isCurrent': true,
      'trusted': true,
    },
    {
      'id': 'session_002',
      'name': 'MacBook Pro',
      'type': 'desktop',
      'os': 'macOS Sonoma',
      'browser': 'Chrome 122',
      'location': '上海市浦东新区',
      'ip': '10.0.0.50',
      'lastActive': DateTime.now().subtract(const Duration(hours: 2)),
      'firstLogin': DateTime.now().subtract(const Duration(days: 15)),
      'isCurrent': false,
      'trusted': true,
    },
    {
      'id': 'session_003',
      'name': 'iPad Pro',
      'type': 'tablet',
      'os': 'iPadOS 17.2',
      'browser': 'Safari',
      'location': '深圳市南山区',
      'ip': '192.168.2.150',
      'lastActive': DateTime.now().subtract(const Duration(days: 1)),
      'firstLogin': DateTime.now().subtract(const Duration(days: 45)),
      'isCurrent': false,
      'trusted': false,
    },
  ];
  
  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 1) {
      return '当前在线';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${lastActive.month}月${lastActive.day}日';
    }
  }
  
  String _formatFirstLogin(DateTime date) {
    return '首次登录：${date.year}年${date.month}月${date.day}日';
  }
  
  @override
  Widget build(BuildContext context) {
    final trustedDevices = devices.where((d) => d['trusted'] == true).length;
    final activeDevices = devices.where((d) {
      final lastActive = d['lastActive'] as DateTime;
      return DateTime.now().difference(lastActive).inHours < 24;
    }).length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('登出所有其他设备'),
            onPressed: () => _showLogoutAllDialog(context),
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: ListView(
        children: [
          // 统计信息卡片
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('总设备数', devices.length.toString(), Icons.devices, Colors.blue),
                _buildStatCard('活跃设备', activeDevices.toString(), Icons.check_circle, Colors.green),
                _buildStatCard('受信任设备', trustedDevices.toString(), Icons.verified_user, Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // 安全提示
          if (devices.any((d) => d['trusted'] == false))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '您有未受信任的设备登录，建议检查并移除可疑设备',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          
          // 设备列表
          ...devices.map((device) => _buildEnhancedDeviceItem(context, device)).toList(),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEnhancedDeviceItem(BuildContext context, Map<String, dynamic> device) {
    IconData icon;
    Color color;
    
    switch (device['type']) {
      case 'mobile':
        icon = Icons.phone_iphone;
        color = Colors.blue;
        break;
      case 'desktop':
        icon = Icons.computer;
        color = Colors.purple;
        break;
      case 'tablet':
        icon = Icons.tablet_mac;
        color = Colors.orange;
        break;
      default:
        icon = Icons.devices_other;
        color = Colors.grey;
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        device['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (device['isCurrent'])
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '当前设备',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device['location']} • ${device['lastActive']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!device['isCurrent'])
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'remove') {
                    _showRemoveDeviceDialog(context, device['name']);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('移除设备', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  void _toggleTrust(Map<String, dynamic> device) {
    final isTrusted = device['trusted'] as bool;
    setState(() {
      device['trusted'] = !isTrusted;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTrusted ? '已取消设备信任' : '设备已标记为受信任',
        ),
        backgroundColor: isTrusted ? Colors.orange : Colors.green,
      ),
    );
  }
  
  void _showRemoveDeviceDialog(BuildContext context, Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登出设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要从 ${device['name']} 登出吗？'),
            const SizedBox(height: 8),
            Text(
              '该设备将需要重新登录才能访问您的账户。',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                devices.removeWhere((d) => d['id'] == device['id']);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('设备已登出'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('登出设备'),
          ),
        ],
      ),
    );
  }
  
  void _showLogoutAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('登出所有其他设备'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('这将登出除当前设备外的所有设备。'),
            SizedBox(height: 8),
            Text(
              '所有其他设备将需要重新登录。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                devices.removeWhere((d) => d['isCurrent'] != true);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已登出所有其他设备'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认登出'),
          ),
        ],
      ),
    );
  }
}

// 登录历史页面
class LoginHistoryPage extends StatelessWidget {
  const LoginHistoryPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    final loginHistory = [
      {
        'date': '2024-03-20 14:30',
        'device': 'iPhone 14 Pro',
        'location': '北京市朝阳区',
        'ip': '192.168.1.100',
        'status': 'success',
      },
      {
        'date': '2024-03-20 10:15',
        'device': 'MacBook Pro',
        'location': '上海市浦东新区',
        'ip': '10.0.0.50',
        'status': 'success',
      },
      {
        'date': '2024-03-19 22:45',
        'device': '未知设备',
        'location': '广州市天河区',
        'ip': '117.136.12.79',
        'status': 'failed',
      },
      {
        'date': '2024-03-19 18:20',
        'device': 'iPad Pro',
        'location': '深圳市南山区',
        'ip': '192.168.2.150',
        'status': 'success',
      },
      {
        'date': '2024-03-18 09:00',
        'device': 'Windows PC',
        'location': '成都市高新区',
        'ip': '172.16.0.100',
        'status': 'success',
      },
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录历史'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // 显示筛选选项
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: ListView.builder(
        itemCount: loginHistory.length,
        itemBuilder: (context, index) {
          final item = loginHistory[index];
          final isSuccess = item['status'] == 'success';
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSuccess ? Colors.grey[200]! : Colors.red[100]!,
              ),
            ),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green[600] : Colors.red[600],
                  size: 20,
                ),
              ),
              title: Text(
                item['device']!,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${item['date']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${item['location']} • IP: ${item['ip']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (!isSuccess)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '登录失败',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16),
                onSelected: (value) {
                  if (value == 'report') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已报告可疑活动'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('报告可疑活动'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 家庭管理页面
class FamilyManagementPage extends StatelessWidget {
  const FamilyManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的家庭',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFamilyMember('张三', '管理员', Icons.admin_panel_settings, Colors.orange),
                  _buildFamilyMember('李四', '成员', Icons.person, Colors.blue),
                  _buildFamilyMember('王五', '查看者', Icons.visibility, Colors.green),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('邀请成员'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMember(String name, String role, IconData icon, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(name),
      subtitle: Text(role),
      trailing: const Icon(Icons.more_vert),
      onTap: () {},
    );
  }
}

// 通知设置页面
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _budgetAlerts = true;
  bool _billReminders = true;
  bool _transactionAlerts = false;
  bool _weeklyReports = true;
  bool _achievements = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '通知类型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('预算提醒'),
            subtitle: const Text('预算超支时通知'),
            value: _budgetAlerts,
            onChanged: (bool value) {
              setState(() {
                _budgetAlerts = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('账单提醒'),
            subtitle: const Text('信用卡账单到期提醒'),
            value: _billReminders,
            onChanged: (bool value) {
              setState(() {
                _billReminders = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('交易提醒'),
            subtitle: const Text('大额交易和异常活动'),
            value: _transactionAlerts,
            onChanged: (bool value) {
              setState(() {
                _transactionAlerts = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('周报'),
            subtitle: const Text('每周财务摘要'),
            value: _weeklyReports,
            onChanged: (bool value) {
              setState(() {
                _weeklyReports = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('成就通知'),
            subtitle: const Text('理财里程碑提醒'),
            value: _achievements,
            onChanged: (bool value) {
              setState(() {
                _achievements = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

// 数据导入导出页面
class DataImportExportPage extends StatelessWidget {
  const DataImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导入导出'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '数据导入',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildImportOption('支付宝账单', Icons.account_balance_wallet),
                    _buildImportOption('微信账单', Icons.wechat),
                    _buildImportOption('银行流水', Icons.account_balance),
                    _buildImportOption('CSV 文件', Icons.table_chart),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '数据导出',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildExportOption('导出为 Excel', Icons.table_view),
                    _buildExportOption('导出为 PDF', Icons.picture_as_pdf),
                    _buildExportOption('完整备份', Icons.backup),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.upload_file),
      onTap: () {},
    );
  }

  Widget _buildExportOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.download),
      onTap: () {},
    );
  }
}

// 关于页面
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(20),
              child: SvgPicture.asset(
                'assets/images/Jiva.svg',
                width: 60,
                height: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Jive Money',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              '集腋记账',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '版本 1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '集腋成裘，细水长流',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '用心记录每一笔收支，积小成大，理财从记账开始。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '© 2024 Jive Money. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// 移除成员对话框 - 需要4位验证码
class _RemoveMemberDialog extends StatefulWidget {
  final String memberName;

  const _RemoveMemberDialog({required this.memberName});

  @override
  State<_RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<_RemoveMemberDialog> {
  final _verificationController = TextEditingController();
  late final String _verificationCode;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // 生成随机4位数字验证码
    _verificationCode = (1000 + Random().nextInt(9000)).toString();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  void _verifyAndRemove() {
    if (_verificationController.text == _verificationCode) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.memberName} has been removed from the household'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[600]),
          const SizedBox(width: 8),
          const Text('Remove Member'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to remove ${widget.memberName} from this household?',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter verification code: $_verificationCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _verificationController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter 4-digit code',
                    counterText: '',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : () {
            setState(() {
              _isVerifying = true;
            });
            _verifyAndRemove();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Remove Member'),
        ),
      ],
    );
  }
}

// 角色更改对话框
class _ChangeRoleDialog extends StatefulWidget {
  final String memberName;
  final String currentRole;
  final Function(String) onRoleChanged;

  const _ChangeRoleDialog({
    required this.memberName,
    required this.currentRole,
    required this.onRoleChanged,
  });

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Owner':
        return Colors.purple;
      case 'Admin':
        return Colors.blue;
      case 'Member':
        return Colors.green;
      case 'Viewer':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Admin':
        return 'Can manage household members and settings';
      case 'Member':
        return 'Can add transactions and view reports';
      case 'Viewer':
        return 'Can only view data, no editing permissions';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableRoles = ['Admin', 'Member', 'Viewer'];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.blue[600]),
          const SizedBox(width: 8),
          const Text('Change Member Role'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change role for ${widget.memberName}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Current role: ${widget.currentRole}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select new role:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...availableRoles.map((role) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedRole = role;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedRole == role
                      ? _getRoleColor(role).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedRole == role
                        ? _getRoleColor(role)
                        : Colors.grey.withOpacity(0.3),
                    width: _selectedRole == role ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: role,
                      groupValue: _selectedRole,
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
                      activeColor: _getRoleColor(role),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _selectedRole == role
                                  ? _getRoleColor(role)
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getRoleDescription(role),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedRole != widget.currentRole
              ? () {
                  Navigator.pop(context);
                  widget.onRoleChanged(_selectedRole);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text('Change Role'),
        ),
      ],
    );
  }
}

// 解散家庭对话框 - 需要4位验证码
class _DissolveHouseholdDialog extends StatefulWidget {
  const _DissolveHouseholdDialog();

  @override
  State<_DissolveHouseholdDialog> createState() => _DissolveHouseholdDialogState();
}

class _DissolveHouseholdDialogState extends State<_DissolveHouseholdDialog> {
  final _verificationController = TextEditingController();
  late final String _verificationCode;
  bool _isDissolving = false;

  @override
  void initState() {
    super.initState();
    // 生成随机4位数字验证码
    _verificationCode = (1000 + Random().nextInt(9000)).toString();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  void _verifyAndDissolve() {
    if (_verificationController.text == _verificationCode) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Household has been dissolved. All members have been notified.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      setState(() {
        _isDissolving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red[700], size: 28),
          const SizedBox(width: 12),
          const Text('Dissolve Household'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to dissolve this household?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    const Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• All household data will be permanently deleted\n'
                  '• All members will lose access to household data\n'
                  '• Transaction history will be removed\n'
                  '• Members will be notified via email',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter verification code: $_verificationCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _verificationController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter 4-digit code',
                    counterText: '',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isDissolving ? null : () {
            setState(() {
              _isDissolving = true;
            });
            _verifyAndDissolve();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
          child: _isDissolving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Dissolve Household'),
        ),
      ],
    );
  }
}


