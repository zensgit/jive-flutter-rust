import 'package:freezed_annotation/freezed_annotation.dart';

part 'rule.freezed.dart';
part 'rule.g.dart';

/// 规则模型 - 基于maybe-main设计
@freezed
class Rule with _$Rule {
  const factory Rule({
    String? id,
    required String name,
    String? description,
    required ResourceType resourceType,
    @Default(true) bool active,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,

    // 条件和动作
    @Default([]) List<RuleCondition> conditions,
    @Default([]) List<RuleAction> actions,

    // 执行统计
    @Default(0) int executionCount,
    DateTime? lastExecutedAt,
  }) = _Rule;

  factory Rule.fromJson(Map<String, dynamic> json) => _$RuleFromJson(json);
}

/// 资源类型
enum ResourceType {
  transaction, // 交易
  account, // 账户
  budget, // 预算
}

/// 规则条件
@freezed
class RuleCondition with _$RuleCondition {
  const factory RuleCondition({
    String? id,
    required ConditionType type,
    required ConditionOperator operator,
    dynamic value,

    // 复合条件
    @Default(false) bool isCompound,
    LogicalOperator? logicalOperator,
    @Default([]) List<RuleCondition> subConditions,
  }) = _RuleCondition;

  factory RuleCondition.fromJson(Map<String, dynamic> json) =>
      _$RuleConditionFromJson(json);
}

/// 条件类型
enum ConditionType {
  amount, // 金额
  description, // 描述
  category, // 分类
  payee, // 交易对方
  tag, // 标签
  date, // 日期
  accountType, // 账户类型
  transactionType, // 交易类型
}

/// 条件操作符
enum ConditionOperator {
  @JsonValue('equals')
  equals, // 等于
  @JsonValue('not_equals')
  notEquals, // 不等于
  @JsonValue('contains')
  contains, // 包含
  @JsonValue('not_contains')
  notContains, // 不包含
  @JsonValue('starts_with')
  startsWith, // 开始于
  @JsonValue('ends_with')
  endsWith, // 结束于
  @JsonValue('greater_than')
  greaterThan, // 大于
  @JsonValue('less_than')
  lessThan, // 小于
  @JsonValue('between')
  between, // 在...之间
  @JsonValue('in')
  inList, // 在列表中
  @JsonValue('not_in')
  notInList, // 不在列表中
}

/// 逻辑操作符
enum LogicalOperator {
  and, // 与
  or, // 或
}

/// 规则动作
@freezed
class RuleAction with _$RuleAction {
  const factory RuleAction({
    String? id,
    required ActionType type,
    dynamic value,
    Map<String, dynamic>? params,
  }) = _RuleAction;

  factory RuleAction.fromJson(Map<String, dynamic> json) =>
      _$RuleActionFromJson(json);
}

/// 动作类型
enum ActionType {
  setCategory, // 设置分类
  addTag, // 添加标签
  removeTag, // 移除标签
  setPayee, // 设置交易对方
  setDescription, // 设置描述
  markAsTransfer, // 标记为转账
  hide, // 隐藏交易
  notify, // 发送通知
  autoApprove, // 自动批准
  autoCategorize, // 自动分类
}

/// 规则执行日志
@freezed
class RuleLog with _$RuleLog {
  const factory RuleLog({
    String? id,
    required String ruleId,
    required String resourceId,
    required ResourceType resourceType,
    required bool success,
    String? error,
    Map<String, dynamic>? details,
    DateTime? executedAt,
  }) = _RuleLog;

  factory RuleLog.fromJson(Map<String, dynamic> json) =>
      _$RuleLogFromJson(json);
}
