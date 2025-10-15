import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jive_money/models/theme_models.dart' as models;
import 'package:jive_money/services/theme_service.dart';

/// 主题分享对话框
class ThemeShareDialog extends StatefulWidget {
  final models.CustomThemeData theme;

  const ThemeShareDialog({
    super.key,
    required this.theme,
  });

  @override
  State<ThemeShareDialog> createState() => _ThemeShareDialogState();
}

class _ThemeShareDialogState extends State<ThemeShareDialog> {
  final ThemeService _themeService = ThemeService();
  String? _shareCode;
  String? _shareUrl;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.share, color: Colors.blue[600]),
          const SizedBox(width: 8),
          const Text('分享主题'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主题信息
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.theme.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.theme.author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '作者: ${widget.theme.author}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (widget.theme.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.theme.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 分享选项
            if (_shareCode == null) ...[
              const Text('选择分享方式：'),
              const SizedBox(height: 12),

              // 生成分享链接
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSharing ? null : _generateShareLink,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_isSharing ? '生成中...' : '生成分享链接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 复制到剪贴板
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.content_copy),
                  label: const Text('复制主题数据'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              // 分享结果
              const Text(
                '分享链接已生成：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // 分享码
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '分享码：',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _shareCode!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyText(_shareCode!),
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: '复制分享码',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 分享链接
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '分享链接：',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _shareUrl!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copyText(_shareUrl!),
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: '复制链接',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 说明文本
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        const Text(
                          '使用说明',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• 分享码30天内有效\n'
                      '• 可以通过分享码或链接导入主题\n'
                      '• 在主题管理页面选择"输入分享码"导入',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        if (_shareCode != null)
          ElevatedButton.icon(
            onPressed: _shareToSystem,
            icon: const Icon(Icons.share),
            label: const Text('分享到其他应用'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Future<void> _generateShareLink() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final shareCode = await _themeService.shareTheme(widget.theme.id);
      if (!context.mounted) return;
      setState(() {
        _shareCode = shareCode;
        _shareUrl = 'https://jivemoney.com/theme/import/$shareCode';
        _isSharing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分享链接生成成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isSharing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成分享链接失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      await _themeService.copyThemeToClipboard(widget.theme.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('主题数据已复制到剪贴板'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      // ignore: use_build_context_synchronously
      messenger.showSnackBar(
        SnackBar(
          content: Text('复制失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareToSystem() {
    final shareText = '''
🎨 分享一个 Jive Money 主题

主题名称：${widget.theme.name}
作者：${widget.theme.author}
${widget.theme.description.isNotEmpty ? '描述：${widget.theme.description}\n' : ''}

分享码：$_shareCode
分享链接：$_shareUrl

在 Jive Money 应用中的"主题设置"页面，选择"输入分享码"即可导入此主题。
''';

    // 这里应该调用系统分享功能
    // 由于是演示，我们将文本复制到剪贴板
    Clipboard.setData(ClipboardData(text: shareText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('分享内容已复制到剪贴板，可以粘贴到其他应用分享'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
