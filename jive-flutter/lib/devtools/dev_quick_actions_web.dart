// Web-only implementation with quick dev actions
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/storage/token_storage.dart';
import '../core/storage/hive_config.dart';

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
    final content = Stack(children: [
      widget.child,
      Positioned(
        left: _offset.dx,
        top: _offset.dy,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() => _offset += d.delta),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  width: 220,
                  child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _action('清 Token', () async { await TokenStorage.clearTokens(); _toast('Tokens cleared'); _reload(); }),
                      _action('清 Hive', () async { await HiveConfig.clearAll(); _toast('Hive cleared'); }),
                      _action('清 localStorage', () { html.window.localStorage.clear(); _toast('localStorage cleared'); }),
                      _action('清 全部+刷新', () async { await TokenStorage.clearAll(); await HiveConfig.clearAll(); html.window.localStorage.clear(); _toast('All cleared'); _reload(); }),
                      const Divider(color: Colors.white24),
                      _action('模拟过期', () async { await TokenStorage.saveTokenExpiry(DateTime.now().subtract(const Duration(minutes: 1))); _toast('Token expired set'); }),
                      _action('打印AuthInfo', () async { final info = await TokenStorage.getAuthInfo(); debugPrint('[Dev] AuthInfo: $info'); _toast('Logged'); }),
                    ]),
                  ),
                ),
              )
          ]),
        ),
      )
    ]);
    final hasDir = Directionality.maybeOf(context) != null;
    return hasDir ? content : Directionality(textDirection: TextDirection.ltr, child: content);
  }

  Widget _action(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onTap,
          child: Row(children: [
            const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(child: Text(label)),
          ]),
        ),
      );
  void _reload() => html.window.location.reload();
  void _toast(String msg) { if (!mounted) return; WidgetsBinding.instance.addPostFrameCallback((_) { if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));}); }
}
