import 'package:flutter/material.dart';
import '../../services/wechat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/password_strength.dart';

/// 微信注册表单页面
class WeChatRegisterFormScreen extends StatefulWidget {
  final WeChatUserInfo weChatUserInfo;
  final WeChatAuthResult authResult;
  
  const WeChatRegisterFormScreen({
    super.key,
    required this.weChatUserInfo,
    required this.authResult,
  });

  @override
  State<WeChatRegisterFormScreen> createState() => _WeChatRegisterFormScreenState();
}

class _WeChatRegisterFormScreenState extends State<WeChatRegisterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  @override
  void initState() {
    super.initState();
    // 预填充用户名（基于微信昵称）
    _usernameController.text = _generateUsername(widget.weChatUserInfo.nickname);
    // 预填充邮箱（使用微信openid生成）
    _emailController.text = '${widget.authResult.openId}@wechat.jivemoney.com';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _generateUsername(String nickname) {
    // 清理昵称，只保留字母数字和中文
    String cleaned = nickname.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]'), '');
    if (cleaned.isEmpty) {
      cleaned = 'WeChatUser';
    }
    // 添加随机数字确保唯一性
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    return '${cleaned}_$timestamp';
  }

  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = PasswordStrengthChecker.checkStrength(password);
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 首先尝试注册账户
      final result = await _authService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result.success && result.userData != null) {
        // 注册成功后绑定微信
        final bindResult = await _authService.bindWechat();
        
        if (bindResult.success) {
          // 绑定成功，返回成功结果
          Navigator.of(context).pop({
            'success': true,
            'userData': result.userData,
            'message': '微信注册成功！',
          });
        } else {
          // 绑定失败但账户已创建，提示用户
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('账户创建成功，但微信绑定失败: ${bindResult.message}'),
              backgroundColor: Colors.orange,
            ),
          );
          
          Navigator.of(context).pop({
            'success': true,
            'userData': result.userData,
            'message': '账户创建成功，请手动绑定微信',
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? '注册失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('注册过程中发生错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('完善账户信息'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 微信用户信息展示
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: widget.weChatUserInfo.headImgUrl.isNotEmpty
                              ? NetworkImage(widget.weChatUserInfo.headImgUrl)
                              : null,
                          child: widget.weChatUserInfo.headImgUrl.isEmpty
                              ? const Icon(Icons.person, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.wechat, color: Colors.green, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.weChatUserInfo.nickname,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${widget.weChatUserInfo.country} ${widget.weChatUserInfo.province} ${widget.weChatUserInfo.city}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '微信授权成功',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  '请设置您的账户信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // 用户名输入
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '请输入用户名',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    helperText: '用户名将用于登录，3-20个字符',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(value)) {
                      return '用户名只能包含字母、数字、下划线和中文';
                    }
                    if (value.length < 3 || value.length > 20) {
                      return '用户名长度应为3-20个字符';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 邮箱输入（预填充，可修改）
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '邮箱地址',
                    hintText: '请输入邮箱地址',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                    helperText: '邮箱将用于登录和接收重要通知',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入邮箱地址';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                      return '请输入有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 密码输入
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '设置密码',
                    hintText: '请输入密码',
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
                    helperText: '密码长度至少6位，建议包含字母数字和特殊字符',
                  ),
                  obscureText: !_isPasswordVisible,
                  onChanged: _updatePasswordStrength,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 6) {
                      return '密码至少6位';
                    }
                    if (_passwordStrength == PasswordStrength.weak) {
                      return '密码强度太弱，请使用更复杂的密码';
                    }
                    return null;
                  },
                ),
                
                // 密码强度指示器
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '密码强度: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _passwordStrength.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: _passwordStrength.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _passwordStrength.value,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(_passwordStrength.color),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // 确认密码输入
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    hintText: '请再次输入密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请确认密码';
                    }
                    if (value != _passwordController.text) {
                      return '两次输入的密码不一致';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // 注册按钮
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            '完成注册',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 提示信息
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700], size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              '注册说明',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• 您的微信账户已成功授权\n'
                          '• 注册完成后将自动绑定微信账户\n'
                          '• 以后可以使用用户名/邮箱或微信登录\n'
                          '• 用户名一经设置不可修改',
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
    );
  }
}