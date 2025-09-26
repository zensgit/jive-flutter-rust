import 'dart:async';
import 'package:flutter/material.dart';

// 微信二维码绑定对话框
class WeChatQRBindingDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const WeChatQRBindingDialog({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<WeChatQRBindingDialog> createState() => _WeChatQRBindingDialogState();
}

class _WeChatQRBindingDialogState extends State<WeChatQRBindingDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isScanning = true;
  int _countdown = 120; // 2分钟倒计时
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 动画控制器
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.repeat(reverse: true);

    // 开始倒计时
    _startCountdown();

    // 实际微信绑定 - 不再使用模拟
    // Timer(const Duration(seconds: 8), () {
    //   if (mounted && _isScanning) {
    //     _handleScanSuccess();
    //   }
    // });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        if (mounted && _isScanning) {
          setState(() {
            _isScanning = false;
          });
        }
      }
    });
  }

  void _handleScanSuccess() {
    setState(() {
      _isScanning = false;
    });

    _animationController.stop();

    // 显示成功动画
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '扫码成功！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('正在绑定微信账户...'),
          ],
        ),
      ),
    );

    // 2秒后关闭并调用成功回调
    Timer(const Duration(seconds: 2), () {
      Navigator.pop(context); // 关闭成功对话框
      widget.onSuccess();
    });
  }

  void _refreshQR() {
    setState(() {
      _isScanning = true;
      _countdown = 120;
    });
    _animationController.repeat(reverse: true);
    _startCountdown();

    // 实际刷新二维码 - 不再使用模拟
    // Timer(const Duration(seconds: 8), () {
    //   if (mounted && _isScanning) {
    //     _handleScanSuccess();
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.wechat,
                    color: Colors.green[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '绑定微信账户',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 二维码区域
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isScanning ? _buildQRCode() : _buildExpiredQR(),
            ),

            const SizedBox(height: 16),

            // 状态文本
            if (_isScanning) ...[
              Text(
                '请使用微信扫描二维码',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '二维码$_countdown秒后过期',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Text(
                '二维码已过期',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _refreshQR,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新二维码'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                ),
              ),
            ],

            // 测试按钮 - 仅用于演示
            if (_isScanning) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _handleScanSuccess(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('模拟扫码成功 (测试用)'),
              ),
            ],

            const SizedBox(height: 24),

            // 说明文本
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        '绑定说明',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 打开微信，点击右上角"+"号\n'
                    '• 选择"扫一扫"功能\n'
                    '• 对准屏幕上的二维码扫描\n'
                    '• 确认绑定即可完成操作',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCode() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: _scaleAnimation.value * 0.1 + 0.9,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      // 模拟二维码图案
                      Positioned.fill(
                        child: CustomPaint(
                          painter: QRCodePainter(),
                        ),
                      ),
                      // 中心logo
                      Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.wechat,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '扫码中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiredQR() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  '已过期',
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
    );
  }
}

// 自定义二维码绘制器
class QRCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final blockSize = size.width / 25;

    // 绘制随机的二维码模式
    for (int i = 0; i < 25; i++) {
      for (int j = 0; j < 25; j++) {
        if ((i + j) % 3 == 0 ||
            (i * j) % 7 == 0 ||
            (i == 0 || i == 24 || j == 0 || j == 24) ||
            (i >= 0 && i <= 6 && j >= 0 && j <= 6) ||
            (i >= 18 && i <= 24 && j >= 0 && j <= 6) ||
            (i >= 0 && i <= 6 && j >= 18 && j <= 24)) {
          canvas.drawRect(
            Rect.fromLTWH(
              i * blockSize,
              j * blockSize,
              blockSize,
              blockSize,
            ),
            paint,
          );
        }
      }
    }

    // 绘制三个角落的定位标记
    _drawPositionMarker(canvas, paint, const Offset(0, 0), blockSize);
    _drawPositionMarker(canvas, paint, Offset(18 * blockSize, 0), blockSize);
    _drawPositionMarker(canvas, paint, Offset(0, 18 * blockSize), blockSize);
  }

  void _drawPositionMarker(
      Canvas canvas, Paint paint, Offset offset, double blockSize) {
    // 外框
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, blockSize * 7, blockSize * 7),
      paint,
    );

    // 内部白色
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + blockSize, offset.dy + blockSize, blockSize * 5,
          blockSize * 5),
      paint,
    );

    // 中心黑块
    paint.color = Colors.black;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + blockSize * 2, offset.dy + blockSize * 2,
          blockSize * 3, blockSize * 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
