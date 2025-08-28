// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Rule _$RuleFromJson(Map<String, dynamic> json) {
  return _Rule.fromJson(json);
}

/// @nodoc
mixin _$Rule {
  String? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  ResourceType get resourceType => throw _privateConstructorUsedError;
  bool get active => throw _privateConstructorUsedError;
  int? get priority => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError; // 条件和动作
  List<RuleCondition> get conditions => throw _privateConstructorUsedError;
  List<RuleAction> get actions => throw _privateConstructorUsedError; // 执行统计
  int get executionCount => throw _privateConstructorUsedError;
  DateTime? get lastExecutedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RuleCopyWith<Rule> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleCopyWith<$Res> {
  factory $RuleCopyWith(Rule value, $Res Function(Rule) then) =
      _$RuleCopyWithImpl<$Res, Rule>;
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      ResourceType resourceType,
      bool active,
      int? priority,
      DateTime? createdAt,
      DateTime? updatedAt,
      List<RuleCondition> conditions,
      List<RuleAction> actions,
      int executionCount,
      DateTime? lastExecutedAt});
}

/// @nodoc
class _$RuleCopyWithImpl<$Res, $Val extends Rule>
    implements $RuleCopyWith<$Res> {
  _$RuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? resourceType = null,
    Object? active = null,
    Object? priority = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? conditions = null,
    Object? actions = null,
    Object? executionCount = null,
    Object? lastExecutedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      resourceType: null == resourceType
          ? _value.resourceType
          : resourceType // ignore: cast_nullable_to_non_nullable
              as ResourceType,
      active: null == active
          ? _value.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: freezed == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      conditions: null == conditions
          ? _value.conditions
          : conditions // ignore: cast_nullable_to_non_nullable
              as List<RuleCondition>,
      actions: null == actions
          ? _value.actions
          : actions // ignore: cast_nullable_to_non_nullable
              as List<RuleAction>,
      executionCount: null == executionCount
          ? _value.executionCount
          : executionCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastExecutedAt: freezed == lastExecutedAt
          ? _value.lastExecutedAt
          : lastExecutedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleImplCopyWith<$Res> implements $RuleCopyWith<$Res> {
  factory _$$RuleImplCopyWith(
          _$RuleImpl value, $Res Function(_$RuleImpl) then) =
      __$$RuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      ResourceType resourceType,
      bool active,
      int? priority,
      DateTime? createdAt,
      DateTime? updatedAt,
      List<RuleCondition> conditions,
      List<RuleAction> actions,
      int executionCount,
      DateTime? lastExecutedAt});
}

