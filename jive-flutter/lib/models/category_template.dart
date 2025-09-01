import 'package:freezed_annotation/freezed_annotation.dart';
import 'category.dart';

part 'category_template.freezed.dart';
part 'category_template.g.dart';

/// 系统分类模板
@freezed
class SystemCategoryTemplate with _$SystemCategoryTemplate {
  const factory SystemCategoryTemplate({
    required String id,
    required String name,
    String? nameEn,
    String? nameZh,
    String? description,
    required CategoryClassification classification,
    required String color,
    String? icon,
    required CategoryGroup categoryGroup,
    @Default(false) bool isFeatured,
    @Default(true) bool isActive,
    @Default([]) List<String> tags,
    @Default(0) int globalUsageCount,
    @Default('1.0.0') String version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SystemCategoryTemplate;

  factory SystemCategoryTemplate.fromJson(Map<String, dynamic> json) =>
      _$SystemCategoryTemplateFromJson(json);
}

/// 分类组枚举
enum CategoryGroup {
  income('income', '收入'),
  dailyExpense('dailyExpense', '日常支出'),
  transportation('transportation', '交通出行'),
  housing('housing', '住房居家'),
  medical('medical', '医疗健康'),
  entertainmentSocial('entertainmentSocial', '娱乐社交'),
  education('education', '教育培训'),
  finance('finance', '金融投资'),
  other('other', '其他');

  const CategoryGroup(this.key, this.displayName);

  final String key;
  final String displayName;

  static CategoryGroup? fromString(String key) {
    for (final group in CategoryGroup.values) {
      if (group.key == key) {
        return group;
      }
    }
    return null;
  }
}

/// 分类模板库
class CategoryTemplateLibrary {
  
  /// 获取所有默认模板
  static List<SystemCategoryTemplate> getDefaultTemplates() {
    return [
      // 收入类模板
      const SystemCategoryTemplate(
        id: 'income_salary',
        name: '工资收入',
        nameEn: 'Salary',
        nameZh: '工资收入',
        description: '每月固定工资收入',
        classification: CategoryClassification.income,
        color: '#10B981',
        icon: '💰',
        categoryGroup: CategoryGroup.income,
        isFeatured: true,
        tags: ['必备', '常用'],
        globalUsageCount: 15420,
      ),
      
      const SystemCategoryTemplate(
        id: 'income_bonus',
        name: '奖金收入',
        nameEn: 'Bonus',
        nameZh: '奖金收入',
        description: '年终奖、绩效奖金等',
        classification: CategoryClassification.income,
        color: '#059669',
        icon: '🎁',
        categoryGroup: CategoryGroup.income,
        isFeatured: false,
        tags: ['收入'],
        globalUsageCount: 8250,
      ),
      
      const SystemCategoryTemplate(
        id: 'income_investment',
        name: '投资收益',
        nameEn: 'Investment',
        nameZh: '投资收益',
        description: '股票、基金、理财收益',
        classification: CategoryClassification.income,
        color: '#0D9488',
        icon: '📈',
        categoryGroup: CategoryGroup.finance,
        isFeatured: false,
        tags: ['投资', '理财'],
        globalUsageCount: 5630,
      ),

      // 支出类模板 - 日常支出
      const SystemCategoryTemplate(
        id: 'expense_food',
        name: '餐饮美食',
        nameEn: 'Food & Dining',
        nameZh: '餐饮美食',
        description: '日常餐饮、外卖、聚餐等',
        classification: CategoryClassification.expense,
        color: '#EF4444',
        icon: '🍽️',
        categoryGroup: CategoryGroup.dailyExpense,
        isFeatured: true,
        tags: ['热门', '必备'],
        globalUsageCount: 25680,
      ),
      
      const SystemCategoryTemplate(
        id: 'expense_shopping',
        name: '购物消费',
        nameEn: 'Shopping',
        nameZh: '购物消费',
        description: '日用品、服装、数码产品等',
        classification: CategoryClassification.expense,
        color: '#F59E0B',
        icon: '🛒',
        categoryGroup: CategoryGroup.dailyExpense,
        isFeatured: false,
        tags: ['常用'],
        globalUsageCount: 12450,
      ),
      
      const SystemCategoryTemplate(
        id: 'expense_groceries',
        name: '生鲜采购',
        nameEn: 'Groceries',
        nameZh: '生鲜采购',
        description: '蔬菜、水果、肉类等食材采购',
        classification: CategoryClassification.expense,
        color: '#84CC16',
        icon: '🛒',
        categoryGroup: CategoryGroup.dailyExpense,
        isFeatured: false,
        tags: ['日常'],
        globalUsageCount: 18920,
      ),

      // 交通出行
      const SystemCategoryTemplate(
        id: 'expense_transport',
        name: '交通出行',
        nameEn: 'Transportation',
        nameZh: '交通出行',
        description: '地铁、公交、打车、加油等',
        classification: CategoryClassification.expense,
        color: '#F97316',
        icon: '🚗',
        categoryGroup: CategoryGroup.transportation,
        isFeatured: true,
        tags: ['必备'],
        globalUsageCount: 18350,
      ),
      
      const SystemCategoryTemplate(
        id: 'expense_fuel',
        name: '汽车加油',
        nameEn: 'Fuel',
        nameZh: '汽车加油',
        description: '汽车、摩托车加油费用',
        classification: CategoryClassification.expense,
        color: '#EA580C',
        icon: '⛽',
        categoryGroup: CategoryGroup.transportation,
        isFeatured: false,
        tags: ['交通', '汽车'],
        globalUsageCount: 9870,
      ),

      // 住房居家
      const SystemCategoryTemplate(
        id: 'expense_rent',
        name: '房租房贷',
        nameEn: 'Rent & Mortgage',
        nameZh: '房租房贷',
        description: '月租金、房贷月供',
        classification: CategoryClassification.expense,
        color: '#7C3AED',
        icon: '🏠',
        categoryGroup: CategoryGroup.housing,
        isFeatured: true,
        tags: ['必备', '住房'],
        globalUsageCount: 16780,
      ),
      
      const SystemCategoryTemplate(
        id: 'expense_utilities',
        name: '水电气费',
        nameEn: 'Utilities',
        nameZh: '水电气费',
        description: '水费、电费、燃气费',
        classification: CategoryClassification.expense,
        color: '#7C2D12',
        icon: '💡',
        categoryGroup: CategoryGroup.housing,
        isFeatured: false,
        tags: ['住房', '必备'],
        globalUsageCount: 14520,
      ),

      // 娱乐休闲
      const SystemCategoryTemplate(
        id: 'expense_entertainment',
        name: '娱乐休闲',
        nameEn: 'Entertainment',
        nameZh: '娱乐休闲',
        description: '电影、游戏、KTV、旅游等',
        classification: CategoryClassification.expense,
        color: '#8B5CF6',
        icon: '🎬',
        categoryGroup: CategoryGroup.entertainmentSocial,
        isFeatured: false,
        tags: ['热门'],
        globalUsageCount: 9870,
      ),
      
      const SystemCategoryTemplate(
        id: 'expense_travel',
        name: '旅游度假',
        nameEn: 'Travel',
        nameZh: '旅游度假',
        description: '旅游、度假相关支出',
        classification: CategoryClassification.expense,
        color: '#0EA5E9',
        icon: '✈️',
        categoryGroup: CategoryGroup.entertainmentSocial,
        isFeatured: false,
        tags: ['旅游', '休闲'],
        globalUsageCount: 6540,
      ),

      // 医疗健康
      const SystemCategoryTemplate(
        id: 'expense_medical',
        name: '医疗健康',
        nameEn: 'Medical & Health',
        nameZh: '医疗健康',
        description: '看病、买药、体检等',
        classification: CategoryClassification.expense,
        color: '#DC2626',
        icon: '🏥',
        categoryGroup: CategoryGroup.medical,
        isFeatured: false,
        tags: ['健康', '必备'],
        globalUsageCount: 7890,
      ),

      // 教育培训
      const SystemCategoryTemplate(
        id: 'expense_education',
        name: '教育培训',
        nameEn: 'Education',
        nameZh: '教育培训',
        description: '学费、培训费、书籍等',
        classification: CategoryClassification.expense,
        color: '#2563EB',
        icon: '📚',
        categoryGroup: CategoryGroup.education,
        isFeatured: false,
        tags: ['教育', '学习'],
        globalUsageCount: 4560,
      ),

      // 金融投资
      const SystemCategoryTemplate(
        id: 'expense_investment',
        name: '投资理财',
        nameEn: 'Investment',
        nameZh: '投资理财',
        description: '股票、基金、保险等投资',
        classification: CategoryClassification.expense,
        color: '#059669',
        icon: '💼',
        categoryGroup: CategoryGroup.finance,
        isFeatured: false,
        tags: ['投资', '理财'],
        globalUsageCount: 8920,
      ),
    ];
  }

  /// 按分类获取模板
  static List<SystemCategoryTemplate> getTemplatesByClassification(
    CategoryClassification classification,
  ) {
    return getDefaultTemplates()
        .where((template) => template.classification == classification)
        .toList();
  }

  /// 按分组获取模板
  static List<SystemCategoryTemplate> getTemplatesByGroup(
    CategoryGroup group,
  ) {
    return getDefaultTemplates()
        .where((template) => template.categoryGroup == group)
        .toList();
  }

  /// 获取精选模板
  static List<SystemCategoryTemplate> getFeaturedTemplates() {
    return getDefaultTemplates()
        .where((template) => template.isFeatured)
        .toList();
  }

  /// 搜索模板
  static List<SystemCategoryTemplate> searchTemplates(String query) {
    final queryLower = query.toLowerCase();
    return getDefaultTemplates().where((template) {
      return template.name.toLowerCase().contains(queryLower) ||
             (template.nameEn?.toLowerCase().contains(queryLower) ?? false) ||
             template.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }
}