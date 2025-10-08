import 'dart:html' as html; // Web only
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/storage/token_storage.dart';
import '../core/storage/hive_config.dart';

/// 开发阶段全局悬浮调试/清理按钮 (仅 Web & debug)
class DevQuickActions extends StatefulWidget {
  final Widget child;
  const DevQuickActions({super.key, required this.child});

  @override
  State<DevQuickActions> createState() => _DevQuickActionsState();
}

class _DevQuickActionsState extends State<DevQuickActions> {
  bool _open = false;
  Offset _offset = const Offset(16, 120);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !kIsWeb) return widget.child;
    debugPrint('@@ DevQuickActions build (has Directionality=${Directionality.maybeOf(context)!=null})');
    final content = Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _offset += d.delta),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              FloatingActionButton.small(
                heroTag: 'dev_fab',
                onPressed: () => setState(() => _open = !_open),
                child: Icon(_open ? Icons.close : Icons.build, size: 18),
              ),
              if (_open)
                Material(
                  color: Colors.transparent,
                  child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: 240,
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _actionButton(
                          label: '清除 Token (登出)',
                          onTap: () async {
                            await TokenStorage.clearTokens();
                            _toast('Tokens cleared');
                            _reload();
                          },
                        ),
                        _actionButton(
                          label: '清除 Hive/缓存',
                          onTap: () async {
                            await HiveConfig.clearAll();
                            _toast('Hive cleared');
                            _reload();
                          },
                        ),
                        _actionButton(
                          label: '清除 localStorage',
                          onTap: () {
                            html.window.localStorage.clear();
                            _toast('localStorage cleared');
                          },
                        ),
                        _actionButton(
                          label: '清除全部(含刷新)',
                          onTap: () async {
                            await TokenStorage.clearAll();
                            await HiveConfig.clearAll();
                            html.window.localStorage.clear();
                            _toast('All cleared');
                            _reload();
                          },
                        ),
                        const Divider(color: Colors.white24),
                        _actionButton(
                          label: '模拟 Token 过期',
                          onTap: () async {
                            await TokenStorage.saveTokenExpiry(DateTime.now().subtract(const Duration(minutes: 1)));
                            _toast('Token expiry set to past');
                          },
                        ),
                        _actionButton(
                          label: '打印 AuthInfo',
                          onTap: () async {
                            final info = await TokenStorage.getAuthInfo();
                            debugPrint('[Dev] AuthInfo: ' + info.toString());
                            _toast('AuthInfo logged');
                          },
                        ),
                      ],
                    ),
                  ),
                ))
              ],
            ),
          ),
        ),
      ],
    );
    // 兜底：如果还没有 Directionality（极早期构建阶段/某些集成测试场景），提供一个默认的 LTR，避免断言失败
    final hasDir = Directionality.maybeOf(context) != null;
    if (!hasDir) {
      debugPrint('@@ DevQuickActions injecting fallback Directionality');
    }
    return hasDir ? content : Directionality(textDirection: TextDirection.ltr, child: content);
  }

  Widget _actionButton({required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  void _reload() => html.window.location.reload();

  void _toast(String msg) {
    if (!mounted) return;
    // 延迟到下一帧，确保 Directionality / ScaffoldMessenger 就绪
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}
