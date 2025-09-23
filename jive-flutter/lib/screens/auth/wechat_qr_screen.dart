import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jive_money/services/wechat_service.dart';
import 'package:jive_money/screens/auth/wechat_register_form_screen.dart';

/// 微信二维码扫描页面
class WeChatQRScreen extends StatefulWidget {
  final bool isLogin; // true为登录，false为注册

  const WeChatQRScreen({
    super.key,
    this.isLogin = true,
  });

  @override
  State<WeChatQRScreen> createState() => _WeChatQRScreenState();
}

class _WeChatQRScreenState extends State<WeChatQRScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  bool _isScanning = true;
  bool _scanSuccess = false;
  String _statusText = '请使用微信扫描二维码';

  @override
  void initState() {
    super.initState();

    // 脉搏动画控制器
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 扫描线动画控制器
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear,
    ));

    // 开始动画
    _pulseController.repeat(reverse: true);
    _scanController.repeat();

    // 模拟扫码过程
    _simulateQRScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _simulateQRScan() async {
    // 等待5秒模拟用户扫码
    await Future.delayed(const Duration(seconds: 5));

    if (mounted) {
      setState(() {
        _statusText = '扫描成功！正在获取微信信息...';
        _scanSuccess = true;
        _isScanning = false;
      });

      _pulseController.stop();
      _scanController.stop();

      // 再等待2秒模拟获取信息
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // 获取微信用户信息
        try {
          final userInfo = await WeChatService.simulateGetUserInfo();
          final authResult = await WeChatService.simulateLogin();
          if (!context.mounted) return;

          if (userInfo != null && authResult != null) {
            if (widget.isLogin) {
              // 登录流程：直接返回结果
              Navigator.of(context).pop({
                'success': true,
                'authResult': authResult,
                'userInfo': userInfo,
              });
            } else {
              // 注册流程：跳转到注册表单
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WeChatRegisterFormScreen(
                    weChatUserInfo: userInfo,
                    authResult: authResult,
                  ),
                ),
              );

              if (!context.mounted) return;

              if (result != null) {
                Navigator.of(context).pop(result);
              }
            }
          }
        } catch (e) {
          setState(() {
            _statusText = '获取微信信息失败，请重试';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLogin ? '微信登录' : '微信注册'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              SvgPicture.asset(
                'assets/images/Jiva.svg',
                width: 60,
                height: 60,
              ),
              const SizedBox(height: 20),

              const Text(
                'Jive Money',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 40),

              // 二维码区域
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isScanning ? _pulseAnimation.value : 1.0,
                      child: Stack(
                        children: [
                          // 二维码背景
                          Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _scanSuccess
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _scanSuccess
                                    ? Colors.green
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: _scanSuccess
                                  ? Icon(
                                      Icons.check_circle,
                                      size: 80,
                                      color: Colors.green[600],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'QR\nCODE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '模拟二维码',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // 扫描线动画
                          if (_isScanning)
                            AnimatedBuilder(
                              animation: _scanAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: 20 + (_scanAnimation.value * 180),
                                  left: 20,
                                  right: 20,
                                  child: Container(
                                    height: 2,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.green,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // 四角装饰
                          ...List.generate(4, (index) {
                            final isTop = index < 2;
                            final isLeft = index % 2 == 0;

                            return Positioned(
                              top: isTop ? 15 : null,
                              bottom: isTop ? null : 15,
                              left: isLeft ? 15 : null,
                              right: isLeft ? null : 15,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: isTop
                                        ? const BorderSide(
                                            color: Colors.green, width: 3)
                                        : BorderSide.none,
                                    bottom: isTop
                                        ? BorderSide.none
                                        : const BorderSide(
                                            color: Colors.green, width: 3),
                                    left: isLeft
                                        ? const BorderSide(
                                            color: Colors.green, width: 3)
                                        : BorderSide.none,
                                    right: isLeft
                                        ? BorderSide.none
                                        : const BorderSide(
                                            color: Colors.green, width: 3),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // 状态文字
              Text(
                _statusText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 提示文字
              if (_isScanning) ...[
                Text(
                  widget.isLogin ? '使用微信扫描二维码即可快速登录' : '扫码后需要设置账户信息完成注册',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 加载指示器
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ],

              const SizedBox(height: 40),

              // 取消按钮
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop({'success': false});
                },
                child: const Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
