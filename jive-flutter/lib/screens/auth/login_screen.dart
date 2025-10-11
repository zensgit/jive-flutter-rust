import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jive_money/services/auth_service.dart';
import 'package:jive_money/services/storage_service.dart';
import 'package:jive_money/widgets/wechat_login_button.dart';
import 'package:jive_money/widgets/auth/auth_text_field.dart';
import 'package:jive_money/core/router/app_router.dart';
import 'package:jive_money/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'superadmin@jive.money');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _rememberPassword = false;
  bool _rememberPermanently = false;
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  String? _emailError;
  String? _passwordError;

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

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool isValid = true;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _emailError = '请输入用户名或邮箱地址';
      });
      isValid = false;
    } else {
      bool isEmail = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
      bool isUsername = RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(email) &&
                       email.length >= 3 && email.length <= 20;

      if (!isEmail && !isUsername) {
        setState(() {
          _emailError = '请输入有效的用户名或邮箱地址';
        });
        isValid = false;
      }
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = '请输入密码';
      });
      isValid = false;
    } else if (password.length < 6) {
      setState(() {
        _passwordError = '密码至少6位';
      });
      isValid = false;
    }

    return isValid;
  }

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    if (!_validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _saveCredentials();
      debugPrint('DEBUG: Starting login for ${_emailController.text.trim()}');

      final success = await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            rememberMe: _rememberMe,
          );

      debugPrint('DEBUG: Login result: $success');

      if (mounted) {
        if (success) {
          final authState = ref.read(authControllerProvider);
          debugPrint('DEBUG: Login successful, user: ${authState.user?.name}');

          messenger.showSnackBar(
            SnackBar(
              content: Text('欢迎回来，${authState.user?.name ?? '用户'}！'),
              backgroundColor: Colors.green,
            ),
          );

          debugPrint('DEBUG: Navigating to dashboard');
          router.go(AppRoutes.dashboard);
        } else {
          final authState = ref.read(authControllerProvider);
          debugPrint('DEBUG: Login failed: ${authState.errorMessage}');

          messenger.showSnackBar(
            SnackBar(
              content: Text(authState.errorMessage ?? '登录失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('DEBUG: Login exception: $e');
      debugPrint('DEBUG: Stack trace: $stack');

      if (mounted) {
        messenger.showSnackBar(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  SvgPicture.asset(
                    'assets/images/Jiva.svg',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 24),

                  // 标题
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

                  const Text('用户名或邮箱', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _emailController,
                    hintText: '请输入用户名或邮箱地址',
                    icon: Icons.person,
                    errorText: _emailError,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    onSubmitted: (_) {},
                  ),
                  const SizedBox(height: 16),

                  const Text('密码', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _passwordController,
                    hintText: '请输入密码',
                    icon: Icons.lock,
                    obscureText: !_isPasswordVisible,
                    enableToggleObscure: true,
                    onObscureToggled: (newObscure) {
                      setState(() {
                        // newObscure = true => 内容被隐藏 => _isPasswordVisible = false
                        _isPasswordVisible = !newObscure;
                      });
                    },
                    errorText: _passwordError,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _isLoading ? null : _login(),
                  ),
                  const SizedBox(height: 16),

                  // 记住我选项
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: _isLoading ? null : (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                            if (!_rememberMe) {
                              _rememberPassword = false;
                              _rememberPermanently = false;
                            }
                          });
                        },
                      ),
                      const Text('记住用户名'),
                      const Spacer(),
                      if (_rememberMe)
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberPassword,
                              onChanged: _isLoading ? null : (value) {
                                setState(() {
                                  _rememberPassword = value ?? false;
                                });
                              },
                            ),
                            const Text('记住密码'),
                          ],
                        ),
                    ],
                  ),

                  // 永久记住选项
                  if (_rememberMe && _rememberPassword)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _rememberPermanently ? Colors.red[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _rememberPermanently ? Colors.red.shade200 : Colors.orange.shade200,
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
                                color: _rememberPermanently ? Colors.red[700] : Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '安全选项',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _rememberPermanently ? Colors.red[900] : Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberPermanently,
                                onChanged: _isLoading ? null : (value) {
                                  setState(() {
                                    _rememberPermanently = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '永久保存密码',
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      _rememberPermanently
                                          ? '⚠️ 密码将永久保存，请确保设备安全！'
                                          : '密码将在30天后自动清除',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _rememberPermanently ? Colors.red[700] : Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 登录按钮
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 24),

                  // TODO: 微信登录功能待添加回调函数
                  // WeChatLoginButton(
                  //   onSuccess: (authResult, userInfo) {},
                  //   onError: (error) {},
                  // ),

                  // 登录提示
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700], size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              '登录说明',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 默认管理员账号：superadmin@jive.money / admin123\n'
                          '• 支持用户名或邮箱登录\n'
                          '• 测试环境已预填充登录信息',
                          style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 注册链接
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('还没有账号？'),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                context.go(AppRoutes.register);
                              },
                        child: const Text('立即注册'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
