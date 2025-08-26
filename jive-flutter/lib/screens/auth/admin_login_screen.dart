import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../admin/super_admin_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showTotpField = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 模拟登录验证
      await Future.delayed(const Duration(seconds: 1));
      
      // 获取输入的用户名和密码，并去除前后空格
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      
      // 调试信息
      print('输入的用户名: "$username" (长度: ${username.length})');
      print('输入的密码: "$password" (长度: ${password.length})');
      print('用户名匹配: ${username == 'superadmin'}');
      print('密码匹配: ${password == 'admin123'}');
      
      // 硬编码的超级管理员账户 (实际应用中应该从后端验证)
      if (username == 'superadmin' && password == 'admin123') {
        
        if (!_showTotpField) {
          // 第一步验证通过，显示TOTP字段
          setState(() {
            _showTotpField = true;
            _isLoading = false;
          });
          return;
        }
        
        // 验证TOTP (这里简化处理)
        if (_totpController.text == '123456') {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SuperAdminScreen(),
              ),
            );
          }
        } else {
          throw Exception('TOTP验证码错误');
        }
      } else {
        throw Exception('用户名或密码错误');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
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
      appBar: AppBar(
        title: const Text('系统管理员登录'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
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
                      '系统管理',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Text(
                      'Super Administrator',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // 安全提示
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '此页面仅供系统管理员使用\n需要双重认证验证',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 用户名输入框
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '管理员账户',
                        prefixIcon: Icon(Icons.admin_panel_settings),
                        border: OutlineInputBorder(),
                        fillColor: Colors.red,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入管理员账户';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 密码输入框
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '管理员密码',
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
                          return '请输入管理员密码';
                        }
                        return null;
                      },
                    ),
                    
                    // TOTP验证码输入框 (条件显示)
                    if (_showTotpField) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _totpController,
                        decoration: const InputDecoration(
                          labelText: 'TOTP验证码',
                          prefixIcon: Icon(Icons.verified_user),
                          border: OutlineInputBorder(),
                          helperText: '请输入6位TOTP验证码',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入TOTP验证码';
                          }
                          if (value.length != 6) {
                            return '验证码必须为6位数字';
                          }
                          return null;
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // 登录按钮
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : Text(
                                _showTotpField ? '验证并登录' : '下一步',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 演示账户信息
                    Card(
                      color: Colors.grey[100],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  '演示账户信息',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '账户: superadmin\n'
                              '密码: admin123\n'
                              'TOTP: 123456 (演示)',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 返回按钮
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('返回普通登录'),
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