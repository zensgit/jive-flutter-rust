import 'package:flutter/material.dart';
import '../../services/wechat_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/wechat_login_button.dart';

/// 微信绑定设置页面
class WeChatBindingScreen extends StatefulWidget {
  const WeChatBindingScreen({super.key});

  @override
  State<WeChatBindingScreen> createState() => _WeChatBindingScreenState();
}

class _WeChatBindingScreenState extends State<WeChatBindingScreen> {
  WeChatBindingData? _weChatInfo;
  bool _isLoading = false;
  bool _isInitialized = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeWeChatService();
    _loadWeChatInfo();
  }

  Future<void> _initializeWeChatService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool initialized = await WeChatService.initWeChat();
      setState(() {
        _isInitialized = initialized;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化微信SDK失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _handleBind(WeChatAuthResult authResult, WeChatUserInfo userInfo) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.bindWechat();
      
      if (result.success) {
        await _loadWeChatInfo(); // 重新加载绑定信息
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? '微信账户绑定成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? '绑定失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('绑定过程中发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnbind() async {
    // 确认对话框
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

    if (confirmed != true) return;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('解绑过程中发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微信绑定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 说明信息
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              const Text(
                                '关于微信绑定',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• 绑定微信后可使用微信快速登录\n'
                            '• 支持微信扫码和微信内授权登录\n'
                            '• 绑定信息仅用于身份验证\n'
                            '• 可随时解绑微信账户',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 微信绑定卡片
                  if (_weChatInfo != null) ...[
                    // 已绑定状态
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wechat, color: Color(0xFF07C160)),
                                const SizedBox(width: 8),
                                const Text(
                                  '已绑定微信账户',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: _weChatInfo!.headImgUrl.isNotEmpty
                                      ? NetworkImage(_weChatInfo!.headImgUrl)
                                      : null,
                                  child: _weChatInfo!.headImgUrl.isEmpty
                                      ? const Icon(Icons.person, size: 30)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _weChatInfo!.nickname,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '性别: ${_weChatInfo!.sexText}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '地区: ${_weChatInfo!.country} ${_weChatInfo!.province} ${_weChatInfo!.city}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _handleUnbind,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                        ),
                                      )
                                    : const Text('解绑微信账户'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // 未绑定状态
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wechat_outlined, color: Color(0xFF07C160)),
                                const SizedBox(width: 8),
                                const Text(
                                  '绑定微信账户',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            const Text(
                              '绑定微信账户后，您可以使用微信快速登录，让使用更加便捷。',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            WeChatLoginButton(
                              buttonText: '绑定微信账户',
                              isBinding: true,
                              onSuccess: _handleBind,
                              onError: (error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('绑定失败: $error')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // 安全提示
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              const Text(
                                '安全提示',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• 请确保在安全的网络环境下进行绑定操作\n'
                            '• 如发现异常登录，请及时解绑并修改密码\n'
                            '• 建议同时开启多因素认证增强安全性',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}