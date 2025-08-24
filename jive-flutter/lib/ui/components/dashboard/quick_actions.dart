// 仪表板快捷操作组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class QuickActions extends StatelessWidget {
  final List<QuickActionData> actions;
  final int itemsPerRow;
  final double spacing;

  const QuickActions({
    super.key,
    required this.actions,
    this.itemsPerRow = 4,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快捷操作',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionGrid(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(ThemeData theme) {
    final rows = <Widget>[];
    
    for (int i = 0; i < actions.length; i += itemsPerRow) {
      final rowActions = actions.skip(i).take(itemsPerRow).toList();
      rows.add(
        Row(
          children: rowActions.map((action) => 
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: action != rowActions.last ? spacing : 0,
                ),
                child: QuickActionItem(
                  action: action,
                  theme: theme,
                ),
              ),
            ),
          ).toList(),
        ),
      );
      
      if (i + itemsPerRow < actions.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    
    return Column(children: rows);
  }
}

class QuickActionItem extends StatelessWidget {
  final QuickActionData action;
  final ThemeData theme;

  const QuickActionItem({
    super.key,
    required this.action,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                action.icon,
                size: 28,
                color: action.color,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 标题
            Text(
              action.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷操作数据模型
class QuickActionData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const QuickActionData({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  // 预定义的快捷操作
  static List<QuickActionData> getDefaultActions({
    VoidCallback? onAddIncome,
    VoidCallback? onAddExpense,
    VoidCallback? onTransfer,
    VoidCallback? onAddBudget,
    VoidCallback? onScanReceipt,
    VoidCallback? onViewReports,
    VoidCallback? onExportData,
    VoidCallback? onSettings,
  }) {
    return [
      QuickActionData(
        title: '添加收入',
        icon: Icons.add_circle_outline,
        color: AppConstants.successColor,
        onTap: onAddIncome ?? () {},
      ),
      QuickActionData(
        title: '添加支出',
        icon: Icons.remove_circle_outline,
        color: AppConstants.errorColor,
        onTap: onAddExpense ?? () {},
      ),
      QuickActionData(
        title: '转账',
        icon: Icons.swap_horiz,
        color: AppConstants.primaryColor,
        onTap: onTransfer ?? () {},
      ),
      QuickActionData(
        title: '预算管理',
        icon: Icons.pie_chart_outline,
        color: AppConstants.warningColor,
        onTap: onAddBudget ?? () {},
      ),
      QuickActionData(
        title: '扫描票据',
        icon: Icons.camera_alt_outlined,
        color: AppConstants.infoColor,
        onTap: onScanReceipt ?? () {},
      ),
      QuickActionData(
        title: '查看报表',
        icon: Icons.analytics_outlined,
        color: Colors.purple,
        onTap: onViewReports ?? () {},
      ),
      QuickActionData(
        title: '导出数据',
        icon: Icons.file_download_outlined,
        color: Colors.orange,
        onTap: onExportData ?? () {},
      ),
      QuickActionData(
        title: '设置',
        icon: Icons.settings_outlined,
        color: Colors.grey[600]!,
        onTap: onSettings ?? () {},
      ),
    ];
  }
}

/// 简化版快捷操作（只显示主要操作）
class SimpleQuickActions extends StatelessWidget {
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final VoidCallback? onTransfer;
  final VoidCallback? onScanReceipt;

  const SimpleQuickActions({
    super.key,
    this.onAddIncome,
    this.onAddExpense,
    this.onTransfer,
    this.onScanReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickActionData(
        title: '收入',
        icon: Icons.add_circle_outline,
        color: AppConstants.successColor,
        onTap: onAddIncome ?? () {},
      ),
      QuickActionData(
        title: '支出',
        icon: Icons.remove_circle_outline,
        color: AppConstants.errorColor,
        onTap: onAddExpense ?? () {},
      ),
      QuickActionData(
        title: '转账',
        icon: Icons.swap_horiz,
        color: AppConstants.primaryColor,
        onTap: onTransfer ?? () {},
      ),
      QuickActionData(
        title: '扫描',
        icon: Icons.camera_alt_outlined,
        color: AppConstants.infoColor,
        onTap: onScanReceipt ?? () {},
      ),
    ];

    return QuickActions(
      actions: actions,
      itemsPerRow: 4,
    );
  }
}