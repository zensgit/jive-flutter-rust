// 仪表板摘要卡片组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? trend;
  final bool isPositive;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.backgroundColor,
    this.trend,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            gradient: backgroundColor != null 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor!,
                      backgroundColor!.withOpacity(0.8),
                    ],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：图标和标题
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (iconColor ?? theme.primaryColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: iconColor ?? theme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (trend != null)
                    _buildTrendIndicator(theme),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 标题
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: backgroundColor != null 
                      ? Colors.white.withOpacity(0.9)
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 金额
              Text(
                amount,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: backgroundColor != null 
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // 副标题
              if (subtitle != null) ...[ 
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: backgroundColor != null 
                        ? Colors.white.withOpacity(0.8)
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(ThemeData theme) {
    final color = isPositive ? AppConstants.successColor : AppConstants.errorColor;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            trend!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 仪表板摘要卡片网格
class SummaryCardGrid extends StatelessWidget {
  final List<SummaryCardData> cards;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const SummaryCardGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.6,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return SummaryCard(
          title: card.title,
          amount: card.amount,
          subtitle: card.subtitle,
          icon: card.icon,
          iconColor: card.iconColor,
          backgroundColor: card.backgroundColor,
          trend: card.trend,
          isPositive: card.isPositive,
          onTap: card.onTap,
        );
      },
    );
  }
}

/// 摘要卡片数据模型
class SummaryCardData {
  final String title;
  final String amount;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? trend;
  final bool isPositive;
  final VoidCallback? onTap;

  const SummaryCardData({
    required this.title,
    required this.amount,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.backgroundColor,
    this.trend,
    this.isPositive = true,
    this.onTap,
  });
}