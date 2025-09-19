import 'package:flutter/material.dart';

/// 错误状态组件
class ErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final bool showDetails;
  final EdgeInsetsGeometry padding;

  const ErrorState({
    super.key,
    this.title,
    this.message,
    this.error,
    this.onRetry,
    this.showDetails = false,
    this.padding = const EdgeInsets.all(32.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage = _getErrorMessage();

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              title ?? '出错了',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (showDetails && error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getErrorMessage() {
    if (error == null) {
      return '发生了未知错误';
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return '网络连接失败，请检查您的网络设置';
    }

    if (errorString.contains('timeout')) {
      return '请求超时，请稍后重试';
    }

    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return '认证失败，请重新登录';
    }

    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return '您没有权限访问此内容';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return '请求的内容不存在';
    }

    if (errorString.contains('server') || errorString.contains('500')) {
      return '服务器错误，请稍后重试';
    }

    return '加载失败，请稍后重试';
  }
}

/// 错误边界组件
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    // Flutter错误处理
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });
    };
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }

      return ErrorState(
        error: _error,
        onRetry: _retry,
        showDetails: true,
      );
    }

    return widget.child;
  }
}

/// 错误提示条
class ErrorSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Theme.of(context).colorScheme.error,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: Theme.of(context).colorScheme.onError,
              )
            : null,
      ),
    );
  }
}

/// 错误对话框
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final Object? error;
  final bool showDetails;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.error,
    this.showDetails = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    Object? error,
    bool showDetails = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        error: error,
        showDetails: showDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 48,
      ),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (showDetails && error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('确定'),
        ),
      ],
    );
  }
}
