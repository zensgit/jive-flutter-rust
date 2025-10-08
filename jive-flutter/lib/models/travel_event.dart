import 'package:freezed_annotation/freezed_annotation.dart';

part 'travel_event.freezed.dart';
part 'travel_event.g.dart';

/// 旅行事件模型 - 基于maybe-main设计
@freezed
class TravelEvent with _$TravelEvent {
  const TravelEvent._();

  const factory TravelEvent({
    String? id,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    @Default('planning') String status,
    @Default(true) bool isActive,
    @Default(false) bool autoTag,
    @Default([]) List<String> travelCategoryIds,
    String? ledgerId,
    DateTime? createdAt,
    DateTime? updatedAt,

    // 统计信息
    @Default(0) int transactionCount,
    double? totalAmount,
    String? travelTagId,

    // 预算相关
    double? totalBudget,
    String? budgetCurrencyCode,
    @Default(0) double totalSpent,
    String? homeCurrencyCode,
    double? budgetUsagePercent,
  }) = _TravelEvent;

  factory TravelEvent.fromJson(Map<String, dynamic> json) =>
      _$TravelEventFromJson(json);

  // Computed properties
  String get tripName => name; // alias for compatibility
  int get durationDays => endDate.difference(startDate).inDays + 1;
}

/// 旅行事件模板
@freezed
class TravelEventTemplate with _$TravelEventTemplate {
  const factory TravelEventTemplate({
    String? id,
    required String name,
    String? description,
    required TravelTemplateType templateType,
    @Default([]) List<String> categoryIds,
    @Default(false) bool isSystemTemplate,
    String? ledgerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TravelEventTemplate;

  factory TravelEventTemplate.fromJson(Map<String, dynamic> json) =>
      _$TravelEventTemplateFromJson(json);
}

/// 模板类型
enum TravelTemplateType {
  @JsonValue('inclusion')
  inclusion, // 包含指定分类
  @JsonValue('exclusion')
  exclusion, // 排除指定分类
}

/// 旅行事件状态
enum TravelEventStatus {
  upcoming, // 即将开始
  active, // 进行中
  completed, // 已完成
  cancelled, // 已取消
}

/// 预设旅行事件模板库
class TravelEventTemplateLibrary {
  static List<TravelEventTemplate> getSystemTemplates() {
    return [
      // 常见旅行分类模板
      const TravelEventTemplate(
        id: 'common_travel',
        name: '常见旅行分类',
        description: '包含最常用的旅行相关支出分类',
        templateType: TravelTemplateType.inclusion,
        categoryIds: [
          'transportation',
          'accommodation',
          'dining',
          'entertainment',
          'shopping',
          'attractions',
        ],
        isSystemTemplate: true,
      ),

      // 完整旅行模板
      const TravelEventTemplate(
        id: 'complete_travel',
        name: '完整旅行模板',
        description: '包含所有可能的旅行相关支出',
        templateType: TravelTemplateType.inclusion,
        categoryIds: [
          'transportation',
          'accommodation',
          'dining',
          'entertainment',
          'shopping',
          'attractions',
          'insurance',
          'visa_fees',
          'currency_exchange',
          'communication',
          'emergency',
        ],
        isSystemTemplate: true,
      ),

      // 国内短途旅行
      const TravelEventTemplate(
        id: 'domestic_short_trip',
        name: '国内短途旅行',
        description: '适合周末或短期国内旅行',
        templateType: TravelTemplateType.inclusion,
        categoryIds: [
          'transportation',
          'accommodation',
          'dining',
          'attractions',
        ],
        isSystemTemplate: true,
      ),

      // 商务出差
      const TravelEventTemplate(
        id: 'business_trip',
        name: '商务出差',
        description: '商务旅行相关支出分类',
        templateType: TravelTemplateType.inclusion,
        categoryIds: [
          'transportation',
          'accommodation',
          'dining',
          'communication',
          'office_supplies',
        ],
        isSystemTemplate: true,
      ),

      // 排除日常分类
      const TravelEventTemplate(
        id: 'exclude_daily',
        name: '排除日常支出',
        description: '排除日常生活支出，只记录旅行特有消费',
        templateType: TravelTemplateType.exclusion,
        categoryIds: [
          'groceries',
          'utilities',
          'rent',
          'insurance',
          'loans',
          'subscriptions',
        ],
        isSystemTemplate: true,
      ),
    ];
  }

  static String getTemplateIcon(String templateId) {
    const iconMap = {
      'common_travel': '✈️',
      'complete_travel': '🌍',
      'domestic_short_trip': '🚗',
      'business_trip': '💼',
      'exclude_daily': '🚫',
    };
    return iconMap[templateId] ?? '📋';
  }
}

/// 旅行事件扩展方法
extension TravelEventExtension on TravelEvent {
  /// 获取旅行状态
  TravelEventStatus get status {
    final now = DateTime.now();
    if (endDate.isBefore(now)) {
      return TravelEventStatus.completed;
    } else if (startDate.isAfter(now)) {
      return TravelEventStatus.upcoming;
    } else {
      return TravelEventStatus.active;
    }
  }

  /// 获取持续天数
  int get duration {
    return endDate.difference(startDate).inDays + 1;
  }

  /// 是否在旅行期间
  bool isDateInRange(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// 获取旅行标签名称
  String get travelTagName {
    return '旅行-$name';
  }
}

/// 创建旅行事件输入
@freezed
class CreateTravelEventInput with _$CreateTravelEventInput {
  const factory CreateTravelEventInput({
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    @Default(true) bool autoTag,
    @Default([]) List<String> travelCategoryIds,
  }) = _CreateTravelEventInput;

  factory CreateTravelEventInput.fromJson(Map<String, dynamic> json) =>
      _$CreateTravelEventInputFromJson(json);
}

/// 更新旅行事件输入
@freezed
class UpdateTravelEventInput with _$UpdateTravelEventInput {
  const factory UpdateTravelEventInput({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    bool? autoTag,
    List<String>? travelCategoryIds,
  }) = _UpdateTravelEventInput;

  factory UpdateTravelEventInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateTravelEventInputFromJson(json);
}

/// 旅行统计信息
@freezed
class TravelStatistics with _$TravelStatistics {
  const factory TravelStatistics({
    required double totalSpent,
    required double totalBudget,
    required double budgetUsage,
    required Map<String, double> spentByCategory,
    required Map<String, double> spentByDay,
    required int transactionCount,
    required double averagePerDay,
  }) = _TravelStatistics;

  factory TravelStatistics.fromJson(Map<String, dynamic> json) =>
      _$TravelStatisticsFromJson(json);
}

/// 旅行分类预算
@freezed
class TravelBudget with _$TravelBudget {
  const factory TravelBudget({
    String? id,
    required String travelEventId,
    required String categoryId,
    required String categoryName,
    required double budgetAmount,
    String? budgetCurrencyCode,
    @Default(0.8) double alertThreshold,
    @Default(0) double spentAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _TravelBudget;

  factory TravelBudget.fromJson(Map<String, dynamic> json) =>
      _$TravelBudgetFromJson(json);
}
