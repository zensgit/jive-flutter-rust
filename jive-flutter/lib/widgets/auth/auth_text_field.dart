import 'package:flutter/material.dart';

/// A minimal, reusable auth text field that avoids custom Row+Expanded
/// layout patterns which have triggered NaN layout issues in Flutter Web
/// CanvasKit when using a raw TextField with InputBorder.none.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final bool enableToggleObscure;
  final ValueChanged<bool>? onObscureToggled;
  final String? errorText;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final IconData? icon;

  const AuthTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.enableToggleObscure = false,
    this.onObscureToggled,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.icon,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final bool isFocused = _focusNode.hasFocus;

    Color borderColor;
    if (isError) {
      borderColor = Colors.red.shade400;
    } else if (isFocused) {
      borderColor = Colors.blue;
    } else {
      borderColor = Colors.grey.shade400;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(minHeight: 48),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            autocorrect: !(widget.obscureText),
            enableSuggestions: !(widget.obscureText),
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            autofillHints: widget.autofillHints,
            decoration: InputDecoration(
              prefixIcon: widget.icon != null ? Icon(widget.icon, color: Colors.grey) : null,
              hintText: widget.hintText,
              border: const OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              suffixIcon: widget.enableToggleObscure
                  ? IconButton(
                      icon: Icon(
                        widget.obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: !widget.enabled
                          ? null
                          : () {
                              widget.onObscureToggled?.call(!widget.obscureText);
                            },
                    )
                  : null,
            ),
          ),
        ),
        if (isError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              widget.errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

