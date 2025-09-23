import 'package:flutter/material.dart';
import 'package:jive_money/services/wechat_service.dart';
import 'package:jive_money/screens/auth/wechat_qr_screen.dart';

/// 微信登录按钮组件
class WeChatLoginButton extends StatefulWidget {
  final Function(WeChatAuthResult, WeChatUserInfo) onSuccess;
  final Function(String) onError;
  final String buttonText;
  final bool isBinding; // 是否为绑定操作

  const WeChatLoginButton({
    super.key,
    required this.onSuccess,
    required this.onError,
    this.buttonText = '微信登录',
    this.isBinding = false,
  });

  @override
  State<WeChatLoginButton> createState() => _WeChatLoginButtonState();
}

class _WeChatLoginButtonState extends State<WeChatLoginButton> {
  bool _isLoading = false;

  Future<void> _handleWeChatLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 显示二维码扫描界面
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => WeChatQRScreen(
            isLogin: !widget.buttonText.contains('注册'), // 根据按钮文字判断是登录还是注册
          ),
        ),
      );

      if (result != null && result['success'] == true) {
        if (result.containsKey('authResult') &&
            result.containsKey('userInfo')) {
          // 直接登录成功
          widget.onSuccess(result['authResult'], result['userInfo']);
        } else if (result.containsKey('userData')) {
          // 注册成功，需要创建模拟的授权结果
          final authResult = WeChatAuthResult(
            code: 'registered_${DateTime.now().millisecondsSinceEpoch}',
            openId: 'registered_openid',
            expiresIn: 7200,
          );
          final userInfo = WeChatUserInfo(
            openId: 'registered_openid',
            nickname: result['userData'].username,
            headImgUrl: '',
            sex: 0,
            province: '',
            city: '',
            country: '',
          );
          widget.onSuccess(authResult, userInfo);
        }
      } else if (result != null && result['success'] == false) {
        widget.onError('用户取消了微信授权');
      }
    } catch (e) {
      widget.onError('微信登录出现错误: $e');
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleWeChatLogin,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF07C160), // 微信绿色
          side: const BorderSide(color: Color(0xFF07C160)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF07C160)),
                ),
              )
            : const Icon(Icons.wechat_outlined, size: 24),
        label: Text(
          widget.buttonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 微信绑定卡片组件
class WeChatBindingCard extends StatelessWidget {
  final WeChatUserInfo? weChatInfo;
  final VoidCallback? onBind;
  final VoidCallback? onUnbind;
  final bool isLoading;

  const WeChatBindingCard({
    super.key,
    this.weChatInfo,
    this.onBind,
    this.onUnbind,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wechat, color: Color(0xFF07C160)),
                SizedBox(width: 8),
                Text(
                  '微信账户',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (weChatInfo != null) ...[
              // 已绑定状态
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: weChatInfo!.headImgUrl.isNotEmpty
                        ? NetworkImage(weChatInfo!.headImgUrl)
                        : null,
                    child: weChatInfo!.headImgUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weChatInfo!.nickname,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${weChatInfo!.country} ${weChatInfo!.province} ${weChatInfo!.city}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onUnbind,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          : const Text('解绑'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 未绑定状态
              const Text(
                '绑定微信账户后，您可以使用微信快速登录',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              WeChatLoginButton(
                buttonText: '绑定微信账户',
                isBinding: true,
                onSuccess: (authResult, userInfo) {
                  // 处理绑定成功
                  if (onBind != null) onBind!();
                },
                onError: (error) {
                  // 处理绑定失败
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('绑定失败: $error')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
