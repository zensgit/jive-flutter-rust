import 'package:flutter/material.dart';

/// 空状态组件
class EmptyState extends StatelessWidget {
  final String? title;
  final String? message;
  final IconData? icon;
  final Widget? image;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final MainAxisSize mainAxisSize;

  const EmptyState({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.image,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(32.0),
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: mainAxisSize,
          children: [
            if (image != null)
              image!
            else if (icon != null)
              Icon(
                icon,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            if (title != null) ...[
              const SizedBox(height: 24),
              Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 预设的空状态类型
class EmptyStates {
  /// 无数据
  static Widget noData({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: '暂无数据',
      message: message ?? '这里还没有任何内容',
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 无交易
  static Widget noTransactions({
    VoidCallback? onAddTransaction,
  }) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: '暂无交易记录',
      message: '点击下方按钮添加您的第一笔交易',
      actionLabel: '添加交易',
      onAction: onAddTransaction,
    );
  }

  /// 无账户
  static Widget noAccounts({
    VoidCallback? onAddAccount,
  }) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: '暂无账户',
      message: '创建账户来开始记录您的财务',
      actionLabel: '创建账户',
      onAction: onAddAccount,
    );
  }

  /// 搜索无结果
  static Widget noSearchResults({
    String? query,
    VoidCallback? onClearSearch,
  }) {
    return EmptyState(
      icon: Icons.search_off,
      title: '未找到结果',
      message: query != null ? '没有找到与"$query"相关的内容' : '尝试使用不同的关键词',
      actionLabel: onClearSearch != null ? '清除搜索' : null,
      onAction: onClearSearch,
    );
  }

  /// 网络错误
  static Widget networkError({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.wifi_off,
      title: '网络连接失败',
      message: '请检查您的网络连接后重试',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }

  /// 加载错误
  static Widget error({
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.error_outline,
      title: '加载失败',
      message: message ?? '发生了一些错误，请稍后重试',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }

  /// 权限不足
  static Widget noPermission({
    VoidCallback? onRequestPermission,
  }) {
    return EmptyState(
      icon: Icons.lock_outline,
      title: '权限不足',
      message: '您没有权限访问此内容',
      actionLabel: onRequestPermission != null ? '申请权限' : null,
      onAction: onRequestPermission,
    );
  }
}

/// 带图片的空状态
class IllustratedEmptyState extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double imageHeight;

  const IllustratedEmptyState({
    super.key,
    required this.imagePath,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.imageHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      image: Image.asset(
        imagePath,
        height: imageHeight,
        fit: BoxFit.contain,
      ),
    );
  }
}
