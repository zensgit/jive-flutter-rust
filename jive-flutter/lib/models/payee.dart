import 'package:freezed_annotation/freezed_annotation.dart';

part 'payee.freezed.dart';
part 'payee.g.dart';

/// 交易对方模型 - 基于maybe-main设计
@freezed
class Payee with _$Payee {
  const factory Payee({
    String? id,
    required String name,
    String? color,
    PayeeType? payeeType,
    PayeeSource? source,
    String? logo,
    String? website,
    @Default(0) int transactionsCount,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,

    // 分类关联
    @Default([]) List<String> categoryIds,
    String? primaryCategoryId,
  }) = _Payee;

  factory Payee.fromJson(Map<String, dynamic> json) => _$PayeeFromJson(json);
}

/// 交易对方类型
enum PayeeType {
  @JsonValue('family_payee')
  familyPayee, // 家庭成员
  @JsonValue('provider_payee')
  providerPayee, // 外部商户
}

/// 交易对方来源
enum PayeeSource {
  @JsonValue('manual')
  manual, // 手动创建
  @JsonValue('plaid')
  plaid, // 从Plaid同步
  @JsonValue('synth')
  synth, // 系统生成
  @JsonValue('ai')
  ai, // AI识别
}

/// 交易对方颜色
class PayeeColors {
  static const List<String> colors = [
    '#e99537',
    '#4da568',
    '#6471eb',
    '#db5a54',
    '#df4e92',
    '#c44fe9',
    '#eb5429',
    '#61c9ea',
    '#805dee',
    '#6ad28a',
  ];
}

/// 交易对方与分类的关联
@freezed
class PayeeCategory with _$PayeeCategory {
  const factory PayeeCategory({
    String? id,
    required String payeeId,
    required String categoryId,
    @Default(0) int usageCount,
    DateTime? lastUsedAt,
  }) = _PayeeCategory;

  factory PayeeCategory.fromJson(Map<String, dynamic> json) =>
      _$PayeeCategoryFromJson(json);
}