/// @nodoc
class __$$RuleImplCopyWithImpl<$Res>
    extends _$RuleCopyWithImpl<$Res, _$RuleImpl>
    implements _$$RuleImplCopyWith<$Res> {
  __$$RuleImplCopyWithImpl(_$RuleImpl _value, $Res Function(_$RuleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? resourceType = null,
    Object? active = null,
    Object? priority = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? conditions = null,
    Object? actions = null,
    Object? executionCount = null,
    Object? lastExecutedAt = freezed,
  }) {
    return _then(_$RuleImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      resourceType: null == resourceType
          ? _value.resourceType
          : resourceType // ignore: cast_nullable_to_non_nullable
              as ResourceType,
      active: null == active
          ? _value.active
          : active // ignore: cast_nullable_to_non_nullable
              as bool,
      priority: freezed == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      conditions: null == conditions
          ? _value._conditions
          : conditions // ignore: cast_nullable_to_non_nullable
              as List<RuleCondition>,
      actions: null == actions
          ? _value._actions
          : actions // ignore: cast_nullable_to_non_nullable
              as List<RuleAction>,
      executionCount: null == executionCount
          ? _value.executionCount
          : executionCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastExecutedAt: freezed == lastExecutedAt
          ? _value.lastExecutedAt
          : lastExecutedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleImpl implements _Rule {
  const _$RuleImpl(
      {this.id,
      required this.name,
      this.description,
      required this.resourceType,
      this.active = true,
      this.priority,
      this.createdAt,
      this.updatedAt,
      final List<RuleCondition> conditions = const [],
      final List<RuleAction> actions = const [],
      this.executionCount = 0,
      this.lastExecutedAt})
      : _conditions = conditions,
        _actions = actions;

  factory _$RuleImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleImplFromJson(json);

  @override
  final String? id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final ResourceType resourceType;
  @override
  @JsonKey()
  final bool active;
  @override
  final int? priority;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
// 条件和动作
  final List<RuleCondition> _conditions;
// 条件和动作
  @override
  @JsonKey()
  List<RuleCondition> get conditions {
    if (_conditions is EqualUnmodifiableListView) return _conditions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_conditions);
  }

  final List<RuleAction> _actions;
  @override
  @JsonKey()
  List<RuleAction> get actions {
    if (_actions is EqualUnmodifiableListView) return _actions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_actions);
  }

// 执行统计
  @override
  @JsonKey()
  final int executionCount;
  @override
  final DateTime? lastExecutedAt;

  @override
  String toString() {
    return 'Rule(id: $id, name: $name, description: $description, resourceType: $resourceType, active: $active, priority: $priority, createdAt: $createdAt, updatedAt: $updatedAt, conditions: $conditions, actions: $actions, executionCount: $executionCount, lastExecutedAt: $lastExecutedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.resourceType, resourceType) ||
                other.resourceType == resourceType) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality()
                .equals(other._conditions, _conditions) &&
            const DeepCollectionEquality().equals(other._actions, _actions) &&
            (identical(other.executionCount, executionCount) ||
                other.executionCount == executionCount) &&
            (identical(other.lastExecutedAt, lastExecutedAt) ||
                other.lastExecutedAt == lastExecutedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      resourceType,
      active,
      priority,
      createdAt,
      updatedAt,
      const DeepCollectionEquality().hash(_conditions),
      const DeepCollectionEquality().hash(_actions),
      executionCount,
      lastExecutedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleImplCopyWith<_$RuleImpl> get copyWith =>
      __$$RuleImplCopyWithImpl<_$RuleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleImplToJson(
      this,
    );
  }
}

abstract class _Rule implements Rule {
  const factory _Rule(
      {final String? id,
      required final String name,
      final String? description,
      required final ResourceType resourceType,
      final bool active,
      final int? priority,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final List<RuleCondition> conditions,
      final List<RuleAction> actions,
      final int executionCount,
      final DateTime? lastExecutedAt}) = _$RuleImpl;

  factory _Rule.fromJson(Map<String, dynamic> json) = _$RuleImpl.fromJson;

  @override
  String? get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  ResourceType get resourceType;
  @override
  bool get active;
  @override
  int? get priority;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override // 条件和动作
  List<RuleCondition> get conditions;
  @override
  List<RuleAction> get actions;
  @override // 执行统计
  int get executionCount;
  @override
  DateTime? get lastExecutedAt;
  @override
  @JsonKey(ignore: true)
  _$$RuleImplCopyWith<_$RuleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleCondition _$RuleConditionFromJson(Map<String, dynamic> json) {
  return _RuleCondition.fromJson(json);
}

/// @nodoc
mixin _$RuleCondition {
  String? get id => throw _privateConstructorUsedError;
  ConditionType get type => throw _privateConstructorUsedError;
  ConditionOperator get operator => throw _privateConstructorUsedError;
  dynamic get value => throw _privateConstructorUsedError; // 复合条件
  bool get isCompound => throw _privateConstructorUsedError;
  LogicalOperator? get logicalOperator => throw _privateConstructorUsedError;
  List<RuleCondition> get subConditions => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RuleConditionCopyWith<RuleCondition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleConditionCopyWith<$Res> {
  factory $RuleConditionCopyWith(
          RuleCondition value, $Res Function(RuleCondition) then) =
      _$RuleConditionCopyWithImpl<$Res, RuleCondition>;
  @useResult
  $Res call(
      {String? id,
      ConditionType type,
      ConditionOperator operator,
      dynamic value,
      bool isCompound,
      LogicalOperator? logicalOperator,
      List<RuleCondition> subConditions});
}

/// @nodoc
class _$RuleConditionCopyWithImpl<$Res, $Val extends RuleCondition>
    implements $RuleConditionCopyWith<$Res> {
  _$RuleConditionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? operator = null,
    Object? value = freezed,
    Object? isCompound = null,
    Object? logicalOperator = freezed,
    Object? subConditions = null,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ConditionType,
      operator: null == operator
          ? _value.operator
          : operator // ignore: cast_nullable_to_non_nullable
              as ConditionOperator,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as dynamic,
      isCompound: null == isCompound
          ? _value.isCompound
          : isCompound // ignore: cast_nullable_to_non_nullable
              as bool,
      logicalOperator: freezed == logicalOperator
          ? _value.logicalOperator
          : logicalOperator // ignore: cast_nullable_to_non_nullable
              as LogicalOperator?,
      subConditions: null == subConditions
          ? _value.subConditions
          : subConditions // ignore: cast_nullable_to_non_nullable
              as List<RuleCondition>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleConditionImplCopyWith<$Res>
    implements $RuleConditionCopyWith<$Res> {
  factory _$$RuleConditionImplCopyWith(
          _$RuleConditionImpl value, $Res Function(_$RuleConditionImpl) then) =
      __$$RuleConditionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      ConditionType type,
      ConditionOperator operator,
      dynamic value,
      bool isCompound,
      LogicalOperator? logicalOperator,
      List<RuleCondition> subConditions});
}

/// @nodoc
class __$$RuleConditionImplCopyWithImpl<$Res>
    extends _$RuleConditionCopyWithImpl<$Res, _$RuleConditionImpl>
    implements _$$RuleConditionImplCopyWith<$Res> {
  __$$RuleConditionImplCopyWithImpl(
      _$RuleConditionImpl _value, $Res Function(_$RuleConditionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? operator = null,
    Object? value = freezed,
    Object? isCompound = null,
    Object? logicalOperator = freezed,
    Object? subConditions = null,
  }) {
    return _then(_$RuleConditionImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ConditionType,
      operator: null == operator
          ? _value.operator
          : operator // ignore: cast_nullable_to_non_nullable
              as ConditionOperator,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as dynamic,
      isCompound: null == isCompound
          ? _value.isCompound
          : isCompound // ignore: cast_nullable_to_non_nullable
              as bool,
      logicalOperator: freezed == logicalOperator
          ? _value.logicalOperator
          : logicalOperator // ignore: cast_nullable_to_non_nullable
              as LogicalOperator?,
      subConditions: null == subConditions
          ? _value._subConditions
          : subConditions // ignore: cast_nullable_to_non_nullable
              as List<RuleCondition>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleConditionImpl implements _RuleCondition {
  const _$RuleConditionImpl(
      {this.id,
      required this.type,
      required this.operator,
      this.value,
      this.isCompound = false,
      this.logicalOperator,
      final List<RuleCondition> subConditions = const []})
      : _subConditions = subConditions;

  factory _$RuleConditionImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleConditionImplFromJson(json);

  @override
  final String? id;
  @override
  final ConditionType type;
  @override
  final ConditionOperator operator;
  @override
  final dynamic value;
// 复合条件
  @override
  @JsonKey()
  final bool isCompound;
  @override
  final LogicalOperator? logicalOperator;
  final List<RuleCondition> _subConditions;
  @override
  @JsonKey()
  List<RuleCondition> get subConditions {
    if (_subConditions is EqualUnmodifiableListView) return _subConditions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subConditions);
  }

  @override
  String toString() {
    return 'RuleCondition(id: $id, type: $type, operator: $operator, value: $value, isCompound: $isCompound, logicalOperator: $logicalOperator, subConditions: $subConditions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleConditionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.operator, operator) ||
                other.operator == operator) &&
            const DeepCollectionEquality().equals(other.value, value) &&
            (identical(other.isCompound, isCompound) ||
                other.isCompound == isCompound) &&
            (identical(other.logicalOperator, logicalOperator) ||
                other.logicalOperator == logicalOperator) &&
            const DeepCollectionEquality()
                .equals(other._subConditions, _subConditions));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      operator,
      const DeepCollectionEquality().hash(value),
      isCompound,
      logicalOperator,
      const DeepCollectionEquality().hash(_subConditions));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleConditionImplCopyWith<_$RuleConditionImpl> get copyWith =>
      __$$RuleConditionImplCopyWithImpl<_$RuleConditionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleConditionImplToJson(
      this,
    );
  }
}

abstract class _RuleCondition implements RuleCondition {
  const factory _RuleCondition(
      {final String? id,
      required final ConditionType type,
      required final ConditionOperator operator,
      final dynamic value,
      final bool isCompound,
      final LogicalOperator? logicalOperator,
      final List<RuleCondition> subConditions}) = _$RuleConditionImpl;

  factory _RuleCondition.fromJson(Map<String, dynamic> json) =
      _$RuleConditionImpl.fromJson;

  @override
  String? get id;
  @override
  ConditionType get type;
  @override
  ConditionOperator get operator;
  @override
  dynamic get value;
  @override // 复合条件
  bool get isCompound;
  @override
  LogicalOperator? get logicalOperator;
  @override
  List<RuleCondition> get subConditions;
  @override
  @JsonKey(ignore: true)
  _$$RuleConditionImplCopyWith<_$RuleConditionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleAction _$RuleActionFromJson(Map<String, dynamic> json) {
  return _RuleAction.fromJson(json);
}

/// @nodoc
mixin _$RuleAction {
  String? get id => throw _privateConstructorUsedError;
  ActionType get type => throw _privateConstructorUsedError;
  dynamic get value => throw _privateConstructorUsedError;
  Map<String, dynamic>? get params => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RuleActionCopyWith<RuleAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleActionCopyWith<$Res> {
  factory $RuleActionCopyWith(
          RuleAction value, $Res Function(RuleAction) then) =
      _$RuleActionCopyWithImpl<$Res, RuleAction>;
  @useResult
  $Res call(
      {String? id,
      ActionType type,
      dynamic value,
      Map<String, dynamic>? params});
}

/// @nodoc
class _$RuleActionCopyWithImpl<$Res, $Val extends RuleAction>
    implements $RuleActionCopyWith<$Res> {
  _$RuleActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? value = freezed,
    Object? params = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActionType,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as dynamic,
      params: freezed == params
          ? _value.params
          : params // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleActionImplCopyWith<$Res>
    implements $RuleActionCopyWith<$Res> {
  factory _$$RuleActionImplCopyWith(
          _$RuleActionImpl value, $Res Function(_$RuleActionImpl) then) =
      __$$RuleActionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      ActionType type,
      dynamic value,
      Map<String, dynamic>? params});
}

/// @nodoc
class __$$RuleActionImplCopyWithImpl<$Res>
    extends _$RuleActionCopyWithImpl<$Res, _$RuleActionImpl>
    implements _$$RuleActionImplCopyWith<$Res> {
  __$$RuleActionImplCopyWithImpl(
      _$RuleActionImpl _value, $Res Function(_$RuleActionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? type = null,
    Object? value = freezed,
    Object? params = freezed,
  }) {
    return _then(_$RuleActionImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ActionType,
      value: freezed == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as dynamic,
      params: freezed == params
          ? _value._params
          : params // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleActionImpl implements _RuleAction {
  const _$RuleActionImpl(
      {this.id,
      required this.type,
      this.value,
      final Map<String, dynamic>? params})
      : _params = params;

  factory _$RuleActionImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleActionImplFromJson(json);

  @override
  final String? id;
  @override
  final ActionType type;
  @override
  final dynamic value;
  final Map<String, dynamic>? _params;
  @override
  Map<String, dynamic>? get params {
    final value = _params;
    if (value == null) return null;
    if (_params is EqualUnmodifiableMapView) return _params;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'RuleAction(id: $id, type: $type, value: $value, params: $params)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleActionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other.value, value) &&
            const DeepCollectionEquality().equals(other._params, _params));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      const DeepCollectionEquality().hash(value),
      const DeepCollectionEquality().hash(_params));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleActionImplCopyWith<_$RuleActionImpl> get copyWith =>
      __$$RuleActionImplCopyWithImpl<_$RuleActionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleActionImplToJson(
      this,
    );
  }
}

abstract class _RuleAction implements RuleAction {
  const factory _RuleAction(
      {final String? id,
      required final ActionType type,
      final dynamic value,
      final Map<String, dynamic>? params}) = _$RuleActionImpl;

  factory _RuleAction.fromJson(Map<String, dynamic> json) =
      _$RuleActionImpl.fromJson;

  @override
  String? get id;
  @override
  ActionType get type;
  @override
  dynamic get value;
  @override
  Map<String, dynamic>? get params;
  @override
  @JsonKey(ignore: true)
  _$$RuleActionImplCopyWith<_$RuleActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleLog _$RuleLogFromJson(Map<String, dynamic> json) {
  return _RuleLog.fromJson(json);
}

/// @nodoc
mixin _$RuleLog {
  String? get id => throw _privateConstructorUsedError;
  String get ruleId => throw _privateConstructorUsedError;
  String get resourceId => throw _privateConstructorUsedError;
  ResourceType get resourceType => throw _privateConstructorUsedError;
  bool get success => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  Map<String, dynamic>? get details => throw _privateConstructorUsedError;
  DateTime? get executedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RuleLogCopyWith<RuleLog> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleLogCopyWith<$Res> {
  factory $RuleLogCopyWith(RuleLog value, $Res Function(RuleLog) then) =
      _$RuleLogCopyWithImpl<$Res, RuleLog>;
  @useResult
  $Res call(
      {String? id,
      String ruleId,
      String resourceId,
      ResourceType resourceType,
      bool success,
      String? error,
      Map<String, dynamic>? details,
      DateTime? executedAt});
}

/// @nodoc
class _$RuleLogCopyWithImpl<$Res, $Val extends RuleLog>
    implements $RuleLogCopyWith<$Res> {
  _$RuleLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? ruleId = null,
    Object? resourceId = null,
    Object? resourceType = null,
    Object? success = null,
    Object? error = freezed,
    Object? details = freezed,
    Object? executedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleId: null == ruleId
          ? _value.ruleId
          : ruleId // ignore: cast_nullable_to_non_nullable
              as String,
      resourceId: null == resourceId
          ? _value.resourceId
          : resourceId // ignore: cast_nullable_to_non_nullable
              as String,
      resourceType: null == resourceType
          ? _value.resourceType
          : resourceType // ignore: cast_nullable_to_non_nullable
              as ResourceType,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      details: freezed == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      executedAt: freezed == executedAt
          ? _value.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleLogImplCopyWith<$Res> implements $RuleLogCopyWith<$Res> {
  factory _$$RuleLogImplCopyWith(
          _$RuleLogImpl value, $Res Function(_$RuleLogImpl) then) =
      __$$RuleLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String ruleId,
      String resourceId,
      ResourceType resourceType,
      bool success,
      String? error,
      Map<String, dynamic>? details,
      DateTime? executedAt});
}

/// @nodoc
class __$$RuleLogImplCopyWithImpl<$Res>
    extends _$RuleLogCopyWithImpl<$Res, _$RuleLogImpl>
    implements _$$RuleLogImplCopyWith<$Res> {
  __$$RuleLogImplCopyWithImpl(
      _$RuleLogImpl _value, $Res Function(_$RuleLogImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? ruleId = null,
    Object? resourceId = null,
    Object? resourceType = null,
    Object? success = null,
    Object? error = freezed,
    Object? details = freezed,
    Object? executedAt = freezed,
  }) {
    return _then(_$RuleLogImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleId: null == ruleId
          ? _value.ruleId
          : ruleId // ignore: cast_nullable_to_non_nullable
              as String,
      resourceId: null == resourceId
          ? _value.resourceId
          : resourceId // ignore: cast_nullable_to_non_nullable
              as String,
      resourceType: null == resourceType
          ? _value.resourceType
          : resourceType // ignore: cast_nullable_to_non_nullable
              as ResourceType,
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      details: freezed == details
          ? _value._details
          : details // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      executedAt: freezed == executedAt
          ? _value.executedAt
          : executedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleLogImpl implements _RuleLog {
  const _$RuleLogImpl(
      {this.id,
      required this.ruleId,
      required this.resourceId,
      required this.resourceType,
      required this.success,
      this.error,
      final Map<String, dynamic>? details,
      this.executedAt})
      : _details = details;

  factory _$RuleLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleLogImplFromJson(json);

  @override
  final String? id;
  @override
  final String ruleId;
  @override
  final String resourceId;
  @override
  final ResourceType resourceType;
  @override
  final bool success;
  @override
  final String? error;
  final Map<String, dynamic>? _details;
  @override
  Map<String, dynamic>? get details {
    final value = _details;
    if (value == null) return null;
    if (_details is EqualUnmodifiableMapView) return _details;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime? executedAt;

  @override
  String toString() {
    return 'RuleLog(id: $id, ruleId: $ruleId, resourceId: $resourceId, resourceType: $resourceType, success: $success, error: $error, details: $details, executedAt: $executedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ruleId, ruleId) || other.ruleId == ruleId) &&
            (identical(other.resourceId, resourceId) ||
                other.resourceId == resourceId) &&
            (identical(other.resourceType, resourceType) ||
                other.resourceType == resourceType) &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality().equals(other._details, _details) &&
            (identical(other.executedAt, executedAt) ||
                other.executedAt == executedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      ruleId,
      resourceId,
      resourceType,
      success,
      error,
      const DeepCollectionEquality().hash(_details),
      executedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleLogImplCopyWith<_$RuleLogImpl> get copyWith =>
      __$$RuleLogImplCopyWithImpl<_$RuleLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleLogImplToJson(
      this,
    );
  }
}

abstract class _RuleLog implements RuleLog {
  const factory _RuleLog(
      {final String? id,
      required final String ruleId,
      required final String resourceId,
      required final ResourceType resourceType,
      required final bool success,
      final String? error,
      final Map<String, dynamic>? details,
      final DateTime? executedAt}) = _$RuleLogImpl;

  factory _RuleLog.fromJson(Map<String, dynamic> json) = _$RuleLogImpl.fromJson;

  @override
  String? get id;
  @override
  String get ruleId;
  @override
  String get resourceId;
  @override
  ResourceType get resourceType;
  @override
  bool get success;
  @override
  String? get error;
  @override
  Map<String, dynamic>? get details;
  @override
  DateTime? get executedAt;
  @override
  @JsonKey(ignore: true)
  _$$RuleLogImplCopyWith<_$RuleLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
