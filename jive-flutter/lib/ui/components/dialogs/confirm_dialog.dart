// 确认对话框组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final IconData? icon;
  final bool isDangerous;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.icon,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          if (icon != null) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    (isDangerous ? AppConstants.errorColor : theme.primaryColor)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                icon,
                size: 32,
                color:
                    isDangerous ? AppConstants.errorColor : theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 标题
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // 消息
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // 按钮
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: cancelText ?? '取消',
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onCancel?.call();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: confirmText ?? '确认',
                  backgroundColor: isDangerous
                      ? AppConstants.errorColor
                      : (confirmColor ?? theme.primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    onConfirm?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 显示确认对话框
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
        isDangerous: isDangerous,
      ),
    );
  }

  /// 显示删除确认对话框
  static Future<bool?> showDelete({
    required BuildContext context,
    required String itemName,
    String? message,
  }) {
    return show(
      context: context,
      title: '删除$itemName',
      message: message ?? '确定要删除这个$itemName吗？此操作无法撤销。',
      confirmText: '删除',
      icon: Icons.delete_outline,
      isDangerous: true,
    );
  }

  /// 显示退出确认对话框
  static Future<bool?> showExit({
    required BuildContext context,
    String? message,
  }) {
    return show(
      context: context,
      title: '退出应用',
      message: message ?? '确定要退出应用吗？',
      confirmText: '退出',
      icon: Icons.exit_to_app,
    );
  }

  /// 显示保存确认对话框
  static Future<bool?> showSave({
    required BuildContext context,
    String? message,
  }) {
    return show(
      context: context,
      title: '保存更改',
      message: message ?? '您有未保存的更改，是否保存？',
      confirmText: '保存',
      icon: Icons.save_outlined,
    );
  }
}
