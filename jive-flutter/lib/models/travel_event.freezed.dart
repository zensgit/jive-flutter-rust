// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'travel_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TravelEvent _$TravelEventFromJson(Map<String, dynamic> json) {
  return _TravelEvent.fromJson(json);
}

/// @nodoc
mixin _$TravelEvent {
  String? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  bool get autoTag => throw _privateConstructorUsedError;
  List<String> get travelCategoryIds => throw _privateConstructorUsedError;
  String? get ledgerId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError; // 统计信息
  int get transactionCount => throw _privateConstructorUsedError;
  double? get totalAmount => throw _privateConstructorUsedError;
  String? get travelTagId => throw _privateConstructorUsedError; // 预算相关
  double? get totalBudget => throw _privateConstructorUsedError;
  String? get budgetCurrencyCode => throw _privateConstructorUsedError;
  double get totalSpent => throw _privateConstructorUsedError;
  String? get homeCurrencyCode => throw _privateConstructorUsedError;
  double? get budgetUsagePercent => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TravelEventCopyWith<TravelEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TravelEventCopyWith<$Res> {
  factory $TravelEventCopyWith(
          TravelEvent value, $Res Function(TravelEvent) then) =
      _$TravelEventCopyWithImpl<$Res, TravelEvent>;
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      DateTime startDate,
      DateTime endDate,
      String? location,
      String status,
      bool isActive,
      bool autoTag,
      List<String> travelCategoryIds,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt,
      int transactionCount,
      double? totalAmount,
      String? travelTagId,
      double? totalBudget,
      String? budgetCurrencyCode,
      double totalSpent,
      String? homeCurrencyCode,
      double? budgetUsagePercent});
}

/// @nodoc
class _$TravelEventCopyWithImpl<$Res, $Val extends TravelEvent>
    implements $TravelEventCopyWith<$Res> {
  _$TravelEventCopyWithImpl(this._value, this._then);

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
    Object? startDate = null,
    Object? endDate = null,
    Object? location = freezed,
    Object? status = null,
    Object? isActive = null,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? transactionCount = null,
    Object? totalAmount = freezed,
    Object? travelTagId = freezed,
    Object? totalBudget = freezed,
    Object? budgetCurrencyCode = freezed,
    Object? totalSpent = null,
    Object? homeCurrencyCode = freezed,
    Object? budgetUsagePercent = freezed,
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
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      autoTag: null == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool,
      travelCategoryIds: null == travelCategoryIds
          ? _value.travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      ledgerId: freezed == ledgerId
          ? _value.ledgerId
          : ledgerId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transactionCount: null == transactionCount
          ? _value.transactionCount
          : transactionCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      travelTagId: freezed == travelTagId
          ? _value.travelTagId
          : travelTagId // ignore: cast_nullable_to_non_nullable
              as String?,
      totalBudget: freezed == totalBudget
          ? _value.totalBudget
          : totalBudget // ignore: cast_nullable_to_non_nullable
              as double?,
      budgetCurrencyCode: freezed == budgetCurrencyCode
          ? _value.budgetCurrencyCode
          : budgetCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      homeCurrencyCode: freezed == homeCurrencyCode
          ? _value.homeCurrencyCode
          : homeCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      budgetUsagePercent: freezed == budgetUsagePercent
          ? _value.budgetUsagePercent
          : budgetUsagePercent // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TravelEventImplCopyWith<$Res>
    implements $TravelEventCopyWith<$Res> {
  factory _$$TravelEventImplCopyWith(
          _$TravelEventImpl value, $Res Function(_$TravelEventImpl) then) =
      __$$TravelEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      DateTime startDate,
      DateTime endDate,
      String? location,
      String status,
      bool isActive,
      bool autoTag,
      List<String> travelCategoryIds,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt,
      int transactionCount,
      double? totalAmount,
      String? travelTagId,
      double? totalBudget,
      String? budgetCurrencyCode,
      double totalSpent,
      String? homeCurrencyCode,
      double? budgetUsagePercent});
}

