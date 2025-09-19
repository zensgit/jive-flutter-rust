import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 可选择文本组件 - 支持右键复制
class SelectableTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool showCursor;
  final double cursorWidth;
  final double? cursorHeight;
  final Color? cursorColor;

  const SelectableTextWidget({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.showCursor = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      showCursor: showCursor,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorColor: cursorColor,
      // 启用工具栏（复制、全选等）
      enableInteractiveSelection: true,
      // 自定义选择工具栏
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar(
          anchors: editableTextState.contextMenuAnchors,
          children: [
            // 复制按钮
            TextSelectionToolbarTextButton(
              padding: TextSelectionToolbarTextButton.getPadding(0, 2),
              onPressed: () {
                editableTextState.copySelection(SelectionChangedCause.toolbar);
                editableTextState.hideToolbar();
              },
              child: Text('复制'),
            ),
            // 全选按钮
            TextSelectionToolbarTextButton(
              padding: TextSelectionToolbarTextButton.getPadding(1, 2),
              onPressed: () {
                editableTextState.selectAll(SelectionChangedCause.toolbar);
              },
              child: Text('全选'),
            ),
          ],
        );
      },
    );
  }
}

/// 可选择的富文本组件
class SelectableRichTextWidget extends StatelessWidget {
  final TextSpan textSpan;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool showCursor;

  const SelectableRichTextWidget({
    super.key,
    required this.textSpan,
    this.textAlign,
    this.maxLines,
    this.showCursor = false,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      textSpan,
      textAlign: textAlign,
      maxLines: maxLines,
      showCursor: showCursor,
      enableInteractiveSelection: true,
    );
  }
}

/// 带右键菜单的容器
class SelectableContainer extends StatelessWidget {
  final Widget child;
  final String? textToCopy;
  final VoidCallback? onCopy;

  const SelectableContainer({
    super.key,
    required this.child,
    this.textToCopy,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        if (textToCopy != null || onCopy != null) {
          _showContextMenu(context, details.globalPosition);
        }
      },
      child: child,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20),
              const SizedBox(width: 8),
              Text('复制'),
            ],
          ),
          onTap: () {
            if (textToCopy != null) {
              Clipboard.setData(ClipboardData(text: textToCopy!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            onCopy?.call();
          },
        ),
      ],
    );
  }
}

/// 表格中的可选择单元格
class SelectableTableCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final EdgeInsets? padding;
  final AlignmentGeometry? alignment;

  const SelectableTableCell({
    super.key,
    required this.text,
    this.style,
    this.padding,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return TableCell(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8.0),
        child: Align(
          alignment: alignment ?? Alignment.centerLeft,
          child: SelectableTextWidget(
            text: text,
            style: style,
          ),
        ),
      ),
    );
  }
}

/// 列表项中的可选择文本
class SelectableListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const SelectableListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: SelectableTextWidget(
        text: title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: subtitle != null
          ? SelectableTextWidget(
              text: subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: contentPadding,
    );
  }
}
