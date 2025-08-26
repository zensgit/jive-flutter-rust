import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/wechat_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/wechat_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (mounted) {
        if (result.success) {
          // 登录成功，显示欢迎消息并导航到主页
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('欢迎回来，${result.userData?.username}！'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // 登录失败，显示错误消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? '登录失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录过程中发生错误: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo 和标题
                    SvgPicture.asset(
                      'assets/images/Jiva.svg',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Jive Money',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      '集腋记账',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // 用户名或邮箱输入框
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '用户名或邮箱',
                        hintText: '请输入用户名或邮箱地址',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        helperText: '支持用户名或邮箱地址登录',
                      ),
                      autocorrect: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入用户名或邮箱地址';
                        }
                        // 检查是否为有效的邮箱格式
                        bool isEmail = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value);
                        // 检查是否为有效的用户名格式
                        bool isUsername = RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(value) && value.length >= 3 && value.length <= 20;
                        
                        if (!isEmail && !isUsername) {
                          return '请输入有效的用户名或邮箱地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 密码输入框
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        if (value.length < 6) {
                          return '密码至少6位';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // 登录按钮
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Text(
                                '登录',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 注册链接
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/register');
                      },
                      child: const Text('还没有账户？点击注册'),
                    ),
                    
                    // 忘记密码链接
                    TextButton(
                      onPressed: () {
                        // TODO: 实现忘记密码功能
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('忘记密码功能暂未实现')),
                        );
                      },
                      child: const Text('忘记密码？'),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 分割线
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '或',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 微信登录按钮
                    WeChatLoginButton(
                      buttonText: '使用微信登录',
                      onSuccess: (authResult, userInfo) async {
                        final result = await _authService.wechatLogin();
                        
                        if (result.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('欢迎回来，${result.userData?.username}！'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pushReplacementNamed('/home');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.message ?? '微信登录失败'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      onError: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('微信登录失败: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 系统管理员登录链接
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/admin-login');
                      },
                      child: Text(
                        '系统管理员登录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 登录提示
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  '登录说明',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '• 支持用户名或邮箱地址登录\n'
                              '• 测试账户：demo / 密码：123456\n'
                              '• 测试账户：test / 密码：Test123!\n'
                              '• 管理账户：superadmin / 密码：admin123\n'
                              '• 也可以使用微信登录（模拟）',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}