import 'package:flutter/material.dart';
import 'category_management_enhanced.dart';

/// 分类管理页面 - 路由到增强版本
/// 
/// 这是一个包装器，将路由重定向到增强版的分类管理页面
/// 保留这个文件是为了向后兼容性
class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 直接使用增强版分类管理页面
    // 增强版包含：
    // - 三层分类架构（系统模板 → 用户分类 → 标签）
    // - 拖拽排序功能
    // - 批量操作模式
    // - 分类转标签功能
    // - 智能删除策略
    // - 模板库浏览
    return const CategoryManagementEnhancedPage();
  }
}