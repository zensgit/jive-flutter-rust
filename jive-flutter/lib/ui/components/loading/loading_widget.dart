// 加载状态组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool showMessage;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 24,
    this.color,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size > 30 ? 4 : 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? theme.primaryColor,
            ),
          ),
        ),
        if (showMessage && message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// 全屏加载组件
class FullScreenLoading extends StatelessWidget {
  final String? message;
  final bool dismissible;
  final Color? backgroundColor;

  const FullScreenLoading({
    super.key,
    this.message,
    this.dismissible = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: dismissible,
      child: Scaffold(
        backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
        body: Center(
          child: LoadingWidget(
            message: message ?? '加载中...',
            size: 40,
          ),
        ),
      ),
    );
  }

  /// 显示全屏加载对话框
  static void show({
    required BuildContext context,
    String? message,
    bool dismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => FullScreenLoading(
        message: message,
        dismissible: dismissible,
        backgroundColor: Colors.black54,
      ),
    );
  }

  /// 隐藏加载对话框
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

/// 卡片加载状态
class CardLoading extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const CardLoading({
    super.key,
    this.height = 100,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: margin ?? const EdgeInsets.all(8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Container(
        height: height,
        padding: padding ?? const EdgeInsets.all(16),
        child: const Center(
          child: LoadingWidget(
            message: '加载中...',
            showMessage: false,
          ),
        ),
      ),
    );
  }
}

/// 列表加载状态
class ListLoading extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ListLoading({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => ShimmerCard(
        height: itemHeight,
      ),
    );
  }
}

/// 闪烁加载卡片
class ShimmerCard extends StatefulWidget {
  final double height;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const ShimmerCard({
    super.key,
    required this.height,
    this.width,
    this.margin,
    this.borderRadius,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin ??
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AppConstants.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                theme.cardColor,
                theme.cardColor.withValues(alpha: 0.5),
                theme.cardColor,
              ],
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 空状态组件
class EmptyWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? illustration;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.illustration,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标或插图
          if (illustration != null)
            illustration!
          else if (icon != null)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.primaryColor,
              ),
            ),

          const SizedBox(height: 24),

          // 标题
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          // 副标题
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // 操作按钮
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}
