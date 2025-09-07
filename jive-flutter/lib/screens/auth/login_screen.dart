import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/wechat_login_button.dart';
import '../../core/router/app_router.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'superadmin');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _rememberPassword = false;
  bool _rememberPermanently = false;
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// 加载保存的登录凭据
  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await _storageService.getRememberedCredentials();
      if (credentials != null && !credentials.isExpired) {
        setState(() {
          _emailController.text = credentials.username;
          _rememberMe = true;
          _rememberPermanently = credentials.rememberPermanently;
          
          if (credentials.rememberPassword) {
            _passwordController.text = credentials.password;
            _rememberPassword = true;
          }
        });
      }
    } catch (e) {
      debugPrint('加载保存的凭据失败: $e');
    }
  }

  /// 保存登录凭据
  Future<void> _saveCredentials() async {
    if (_rememberMe && _emailController.text.trim().isNotEmpty) {
      try {
        final credentials = RememberedCredentials(
          username: _emailController.text.trim(),
          password: _rememberPassword ? _passwordController.text : '',
          rememberPassword: _rememberPassword,
          rememberPermanently: _rememberPermanently,
          savedAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        );
        await _storageService.saveRememberedCredentials(credentials);
      } catch (e) {
        debugPrint('保存登录凭据失败: $e');
      }
    } else {
      // 如果不记住密码，清除保存的凭据
      await _storageService.clearRememberedCredentials();
    }
  }

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
      // 保存登录凭据
      await _saveCredentials();
      
      print('DEBUG: Starting login for ${_emailController.text.trim()}');
      
      // 使用AuthController的login方法
      final success = await ref.read(authControllerProvider.notifier).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      
      print('DEBUG: Login result: $success');
      
      if (mounted) {
        if (success) {
          final authState = ref.read(authControllerProvider);
          print('DEBUG: Login successful, user: ${authState.user?.name}');
          
          // 登录成功，显示欢迎消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('欢迎回来，${authState.user?.name ?? '用户'}！'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 直接跳转到仪表板
          print('DEBUG: Navigating to dashboard');
          context.go(AppRoutes.dashboard);
        } else {
          final authState = ref.read(authControllerProvider);
          print('DEBUG: Login failed: ${authState.errorMessage}');
          
          // 登录失败，显示错误消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authState.errorMessage ?? '登录失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stack) {
      print('DEBUG: Login exception: $e');
      print('DEBUG: Stack trace: $stack');
      
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
                    const SizedBox(height: 16),
                    
                    // 记住密码选项
                    Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                  if (!_rememberMe) {
                                    _rememberPassword = false;
                                    _rememberPermanently = false;
                                  }
                                });
                              },
                            ),
                            const Text('记住账号'),
                            const SizedBox(width: 16),
                            Checkbox(
                              value: _rememberPassword && _rememberMe,
                              onChanged: _rememberMe ? (value) {
                                setState(() {
                                  _rememberPassword = value ?? false;
                                });
                              } : null,
                            ),
                            const Text('记住密码'),
                            const Spacer(),
                            TextButton(
                              onPressed: () async {
                                // 清除保存的凭据
                                await _storageService.clearRememberedCredentials();
                                setState(() {
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _rememberMe = false;
                                  _rememberPassword = false;
                                  _rememberPermanently = false;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已清除保存的登录信息'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                '清除',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        // 永久记住选项（测试专用）
                        if (_rememberPassword)
                          Row(
                            children: [
                              const SizedBox(width: 12),
                              Checkbox(
                                value: _rememberPermanently,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberPermanently = value ?? false;
                                  });
                                },
                              ),
                              const Text(
                                '永久记住（测试模式）',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.warning_amber,
                                size: 16,
                                color: Colors.orange[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '永不过期',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    
                    // 安全提示
                    if (_rememberPassword)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _rememberPermanently ? Colors.red[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _rememberPermanently ? Colors.red[200]! : Colors.orange[200]!
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _rememberPermanently ? Icons.warning : Icons.security,
                                  size: 16,
                                  color: _rememberPermanently ? Colors.red[600] : Colors.orange[600],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _rememberPermanently
                                        ? '⚠️ 永久记住模式 - 测试专用'
                                        : '密码将保存在本地，请确保设备安全',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _rememberPermanently ? Colors.red[700] : Colors.orange[700],
                                      fontWeight: _rememberPermanently ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_rememberPermanently) ...[
                              const SizedBox(height: 4),
                              Text(
                                '• 凭据永不过期，适合测试环境\n• 生产环境请取消永久记住选项\n• 定期清除凭据确保安全',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[600],
                                  height: 1.3,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                '• 凭据30天后自动过期\n• 仅保存在本地设备',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[600],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    
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
                        context.push(AppRoutes.register);
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
                          context.go(AppRoutes.dashboard);
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
                              '• 管理员账户：admin / 密码：admin123\n'
                              '• 邮箱和密码请填写完整\n'
                              '• 确保后端API服务正在运行\n'
                              '• 也可以使用微信登录（模拟）\n'
                              '• 记住功能：账号+密码（30天）或永久记住（测试用）',
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