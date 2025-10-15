import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 二维码生成器组件
class QrCodeGenerator extends StatefulWidget {
  final String data;
  final String title;
  final String? subtitle;
  final String? logo;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double size;
  final bool showActions;
  final VoidCallback? onShare;

  const QrCodeGenerator({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
    this.logo,
    this.foregroundColor,
    this.backgroundColor,
    this.size = 280,
    this.showActions = true,
    this.onShare,
  });

  @override
  State<QrCodeGenerator> createState() => _QrCodeGeneratorState();
}

class _QrCodeGeneratorState extends State<QrCodeGenerator>
    with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 延迟显示动画
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isGenerating = false);
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _shareQrCode() async {
    try {
      // 获取二维码图片
      final image = await _captureQrCode();
      if (image == null) return;

      // 保存到临时文件
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      // 分享
      await SharePlus.instance.share(
        ShareParams(files: [XFile(imagePath)], text: '${widget.title}\n${widget.subtitle ?? ''}\n${widget.data}'),
      );

      // 触发回调
      widget.onShare?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _captureQrCode() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.data));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveQrCode() async {
    try {
      final image = await _captureQrCode();
      if (image == null) return;

      // 获取保存路径
      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('二维码已保存到: $imagePath'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                // TODO: 打开文件管理器
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrForegroundColor =
        widget.foregroundColor ?? theme.colorScheme.onSurface;
    final qrBackgroundColor =
        widget.backgroundColor ?? theme.colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Text(
          widget.title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 24),

        // 二维码
        Center(
          child: _isGenerating
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : ScaleTransition(
                  scale: _scaleAnimation,
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: qrBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: widget.data,
                        version: QrVersions.auto,
                        size: widget.size,
                        backgroundColor: qrBackgroundColor,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square),
                        dataModuleStyle: QrDataModuleStyle(color: qrForegroundColor, dataModuleShape: QrDataModuleShape.square),
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        embeddedImage: widget.logo != null
                            ? AssetImage(widget.logo!)
                            : null,
                        padding: const EdgeInsets.all(0),
                      ),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 24),

        // 数据内容
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.data,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: _copyToClipboard,
                tooltip: '复制链接',
              ),
            ],
          ),
        ),

        // 操作按钮
        if (widget.showActions) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.share,
                label: '分享',
                onPressed: _shareQrCode,
              ),
              _ActionButton(
                icon: Icons.save_alt,
                label: '保存',
                onPressed: _saveQrCode,
              ),
              _ActionButton(
                icon: Icons.refresh,
                label: '刷新',
                onPressed: () {
                  setState(() => _isGenerating = true);
                  _animationController.reset();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() => _isGenerating = false);
                      _animationController.forward();
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 邀请二维码弹窗
class InvitationQrCodeDialog extends StatelessWidget {
  final String inviteCode;
  final String inviteLink;
  final String familyName;
  final String role;
  final DateTime expiresAt;

  const InvitationQrCodeDialog({
    super.key,
    required this.inviteCode,
    required this.inviteLink,
    required this.familyName,
    required this.role,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 关闭按钮
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // 二维码
            QrCodeGenerator(
              data: inviteLink,
              title: '邀请加入家庭',
              subtitle: familyName,
              size: 200,
              showActions: false,
            ),

            const SizedBox(height: 16),

            // 邀请信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.vpn_key,
                    label: '邀请码',
                    value: inviteCode,
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.person,
                    label: '角色',
                    value: role,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.timer,
                    label: '有效期',
                    value: '$daysLeft 天',
                    valueColor: daysLeft <= 3 ? Colors.orange : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('复制链接'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('链接已复制')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('分享'),
                    onPressed: () async {
                      await SharePlus.instance.share(ShareParams(text: 
                        '邀请你加入家庭「$familyName」\n\n'
                        '邀请码：$inviteCode\n'
                        '点击链接加入：$inviteLink\n\n'
                        '有效期：$daysLeft 天',
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : null,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}


// Stub implementation for XFile
class _StubXFile {
  final String path;
  _StubXFile(this.path);
}
