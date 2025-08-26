import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/settings/wechat_binding_screen.dart';
import 'screens/user/edit_profile_screen.dart';
import 'screens/auth/wechat_qr_screen.dart';
import 'screens/auth/wechat_register_form_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/wechat_service.dart';
import 'services/theme_service.dart';
import 'screens/theme_management_screen.dart';
import 'models/theme_models.dart' as models;
import 'widgets/wechat_qr_binding_dialog.dart';
import 'widgets/invite_member_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  runApp(const JiveApp());
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
    const BudgetPage(),
    const ReportsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/Jiva.svg',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text('Jive Money'),
          ],
        ),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: '仪表盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: '交易',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: '预算',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: '报表',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

// 仪表盘页面
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // 获取坚持记账天数（模拟数据）
  int _getAccountingDays() {
    // 模拟从注册日期开始计算
    final registerDate = DateTime.now().subtract(const Duration(days: 42));
    return DateTime.now().difference(registerDate).inDays;
  }

  // 获取总记录条数（模拟数据）
  int _getTotalRecords() {
    final days = _getAccountingDays();
    // 模拟数据：平均每天1-3条记录
    return (days * 1.8 + Random().nextInt(days * 2)).round();
  }

  // 构建统计项
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 记账统计信息卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '记账统计',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        '坚持记账',
                        '${_getAccountingDays()}天',
                        Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        '记录账单',
                        '${_getTotalRecords()}条',
                        Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '坚持记账第${_getAccountingDays()}天，已记录${_getTotalRecords()}条账单，继续保持！',
                          style: const TextStyle(
                            color: Colors.black54,
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
          const SizedBox(height: 20),
          
          const Text(
            '欢迎回来！',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // 账户概览卡片
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '账户总览',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildColoredStatItem('总资产', '¥125,360.00', Colors.green),
                      _buildColoredStatItem('本月支出', '¥8,520.00', Colors.orange),
                      _buildColoredStatItem('本月收入', '¥15,000.00', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
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

  Widget _buildColoredStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
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
  bool _biometricEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('安全设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('多因素认证'),
            subtitle: const Text('使用 TOTP 增强账户安全'),
            value: _mfaEnabled,
            onChanged: (bool value) {
              setState(() {
                _mfaEnabled = value;
              });
            },
            secondary: const Icon(Icons.security),
          ),
          SwitchListTile(
            title: const Text('生物识别'),
            subtitle: const Text('指纹或面部识别登录'),
            value: _biometricEnabled,
            onChanged: (bool value) {
              setState(() {
                _biometricEnabled = value;
              });
            },
            secondary: const Icon(Icons.fingerprint),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('修改密码'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('设备管理'),
            subtitle: const Text('管理已登录的设备'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('登录历史'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ],
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


