import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// 分类模型 - 基于maybe-main设计
@freezed
class Category with _$Category {
  const factory Category({
    String? id,
    required String name,
    String? nameEn,
    String? description,
    required String color,
    required String icon,
    required CategoryClassification classification,
    String? parentId,
    String? ledgerId,
    int? position,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,

    // 子分类
    @Default([]) List<Category> subcategories,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

/// 分类类型
enum CategoryClassification {
  income,
  expense,
  transfer,
}

/// 预定义的分类颜色
class CategoryColors {
  static const List<String> colors = [
    '#e99537', // 橙色
    '#4da568', // 绿色
    '#6471eb', // 蓝色
    '#db5a54', // 红色
    '#df4e92', // 粉色
    '#c44fe9', // 紫色
    '#eb5429', // 深橙
    '#61c9ea', // 青色
    '#805dee', // 深紫
    '#6ad28a', // 浅绿
  ];

  static const String uncategorized = '#737373';
  static const String transfer = '#444CE7';
  static const String payment = '#db5a54';
  static const String trade = '#e99537';
}

/// 预定义的分类图标
class CategoryIcons {
  static const List<String> icons = [
    'bus',
    'circle-dollar-sign',
    'ambulance',
    'apple',
    'award',
    'baby',
    'battery',
    'lightbulb',
    'bed-single',
    'beer',
    'bluetooth',
    'book',
    'briefcase',
    'building',
    'credit-card',
    'camera',
    'utensils',
    'cooking-pot',
    'cookie',
    'dices',
    'drama',
    'dog',
    'drill',
    'drum',
    'dumbbell',
    'gamepad-2',
    'graduation-cap',
    'house',
    'hand-helping',
    'ice-cream-cone',
    'phone',
    'piggy-bank',
    'pill',
    'pizza',
    'printer',
    'puzzle',
    'ribbon',
    'shopping-cart',
    'shield-plus',
    'ticket',
    'trees',
    'plane',
    'users',
    'gift',
    'megaphone',
    'smartphone',
    'shopping-bag',
    'shirt',
    'scissors',
    'hammer',
    'receipt',
  ];
}

/// 默认分类库
class CategoryLibrary {
  static Map<String, List<CategoryTemplate>> getDefaultCategories() {
    return {
      'income': [
        CategoryTemplate(
            name: '工资收入',
            nameEn: 'Salary',
            color: '#e99537',
            icon: 'circle-dollar-sign',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '奖金收入',
            nameEn: 'Bonus',
            color: '#e99537',
            icon: 'award',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '投资收益',
            nameEn: 'Investment Returns',
            color: '#e99537',
            icon: 'trending-up',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '副业收入',
            nameEn: 'Side Business',
            color: '#e99537',
            icon: 'briefcase',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '租金收入',
            nameEn: 'Rental Income',
            color: '#e99537',
            icon: 'house',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '利息收入',
            nameEn: 'Interest Income',
            color: '#e99537',
            icon: 'piggy-bank',
            classification: CategoryClassification.income),
        CategoryTemplate(
            name: '其他收入',
            nameEn: 'Other Income',
            color: '#e99537',
            icon: 'plus-circle',
            classification: CategoryClassification.income),
      ],
      'daily_expense': [
        CategoryTemplate(
            name: '餐饮美食',
            nameEn: 'Food & Dining',
            color: '#eb5429',
            icon: 'utensils',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '交通出行',
            nameEn: 'Transportation',
            color: '#df4e92',
            icon: 'bus',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '购物消费',
            nameEn: 'Shopping',
            color: '#e99537',
            icon: 'shopping-cart',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '生活用品',
            nameEn: 'Groceries',
            color: '#6471eb',
            icon: 'shopping-bag',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '服装配饰',
            nameEn: 'Clothing',
            color: '#df4e92',
            icon: 'shirt',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '美容美发',
            nameEn: 'Personal Care',
            color: '#4da568',
            icon: 'scissors',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '手机通讯',
            nameEn: 'Phone & Internet',
            color: '#6471eb',
            icon: 'phone',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '数码电器',
            nameEn: 'Electronics',
            color: '#805dee',
            icon: 'smartphone',
            classification: CategoryClassification.expense),
      ],
      'housing': [
        CategoryTemplate(
            name: '房租房贷',
            nameEn: 'Rent & Mortgage',
            color: '#db5a54',
            icon: 'house',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '水电煤气',
            nameEn: 'Utilities',
            color: '#db5a54',
            icon: 'lightbulb',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '物业管理',
            nameEn: 'Property Management',
            color: '#db5a54',
            icon: 'building',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '家具家电',
            nameEn: 'Furniture',
            color: '#6471eb',
            icon: 'bed-single',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '装修维修',
            nameEn: 'Home Improvement',
            color: '#6471eb',
            icon: 'hammer',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '家政服务',
            nameEn: 'Home Services',
            color: '#4da568',
            icon: 'briefcase',
            classification: CategoryClassification.expense),
      ],
      'health_education': [
        CategoryTemplate(
            name: '医疗保健',
            nameEn: 'Healthcare',
            color: '#4da568',
            icon: 'pill',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '教育培训',
            nameEn: 'Education',
            color: '#61c9ea',
            icon: 'graduation-cap',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '运动健身',
            nameEn: 'Fitness',
            color: '#4da568',
            icon: 'dumbbell',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '保险费用',
            nameEn: 'Insurance',
            color: '#6471eb',
            icon: 'shield-plus',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '书籍文具',
            nameEn: 'Books & Stationery',
            color: '#61c9ea',
            icon: 'book',
            classification: CategoryClassification.expense),
      ],
      'entertainment_social': [
        CategoryTemplate(
            name: '娱乐休闲',
            nameEn: 'Entertainment',
            color: '#df4e92',
            icon: 'drama',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '旅游度假',
            nameEn: 'Travel',
            color: '#df4e92',
            icon: 'plane',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '聚餐聚会',
            nameEn: 'Social Dining',
            color: '#eb5429',
            icon: 'users',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '礼品礼金',
            nameEn: 'Gifts & Donations',
            color: '#61c9ea',
            icon: 'gift',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '宠物相关',
            nameEn: 'Pets',
            color: '#4da568',
            icon: 'dog',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '兴趣爱好',
            nameEn: 'Hobbies',
            color: '#c44fe9',
            icon: 'gamepad-2',
            classification: CategoryClassification.expense),
      ],
      'financial': [
        CategoryTemplate(
            name: '信用卡还款',
            nameEn: 'Credit Card Payment',
            color: '#6471eb',
            icon: 'credit-card',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '贷款还款',
            nameEn: 'Loan Payments',
            color: '#6471eb',
            icon: 'credit-card',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '银行手续费',
            nameEn: 'Bank Fees',
            color: '#6471eb',
            icon: 'credit-card',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '投资理财',
            nameEn: 'Investment',
            color: '#e99537',
            icon: 'trending-up',
            classification: CategoryClassification.expense),
        CategoryTemplate(
            name: '税费支出',
            nameEn: 'Taxes',
            color: '#db5a54',
            icon: 'receipt',
            classification: CategoryClassification.expense),
      ],
      'transfer': [
        CategoryTemplate(
            name: '账户转账',
            nameEn: 'Transfer',
            color: CategoryColors.transfer,
            icon: 'arrow-left-right',
            classification: CategoryClassification.transfer),
      ],
    };
  }
}

/// 分类模板
class CategoryTemplate {
  final String name;
  final String? nameEn;
  final String color;
  final String icon;
  final CategoryClassification classification;

  const CategoryTemplate({
    required this.name,
    this.nameEn,
    required this.color,
    required this.icon,
    required this.classification,
  });
}
