// 次要按钮组件
import 'package:flutter/material.dart';
import 'package:jive_money/core/constants/app_constants.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double height;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height = 50,
    this.icon,
    this.borderColor,
    this.textColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !isDisabled && !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? theme.primaryColor,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          side: BorderSide(
            color: isEnabled
                ? (borderColor ?? theme.primaryColor)
                : theme.disabledColor,
            width: 1.5,
          ),
        ),
        icon: _buildIcon(theme),
        label: _buildLabel(),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            textColor ?? theme.primaryColor,
          ),
        ),
      );
    }

    if (icon != null) {
      return Icon(icon, size: 20);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLabel() {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