/// @nodoc
class __$$TravelEventImplCopyWithImpl<$Res>
    extends _$TravelEventCopyWithImpl<$Res, _$TravelEventImpl>
    implements _$$TravelEventImplCopyWith<$Res> {
  __$$TravelEventImplCopyWithImpl(
      _$TravelEventImpl _value, $Res Function(_$TravelEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? location = freezed,
    Object? status = null,
    Object? isActive = null,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? transactionCount = null,
    Object? totalAmount = freezed,
    Object? travelTagId = freezed,
    Object? totalBudget = freezed,
    Object? budgetCurrencyCode = freezed,
    Object? totalSpent = null,
    Object? homeCurrencyCode = freezed,
    Object? budgetUsagePercent = freezed,
  }) {
    return _then(_$TravelEventImpl(
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
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      autoTag: null == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool,
      travelCategoryIds: null == travelCategoryIds
          ? _value._travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      ledgerId: freezed == ledgerId
          ? _value.ledgerId
          : ledgerId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transactionCount: null == transactionCount
          ? _value.transactionCount
          : transactionCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalAmount: freezed == totalAmount
          ? _value.totalAmount
          : totalAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      travelTagId: freezed == travelTagId
          ? _value.travelTagId
          : travelTagId // ignore: cast_nullable_to_non_nullable
              as String?,
      totalBudget: freezed == totalBudget
          ? _value.totalBudget
          : totalBudget // ignore: cast_nullable_to_non_nullable
              as double?,
      budgetCurrencyCode: freezed == budgetCurrencyCode
          ? _value.budgetCurrencyCode
          : budgetCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      homeCurrencyCode: freezed == homeCurrencyCode
          ? _value.homeCurrencyCode
          : homeCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      budgetUsagePercent: freezed == budgetUsagePercent
          ? _value.budgetUsagePercent
          : budgetUsagePercent // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TravelEventImpl extends _TravelEvent {
  const _$TravelEventImpl(
      {this.id,
      required this.name,
      this.description,
      required this.startDate,
      required this.endDate,
      this.location,
      this.status = 'planning',
      this.isActive = true,
      this.autoTag = false,
      final List<String> travelCategoryIds = const [],
      this.ledgerId,
      this.createdAt,
      this.updatedAt,
      this.transactionCount = 0,
      this.totalAmount,
      this.travelTagId,
      this.totalBudget,
      this.budgetCurrencyCode,
      this.totalSpent = 0,
      this.homeCurrencyCode,
      this.budgetUsagePercent})
      : _travelCategoryIds = travelCategoryIds,
        super._();

  factory _$TravelEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$TravelEventImplFromJson(json);

  @override
  final String? id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final String? location;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final bool isActive;
  @override
  @JsonKey()
  final bool autoTag;
  final List<String> _travelCategoryIds;
  @override
  @JsonKey()
  List<String> get travelCategoryIds {
    if (_travelCategoryIds is EqualUnmodifiableListView)
      return _travelCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_travelCategoryIds);
  }

  @override
  final String? ledgerId;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
// 统计信息
  @override
  @JsonKey()
  final int transactionCount;
  @override
  final double? totalAmount;
  @override
  final String? travelTagId;
// 预算相关
  @override
  final double? totalBudget;
  @override
  final String? budgetCurrencyCode;
  @override
  @JsonKey()
  final double totalSpent;
  @override
  final String? homeCurrencyCode;
  @override
  final double? budgetUsagePercent;

  @override
  String toString() {
    return 'TravelEvent(id: $id, name: $name, description: $description, startDate: $startDate, endDate: $endDate, location: $location, status: $status, isActive: $isActive, autoTag: $autoTag, travelCategoryIds: $travelCategoryIds, ledgerId: $ledgerId, createdAt: $createdAt, updatedAt: $updatedAt, transactionCount: $transactionCount, totalAmount: $totalAmount, travelTagId: $travelTagId, totalBudget: $totalBudget, budgetCurrencyCode: $budgetCurrencyCode, totalSpent: $totalSpent, homeCurrencyCode: $homeCurrencyCode, budgetUsagePercent: $budgetUsagePercent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TravelEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.autoTag, autoTag) || other.autoTag == autoTag) &&
            const DeepCollectionEquality()
                .equals(other._travelCategoryIds, _travelCategoryIds) &&
            (identical(other.ledgerId, ledgerId) ||
                other.ledgerId == ledgerId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.travelTagId, travelTagId) ||
                other.travelTagId == travelTagId) &&
            (identical(other.totalBudget, totalBudget) ||
                other.totalBudget == totalBudget) &&
            (identical(other.budgetCurrencyCode, budgetCurrencyCode) ||
                other.budgetCurrencyCode == budgetCurrencyCode) &&
            (identical(other.totalSpent, totalSpent) ||
                other.totalSpent == totalSpent) &&
            (identical(other.homeCurrencyCode, homeCurrencyCode) ||
                other.homeCurrencyCode == homeCurrencyCode) &&
            (identical(other.budgetUsagePercent, budgetUsagePercent) ||
                other.budgetUsagePercent == budgetUsagePercent));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        description,
        startDate,
        endDate,
        location,
        status,
        isActive,
        autoTag,
        const DeepCollectionEquality().hash(_travelCategoryIds),
        ledgerId,
        createdAt,
        updatedAt,
        transactionCount,
        totalAmount,
        travelTagId,
        totalBudget,
        budgetCurrencyCode,
        totalSpent,
        homeCurrencyCode,
        budgetUsagePercent
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TravelEventImplCopyWith<_$TravelEventImpl> get copyWith =>
      __$$TravelEventImplCopyWithImpl<_$TravelEventImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TravelEventImplToJson(
      this,
    );
  }
}

abstract class _TravelEvent extends TravelEvent {
  const factory _TravelEvent(
      {final String? id,
      required final String name,
      final String? description,
      required final DateTime startDate,
      required final DateTime endDate,
      final String? location,
      final String status,
      final bool isActive,
      final bool autoTag,
      final List<String> travelCategoryIds,
      final String? ledgerId,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final int transactionCount,
      final double? totalAmount,
      final String? travelTagId,
      final double? totalBudget,
      final String? budgetCurrencyCode,
      final double totalSpent,
      final String? homeCurrencyCode,
      final double? budgetUsagePercent}) = _$TravelEventImpl;
  const _TravelEvent._() : super._();

