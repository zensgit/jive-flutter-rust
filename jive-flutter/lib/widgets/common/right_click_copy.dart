import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用右键/长按复制组件
/// 用法：
/// RightClickCopy(
///   copyText: someString,
///   child: Text(someString),
/// )
/// 右键（Web/PC）或长按（移动端）将复制 copyText 到剪贴板，并显示 SnackBar。
class RightClickCopy extends StatelessWidget {
  final Widget child;
  final String copyText;
  final String successMessage;
  final bool showIconOnHover;
  final EdgeInsets? padding;

  const RightClickCopy({
    super.key,
    required this.child,
    required this.copyText,
    this.successMessage = '已复制',
    this.showIconOnHover = false,
    this.padding,
  });

  void _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) return;
    // 避免没有 Scaffold 的场景报错
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final result = // ignore: use_build_context_synchronously (pre-captured messenger, no context use after await)
    await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('复制'),
            ],
          ),
        ),
      ],
    );
    if (result == 'copy') {
      await _copyWithMessenger(messenger);
    }
  }

  Future<void> _copyWithMessenger(ScaffoldMessenger? messenger) async {
    await Clipboard.setData(ClipboardData(text: copyText));
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (showIconOnHover) {
      content = _HoverCopyIconWrapper(copyText: copyText, child: child);
    }

    content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: content,
    );

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onLongPress: () {
        // 移动端长按直接复制
        final messenger = ScaffoldMessenger.maybeOf(context);
        _copyWithMessenger(messenger);
      },
      child: content,
    );
  }
}

/// 可选：鼠标悬停显示复制图标的包装器
class _HoverCopyIconWrapper extends StatefulWidget {
  final Widget child;
  final String copyText;
  const _HoverCopyIconWrapper({required this.child, required this.copyText});

  @override
  State<_HoverCopyIconWrapper> createState() => _HoverCopyIconWrapperState();
}

class _HoverCopyIconWrapperState extends State<_HoverCopyIconWrapper> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_hovering && kIsWeb)
            Positioned(
              top: -4,
              right: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
