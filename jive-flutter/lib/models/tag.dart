import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

/// 标签模型 - 基于maybe-main设计
@freezed
class Tag with _$Tag {
  const factory Tag({
    String? id,
    required String name,
    String? color,
    String? icon,
    String? groupId,
    @Default(false) bool archived,
    @Default(0) int usageCount,
    int? position,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Tag;

  const Tag._();

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  /// 获取标签的显示颜色
  String get displayColor => color ?? TagColors.defaultColor;
  
  /// 是否是活跃标签
  bool get isActive => !archived;
  
  /// 获取使用频率级别
  String get usageLevel {
    if (usageCount == 0) return 'unused';
    if (usageCount < 5) return 'low';
    if (usageCount < 20) return 'medium';
    return 'high';
  }
}

/// 标签组
@freezed
class TagGroup with _$TagGroup {
  const factory TagGroup({
    String? id,
    required String name,
    String? color,
    String? icon,
    @Default(false) bool archived,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default([]) List<Tag> tags,
  }) = _TagGroup;

  factory TagGroup.fromJson(Map<String, dynamic> json) => _$TagGroupFromJson(json);
}

/// 标签颜色
class TagColors {
  static const List<String> colors = [
    '#e99537', '#4da568', '#6471eb', '#db5a54', '#df4e92',
    '#c44fe9', '#eb5429', '#61c9ea', '#805dee', '#6ad28a',
  ];
  
  static const String defaultColor = '#737373';
}

/// 快速标签
@freezed
class QuickTag with _$QuickTag {
  const factory QuickTag({
    String? id,
    required String tagId,
    required Tag tag,
    int? position,
    DateTime? createdAt,
  }) = _QuickTag;

  factory QuickTag.fromJson(Map<String, dynamic> json) => _$QuickTagFromJson(json);
}