  factory _TravelEvent.fromJson(Map<String, dynamic> json) =
      _$TravelEventImpl.fromJson;

  @override
  String? get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  String? get location;
  @override
  String get status;
  @override
  bool get isActive;
  @override
  bool get autoTag;
  @override
  List<String> get travelCategoryIds;
  @override
  String? get ledgerId;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override // 统计信息
  int get transactionCount;
  @override
  double? get totalAmount;
  @override
  String? get travelTagId;
  @override // 预算相关
  double? get totalBudget;
  @override
  String? get budgetCurrencyCode;
  @override
  double get totalSpent;
  @override
  String? get homeCurrencyCode;
  @override
  double? get budgetUsagePercent;
  @override
  @JsonKey(ignore: true)
  _$$TravelEventImplCopyWith<_$TravelEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TravelEventTemplate _$TravelEventTemplateFromJson(Map<String, dynamic> json) {
  return _TravelEventTemplate.fromJson(json);
}

/// @nodoc
mixin _$TravelEventTemplate {
  String? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  TravelTemplateType get templateType => throw _privateConstructorUsedError;
  List<String> get categoryIds => throw _privateConstructorUsedError;
  bool get isSystemTemplate => throw _privateConstructorUsedError;
  String? get ledgerId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TravelEventTemplateCopyWith<TravelEventTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TravelEventTemplateCopyWith<$Res> {
  factory $TravelEventTemplateCopyWith(
          TravelEventTemplate value, $Res Function(TravelEventTemplate) then) =
      _$TravelEventTemplateCopyWithImpl<$Res, TravelEventTemplate>;
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      TravelTemplateType templateType,
      List<String> categoryIds,
      bool isSystemTemplate,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$TravelEventTemplateCopyWithImpl<$Res, $Val extends TravelEventTemplate>
    implements $TravelEventTemplateCopyWith<$Res> {
  _$TravelEventTemplateCopyWithImpl(this._value, this._then);

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
    Object? templateType = null,
    Object? categoryIds = null,
    Object? isSystemTemplate = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
      templateType: null == templateType
          ? _value.templateType
          : templateType // ignore: cast_nullable_to_non_nullable
              as TravelTemplateType,
      categoryIds: null == categoryIds
          ? _value.categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isSystemTemplate: null == isSystemTemplate
          ? _value.isSystemTemplate
          : isSystemTemplate // ignore: cast_nullable_to_non_nullable
              as bool,
      ledgerId: freezed == ledgerId
          ? _value.ledgerId
          : ledgerId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TravelEventTemplateImplCopyWith<$Res>
    implements $TravelEventTemplateCopyWith<$Res> {
  factory _$$TravelEventTemplateImplCopyWith(_$TravelEventTemplateImpl value,
          $Res Function(_$TravelEventTemplateImpl) then) =
      __$$TravelEventTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String name,
      String? description,
      TravelTemplateType templateType,
      List<String> categoryIds,
      bool isSystemTemplate,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$TravelEventTemplateImplCopyWithImpl<$Res>
    extends _$TravelEventTemplateCopyWithImpl<$Res, _$TravelEventTemplateImpl>
    implements _$$TravelEventTemplateImplCopyWith<$Res> {
  __$$TravelEventTemplateImplCopyWithImpl(_$TravelEventTemplateImpl _value,
      $Res Function(_$TravelEventTemplateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? description = freezed,
    Object? templateType = null,
    Object? categoryIds = null,
    Object? isSystemTemplate = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$TravelEventTemplateImpl(
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
      templateType: null == templateType
          ? _value.templateType
          : templateType // ignore: cast_nullable_to_non_nullable
              as TravelTemplateType,
      categoryIds: null == categoryIds
          ? _value._categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isSystemTemplate: null == isSystemTemplate
          ? _value.isSystemTemplate
          : isSystemTemplate // ignore: cast_nullable_to_non_nullable
              as bool,
      ledgerId: freezed == ledgerId
          ? _value.ledgerId
          : ledgerId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TravelEventTemplateImpl implements _TravelEventTemplate {
  const _$TravelEventTemplateImpl(
      {this.id,
      required this.name,
      this.description,
      required this.templateType,
      final List<String> categoryIds = const [],
      this.isSystemTemplate = false,
      this.ledgerId,
      this.createdAt,
      this.updatedAt})
      : _categoryIds = categoryIds;

  factory _$TravelEventTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$TravelEventTemplateImplFromJson(json);

  @override
  final String? id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final TravelTemplateType templateType;
  final List<String> _categoryIds;
  @override
  @JsonKey()
  List<String> get categoryIds {
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryIds);
  }

  @override
  @JsonKey()
  final bool isSystemTemplate;
  @override
  final String? ledgerId;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'TravelEventTemplate(id: $id, name: $name, description: $description, templateType: $templateType, categoryIds: $categoryIds, isSystemTemplate: $isSystemTemplate, ledgerId: $ledgerId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TravelEventTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.templateType, templateType) ||
                other.templateType == templateType) &&
            const DeepCollectionEquality()
                .equals(other._categoryIds, _categoryIds) &&
            (identical(other.isSystemTemplate, isSystemTemplate) ||
                other.isSystemTemplate == isSystemTemplate) &&
            (identical(other.ledgerId, ledgerId) ||
                other.ledgerId == ledgerId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      templateType,
      const DeepCollectionEquality().hash(_categoryIds),
      isSystemTemplate,
      ledgerId,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TravelEventTemplateImplCopyWith<_$TravelEventTemplateImpl> get copyWith =>
      __$$TravelEventTemplateImplCopyWithImpl<_$TravelEventTemplateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TravelEventTemplateImplToJson(
      this,
    );
  }
}

abstract class _TravelEventTemplate implements TravelEventTemplate {
  const factory _TravelEventTemplate(
      {final String? id,
      required final String name,
      final String? description,
      required final TravelTemplateType templateType,
      final List<String> categoryIds,
      final bool isSystemTemplate,
      final String? ledgerId,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$TravelEventTemplateImpl;

  factory _TravelEventTemplate.fromJson(Map<String, dynamic> json) =
      _$TravelEventTemplateImpl.fromJson;

  @override
  String? get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  TravelTemplateType get templateType;
  @override
  List<String> get categoryIds;
  @override
  bool get isSystemTemplate;
  @override
  String? get ledgerId;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$TravelEventTemplateImplCopyWith<_$TravelEventTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CreateTravelEventInput _$CreateTravelEventInputFromJson(
    Map<String, dynamic> json) {
  return _CreateTravelEventInput.fromJson(json);
}

/// @nodoc
mixin _$CreateTravelEventInput {
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  bool get autoTag => throw _privateConstructorUsedError;
  List<String> get travelCategoryIds => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CreateTravelEventInputCopyWith<CreateTravelEventInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateTravelEventInputCopyWith<$Res> {
  factory $CreateTravelEventInputCopyWith(CreateTravelEventInput value,
          $Res Function(CreateTravelEventInput) then) =
      _$CreateTravelEventInputCopyWithImpl<$Res, CreateTravelEventInput>;
  @useResult
  $Res call(
      {String name,
      String? description,
      DateTime startDate,
      DateTime endDate,
      String? location,
      bool autoTag,
      List<String> travelCategoryIds});
}

/// @nodoc
class _$CreateTravelEventInputCopyWithImpl<$Res,
        $Val extends CreateTravelEventInput>
    implements $CreateTravelEventInputCopyWith<$Res> {
  _$CreateTravelEventInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? location = freezed,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      autoTag: null == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool,
      travelCategoryIds: null == travelCategoryIds
          ? _value.travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateTravelEventInputImplCopyWith<$Res>
    implements $CreateTravelEventInputCopyWith<$Res> {
  factory _$$CreateTravelEventInputImplCopyWith(
          _$CreateTravelEventInputImpl value,
          $Res Function(_$CreateTravelEventInputImpl) then) =
      __$$CreateTravelEventInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String? description,
      DateTime startDate,
      DateTime endDate,
      String? location,
      bool autoTag,
      List<String> travelCategoryIds});
}

/// @nodoc
class __$$CreateTravelEventInputImplCopyWithImpl<$Res>
    extends _$CreateTravelEventInputCopyWithImpl<$Res,
        _$CreateTravelEventInputImpl>
    implements _$$CreateTravelEventInputImplCopyWith<$Res> {
  __$$CreateTravelEventInputImplCopyWithImpl(
      _$CreateTravelEventInputImpl _value,
      $Res Function(_$CreateTravelEventInputImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = freezed,
    Object? startDate = null,
    Object? endDate = null,
    Object? location = freezed,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
  }) {
    return _then(_$CreateTravelEventInputImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      autoTag: null == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool,
      travelCategoryIds: null == travelCategoryIds
          ? _value._travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateTravelEventInputImpl implements _CreateTravelEventInput {
  const _$CreateTravelEventInputImpl(
      {required this.name,
      this.description,
      required this.startDate,
      required this.endDate,
      this.location,
      this.autoTag = true,
      final List<String> travelCategoryIds = const []})
      : _travelCategoryIds = travelCategoryIds;

  factory _$CreateTravelEventInputImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateTravelEventInputImplFromJson(json);

  @override
  final String name;
  @override
  final String? description;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final String? location;
  @override
  @JsonKey()
  final bool autoTag;
  final List<String> _travelCategoryIds;
  @override
  @JsonKey()
  List<String> get travelCategoryIds {
    if (_travelCategoryIds is EqualUnmodifiableListView)
      return _travelCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_travelCategoryIds);
  }

  @override
  String toString() {
    return 'CreateTravelEventInput(name: $name, description: $description, startDate: $startDate, endDate: $endDate, location: $location, autoTag: $autoTag, travelCategoryIds: $travelCategoryIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateTravelEventInputImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.autoTag, autoTag) || other.autoTag == autoTag) &&
            const DeepCollectionEquality()
                .equals(other._travelCategoryIds, _travelCategoryIds));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      startDate,
      endDate,
      location,
      autoTag,
      const DeepCollectionEquality().hash(_travelCategoryIds));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateTravelEventInputImplCopyWith<_$CreateTravelEventInputImpl>
      get copyWith => __$$CreateTravelEventInputImplCopyWithImpl<
          _$CreateTravelEventInputImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateTravelEventInputImplToJson(
      this,
    );
  }
}

abstract class _CreateTravelEventInput implements CreateTravelEventInput {
  const factory _CreateTravelEventInput(
      {required final String name,
      final String? description,
      required final DateTime startDate,
      required final DateTime endDate,
      final String? location,
      final bool autoTag,
      final List<String> travelCategoryIds}) = _$CreateTravelEventInputImpl;

  factory _CreateTravelEventInput.fromJson(Map<String, dynamic> json) =
      _$CreateTravelEventInputImpl.fromJson;

  @override
  String get name;
  @override
  String? get description;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  String? get location;
  @override
  bool get autoTag;
  @override
  List<String> get travelCategoryIds;
  @override
  @JsonKey(ignore: true)
  _$$CreateTravelEventInputImplCopyWith<_$CreateTravelEventInputImpl>
      get copyWith => throw _privateConstructorUsedError;
}

UpdateTravelEventInput _$UpdateTravelEventInputFromJson(
    Map<String, dynamic> json) {
  return _UpdateTravelEventInput.fromJson(json);
}

/// @nodoc
mixin _$UpdateTravelEventInput {
  String? get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime? get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  bool? get autoTag => throw _privateConstructorUsedError;
  List<String>? get travelCategoryIds => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UpdateTravelEventInputCopyWith<UpdateTravelEventInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateTravelEventInputCopyWith<$Res> {
  factory $UpdateTravelEventInputCopyWith(UpdateTravelEventInput value,
          $Res Function(UpdateTravelEventInput) then) =
      _$UpdateTravelEventInputCopyWithImpl<$Res, UpdateTravelEventInput>;
  @useResult
  $Res call(
      {String? name,
      String? description,
      DateTime? startDate,
      DateTime? endDate,
      String? location,
      bool? autoTag,
      List<String>? travelCategoryIds});
}

/// @nodoc
class _$UpdateTravelEventInputCopyWithImpl<$Res,
        $Val extends UpdateTravelEventInput>
    implements $UpdateTravelEventInputCopyWith<$Res> {
  _$UpdateTravelEventInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? description = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? location = freezed,
    Object? autoTag = freezed,
    Object? travelCategoryIds = freezed,
  }) {
    return _then(_value.copyWith(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      autoTag: freezed == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool?,
      travelCategoryIds: freezed == travelCategoryIds
          ? _value.travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UpdateTravelEventInputImplCopyWith<$Res>
    implements $UpdateTravelEventInputCopyWith<$Res> {
  factory _$$UpdateTravelEventInputImplCopyWith(
          _$UpdateTravelEventInputImpl value,
          $Res Function(_$UpdateTravelEventInputImpl) then) =
      __$$UpdateTravelEventInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? name,
      String? description,
      DateTime? startDate,
      DateTime? endDate,
      String? location,
      bool? autoTag,
      List<String>? travelCategoryIds});
}

/// @nodoc
class __$$UpdateTravelEventInputImplCopyWithImpl<$Res>
    extends _$UpdateTravelEventInputCopyWithImpl<$Res,
        _$UpdateTravelEventInputImpl>
    implements _$$UpdateTravelEventInputImplCopyWith<$Res> {
  __$$UpdateTravelEventInputImplCopyWithImpl(
      _$UpdateTravelEventInputImpl _value,
      $Res Function(_$UpdateTravelEventInputImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? description = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? location = freezed,
    Object? autoTag = freezed,
    Object? travelCategoryIds = freezed,
  }) {
    return _then(_$UpdateTravelEventInputImpl(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      autoTag: freezed == autoTag
          ? _value.autoTag
          : autoTag // ignore: cast_nullable_to_non_nullable
              as bool?,
      travelCategoryIds: freezed == travelCategoryIds
          ? _value._travelCategoryIds
          : travelCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateTravelEventInputImpl implements _UpdateTravelEventInput {
  const _$UpdateTravelEventInputImpl(
      {this.name,
      this.description,
      this.startDate,
      this.endDate,
      this.location,
      this.autoTag,
      final List<String>? travelCategoryIds})
      : _travelCategoryIds = travelCategoryIds;

  factory _$UpdateTravelEventInputImpl.fromJson(Map<String, dynamic> json) =>
      _$$UpdateTravelEventInputImplFromJson(json);

  @override
  final String? name;
  @override
  final String? description;
  @override
  final DateTime? startDate;
  @override
  final DateTime? endDate;
  @override
  final String? location;
  @override
  final bool? autoTag;
  final List<String>? _travelCategoryIds;
  @override
  List<String>? get travelCategoryIds {
    final value = _travelCategoryIds;
    if (value == null) return null;
    if (_travelCategoryIds is EqualUnmodifiableListView)
      return _travelCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'UpdateTravelEventInput(name: $name, description: $description, startDate: $startDate, endDate: $endDate, location: $location, autoTag: $autoTag, travelCategoryIds: $travelCategoryIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateTravelEventInputImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.autoTag, autoTag) || other.autoTag == autoTag) &&
            const DeepCollectionEquality()
                .equals(other._travelCategoryIds, _travelCategoryIds));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      startDate,
      endDate,
      location,
      autoTag,
      const DeepCollectionEquality().hash(_travelCategoryIds));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateTravelEventInputImplCopyWith<_$UpdateTravelEventInputImpl>
      get copyWith => __$$UpdateTravelEventInputImplCopyWithImpl<
          _$UpdateTravelEventInputImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateTravelEventInputImplToJson(
      this,
    );
  }
}

abstract class _UpdateTravelEventInput implements UpdateTravelEventInput {
  const factory _UpdateTravelEventInput(
      {final String? name,
      final String? description,
      final DateTime? startDate,
      final DateTime? endDate,
      final String? location,
      final bool? autoTag,
      final List<String>? travelCategoryIds}) = _$UpdateTravelEventInputImpl;

  factory _UpdateTravelEventInput.fromJson(Map<String, dynamic> json) =
      _$UpdateTravelEventInputImpl.fromJson;

  @override
  String? get name;
  @override
  String? get description;
  @override
  DateTime? get startDate;
  @override
  DateTime? get endDate;
  @override
  String? get location;
  @override
  bool? get autoTag;
  @override
  List<String>? get travelCategoryIds;
  @override
  @JsonKey(ignore: true)
  _$$UpdateTravelEventInputImplCopyWith<_$UpdateTravelEventInputImpl>
      get copyWith => throw _privateConstructorUsedError;
}

TravelStatistics _$TravelStatisticsFromJson(Map<String, dynamic> json) {
  return _TravelStatistics.fromJson(json);
}

/// @nodoc
mixin _$TravelStatistics {
  double get totalSpent => throw _privateConstructorUsedError;
  double get totalBudget => throw _privateConstructorUsedError;
  double get budgetUsage => throw _privateConstructorUsedError;
  Map<String, double> get spentByCategory => throw _privateConstructorUsedError;
  Map<String, double> get spentByDay => throw _privateConstructorUsedError;
  int get transactionCount => throw _privateConstructorUsedError;
  double get averagePerDay => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TravelStatisticsCopyWith<TravelStatistics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TravelStatisticsCopyWith<$Res> {
  factory $TravelStatisticsCopyWith(
          TravelStatistics value, $Res Function(TravelStatistics) then) =
      _$TravelStatisticsCopyWithImpl<$Res, TravelStatistics>;
  @useResult
  $Res call(
      {double totalSpent,
      double totalBudget,
      double budgetUsage,
      Map<String, double> spentByCategory,
      Map<String, double> spentByDay,
      int transactionCount,
      double averagePerDay});
}

/// @nodoc
class _$TravelStatisticsCopyWithImpl<$Res, $Val extends TravelStatistics>
    implements $TravelStatisticsCopyWith<$Res> {
  _$TravelStatisticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalSpent = null,
    Object? totalBudget = null,
    Object? budgetUsage = null,
    Object? spentByCategory = null,
    Object? spentByDay = null,
    Object? transactionCount = null,
    Object? averagePerDay = null,
  }) {
    return _then(_value.copyWith(
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      totalBudget: null == totalBudget
          ? _value.totalBudget
          : totalBudget // ignore: cast_nullable_to_non_nullable
              as double,
      budgetUsage: null == budgetUsage
          ? _value.budgetUsage
          : budgetUsage // ignore: cast_nullable_to_non_nullable
              as double,
      spentByCategory: null == spentByCategory
          ? _value.spentByCategory
          : spentByCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      spentByDay: null == spentByDay
          ? _value.spentByDay
          : spentByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      transactionCount: null == transactionCount
          ? _value.transactionCount
          : transactionCount // ignore: cast_nullable_to_non_nullable
              as int,
      averagePerDay: null == averagePerDay
          ? _value.averagePerDay
          : averagePerDay // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TravelStatisticsImplCopyWith<$Res>
    implements $TravelStatisticsCopyWith<$Res> {
  factory _$$TravelStatisticsImplCopyWith(_$TravelStatisticsImpl value,
          $Res Function(_$TravelStatisticsImpl) then) =
      __$$TravelStatisticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double totalSpent,
      double totalBudget,
      double budgetUsage,
      Map<String, double> spentByCategory,
      Map<String, double> spentByDay,
      int transactionCount,
      double averagePerDay});
}

/// @nodoc
class __$$TravelStatisticsImplCopyWithImpl<$Res>
    extends _$TravelStatisticsCopyWithImpl<$Res, _$TravelStatisticsImpl>
    implements _$$TravelStatisticsImplCopyWith<$Res> {
  __$$TravelStatisticsImplCopyWithImpl(_$TravelStatisticsImpl _value,
      $Res Function(_$TravelStatisticsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalSpent = null,
    Object? totalBudget = null,
    Object? budgetUsage = null,
    Object? spentByCategory = null,
    Object? spentByDay = null,
    Object? transactionCount = null,
    Object? averagePerDay = null,
  }) {
    return _then(_$TravelStatisticsImpl(
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      totalBudget: null == totalBudget
          ? _value.totalBudget
          : totalBudget // ignore: cast_nullable_to_non_nullable
              as double,
      budgetUsage: null == budgetUsage
          ? _value.budgetUsage
          : budgetUsage // ignore: cast_nullable_to_non_nullable
              as double,
      spentByCategory: null == spentByCategory
          ? _value._spentByCategory
          : spentByCategory // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      spentByDay: null == spentByDay
          ? _value._spentByDay
          : spentByDay // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      transactionCount: null == transactionCount
          ? _value.transactionCount
          : transactionCount // ignore: cast_nullable_to_non_nullable
              as int,
      averagePerDay: null == averagePerDay
          ? _value.averagePerDay
          : averagePerDay // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TravelStatisticsImpl implements _TravelStatistics {
  const _$TravelStatisticsImpl(
      {required this.totalSpent,
      required this.totalBudget,
      required this.budgetUsage,
      required final Map<String, double> spentByCategory,
      required final Map<String, double> spentByDay,
      required this.transactionCount,
      required this.averagePerDay})
      : _spentByCategory = spentByCategory,
        _spentByDay = spentByDay;

  factory _$TravelStatisticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TravelStatisticsImplFromJson(json);

  @override
  final double totalSpent;
  @override
  final double totalBudget;
  @override
  final double budgetUsage;
  final Map<String, double> _spentByCategory;
  @override
  Map<String, double> get spentByCategory {
    if (_spentByCategory is EqualUnmodifiableMapView) return _spentByCategory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_spentByCategory);
  }

  final Map<String, double> _spentByDay;
  @override
  Map<String, double> get spentByDay {
    if (_spentByDay is EqualUnmodifiableMapView) return _spentByDay;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_spentByDay);
  }

  @override
  final int transactionCount;
  @override
  final double averagePerDay;

  @override
  String toString() {
    return 'TravelStatistics(totalSpent: $totalSpent, totalBudget: $totalBudget, budgetUsage: $budgetUsage, spentByCategory: $spentByCategory, spentByDay: $spentByDay, transactionCount: $transactionCount, averagePerDay: $averagePerDay)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TravelStatisticsImpl &&
            (identical(other.totalSpent, totalSpent) ||
                other.totalSpent == totalSpent) &&
            (identical(other.totalBudget, totalBudget) ||
                other.totalBudget == totalBudget) &&
            (identical(other.budgetUsage, budgetUsage) ||
                other.budgetUsage == budgetUsage) &&
            const DeepCollectionEquality()
                .equals(other._spentByCategory, _spentByCategory) &&
            const DeepCollectionEquality()
                .equals(other._spentByDay, _spentByDay) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount) &&
            (identical(other.averagePerDay, averagePerDay) ||
                other.averagePerDay == averagePerDay));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalSpent,
      totalBudget,
      budgetUsage,
      const DeepCollectionEquality().hash(_spentByCategory),
      const DeepCollectionEquality().hash(_spentByDay),
      transactionCount,
      averagePerDay);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TravelStatisticsImplCopyWith<_$TravelStatisticsImpl> get copyWith =>
      __$$TravelStatisticsImplCopyWithImpl<_$TravelStatisticsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TravelStatisticsImplToJson(
      this,
    );
  }
}

abstract class _TravelStatistics implements TravelStatistics {
  const factory _TravelStatistics(
      {required final double totalSpent,
      required final double totalBudget,
      required final double budgetUsage,
      required final Map<String, double> spentByCategory,
      required final Map<String, double> spentByDay,
      required final int transactionCount,
      required final double averagePerDay}) = _$TravelStatisticsImpl;

  factory _TravelStatistics.fromJson(Map<String, dynamic> json) =
      _$TravelStatisticsImpl.fromJson;

  @override
  double get totalSpent;
  @override
  double get totalBudget;
  @override
  double get budgetUsage;
  @override
  Map<String, double> get spentByCategory;
  @override
  Map<String, double> get spentByDay;
  @override
  int get transactionCount;
  @override
  double get averagePerDay;
  @override
  @JsonKey(ignore: true)
  _$$TravelStatisticsImplCopyWith<_$TravelStatisticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TravelBudget _$TravelBudgetFromJson(Map<String, dynamic> json) {
  return _TravelBudget.fromJson(json);
}

/// @nodoc
mixin _$TravelBudget {
  String? get id => throw _privateConstructorUsedError;
  String get travelEventId => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  String get categoryName => throw _privateConstructorUsedError;
  double get budgetAmount => throw _privateConstructorUsedError;
  String? get budgetCurrencyCode => throw _privateConstructorUsedError;
  double get alertThreshold => throw _privateConstructorUsedError;
  double get spentAmount => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TravelBudgetCopyWith<TravelBudget> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TravelBudgetCopyWith<$Res> {
  factory $TravelBudgetCopyWith(
          TravelBudget value, $Res Function(TravelBudget) then) =
      _$TravelBudgetCopyWithImpl<$Res, TravelBudget>;
  @useResult
  $Res call(
      {String? id,
      String travelEventId,
      String categoryId,
      String categoryName,
      double budgetAmount,
      String? budgetCurrencyCode,
      double alertThreshold,
      double spentAmount,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$TravelBudgetCopyWithImpl<$Res, $Val extends TravelBudget>
    implements $TravelBudgetCopyWith<$Res> {
  _$TravelBudgetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? travelEventId = null,
    Object? categoryId = null,
    Object? categoryName = null,
    Object? budgetAmount = null,
    Object? budgetCurrencyCode = freezed,
    Object? alertThreshold = null,
    Object? spentAmount = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      travelEventId: null == travelEventId
          ? _value.travelEventId
          : travelEventId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryName: null == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String,
      budgetAmount: null == budgetAmount
          ? _value.budgetAmount
          : budgetAmount // ignore: cast_nullable_to_non_nullable
              as double,
      budgetCurrencyCode: freezed == budgetCurrencyCode
          ? _value.budgetCurrencyCode
          : budgetCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      alertThreshold: null == alertThreshold
          ? _value.alertThreshold
          : alertThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      spentAmount: null == spentAmount
          ? _value.spentAmount
          : spentAmount // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TravelBudgetImplCopyWith<$Res>
    implements $TravelBudgetCopyWith<$Res> {
  factory _$$TravelBudgetImplCopyWith(
          _$TravelBudgetImpl value, $Res Function(_$TravelBudgetImpl) then) =
      __$$TravelBudgetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String travelEventId,
      String categoryId,
      String categoryName,
      double budgetAmount,
      String? budgetCurrencyCode,
      double alertThreshold,
      double spentAmount,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$TravelBudgetImplCopyWithImpl<$Res>
    extends _$TravelBudgetCopyWithImpl<$Res, _$TravelBudgetImpl>
    implements _$$TravelBudgetImplCopyWith<$Res> {
  __$$TravelBudgetImplCopyWithImpl(
      _$TravelBudgetImpl _value, $Res Function(_$TravelBudgetImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? travelEventId = null,
    Object? categoryId = null,
    Object? categoryName = null,
    Object? budgetAmount = null,
    Object? budgetCurrencyCode = freezed,
    Object? alertThreshold = null,
    Object? spentAmount = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$TravelBudgetImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      travelEventId: null == travelEventId
          ? _value.travelEventId
          : travelEventId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryName: null == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String,
      budgetAmount: null == budgetAmount
          ? _value.budgetAmount
          : budgetAmount // ignore: cast_nullable_to_non_nullable
              as double,
      budgetCurrencyCode: freezed == budgetCurrencyCode
          ? _value.budgetCurrencyCode
          : budgetCurrencyCode // ignore: cast_nullable_to_non_nullable
              as String?,
      alertThreshold: null == alertThreshold
          ? _value.alertThreshold
          : alertThreshold // ignore: cast_nullable_to_non_nullable
              as double,
      spentAmount: null == spentAmount
          ? _value.spentAmount
          : spentAmount // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TravelBudgetImpl implements _TravelBudget {
  const _$TravelBudgetImpl(
      {this.id,
      required this.travelEventId,
      required this.categoryId,
      required this.categoryName,
      required this.budgetAmount,
      this.budgetCurrencyCode,
      this.alertThreshold = 0.8,
      this.spentAmount = 0,
      this.createdAt,
      this.updatedAt});

  factory _$TravelBudgetImpl.fromJson(Map<String, dynamic> json) =>
      _$$TravelBudgetImplFromJson(json);

  @override
  final String? id;
  @override
  final String travelEventId;
  @override
  final String categoryId;
  @override
  final String categoryName;
  @override
  final double budgetAmount;
  @override
  final String? budgetCurrencyCode;
  @override
  @JsonKey()
  final double alertThreshold;
  @override
  @JsonKey()
  final double spentAmount;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'TravelBudget(id: $id, travelEventId: $travelEventId, categoryId: $categoryId, categoryName: $categoryName, budgetAmount: $budgetAmount, budgetCurrencyCode: $budgetCurrencyCode, alertThreshold: $alertThreshold, spentAmount: $spentAmount, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TravelBudgetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.travelEventId, travelEventId) ||
                other.travelEventId == travelEventId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.budgetAmount, budgetAmount) ||
                other.budgetAmount == budgetAmount) &&
            (identical(other.budgetCurrencyCode, budgetCurrencyCode) ||
                other.budgetCurrencyCode == budgetCurrencyCode) &&
            (identical(other.alertThreshold, alertThreshold) ||
                other.alertThreshold == alertThreshold) &&
            (identical(other.spentAmount, spentAmount) ||
                other.spentAmount == spentAmount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      travelEventId,
      categoryId,
      categoryName,
      budgetAmount,
      budgetCurrencyCode,
      alertThreshold,
      spentAmount,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TravelBudgetImplCopyWith<_$TravelBudgetImpl> get copyWith =>
      __$$TravelBudgetImplCopyWithImpl<_$TravelBudgetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TravelBudgetImplToJson(
      this,
    );
  }
}

abstract class _TravelBudget implements TravelBudget {
  const factory _TravelBudget(
      {final String? id,
      required final String travelEventId,
      required final String categoryId,
      required final String categoryName,
      required final double budgetAmount,
      final String? budgetCurrencyCode,
      final double alertThreshold,
      final double spentAmount,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$TravelBudgetImpl;

  factory _TravelBudget.fromJson(Map<String, dynamic> json) =
      _$TravelBudgetImpl.fromJson;

  @override
  String? get id;
  @override
  String get travelEventId;
  @override
  String get categoryId;
  @override
  String get categoryName;
  @override
  double get budgetAmount;
  @override
  String? get budgetCurrencyCode;
  @override
  double get alertThreshold;
  @override
  double get spentAmount;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$TravelBudgetImplCopyWith<_$TravelBudgetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
