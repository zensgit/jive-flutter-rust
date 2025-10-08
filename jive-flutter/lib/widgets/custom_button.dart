import 'package:flutter/material.dart';

/// Custom button widget for consistent styling across the app
class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final IconData? icon;
  final ButtonStyle? style;
  final bool expanded;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.icon,
    this.style,
    this.expanded = true,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style ??
          ElevatedButton.styleFrom(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                )
              : Text(
                  text,
                  style: const TextStyle(fontSize: 16),
                ),
    );

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

/// Custom text button for secondary actions
class CustomTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final TextStyle? textStyle;

  const CustomTextButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 4),
                Text(text, style: textStyle),
              ],
            )
          : Text(text, style: textStyle),
    );
  }
}

/// Custom outlined button for tertiary actions
class CustomOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final ButtonStyle? style;
  final bool expanded;

  const CustomOutlinedButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.style,
    this.expanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: style ??
          OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(text),
              ],
            )
          : Text(text),
    );

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}