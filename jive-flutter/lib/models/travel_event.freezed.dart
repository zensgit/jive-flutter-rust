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
  bool get isActive => throw _privateConstructorUsedError;
  bool get autoTag => throw _privateConstructorUsedError;
  List<String> get travelCategoryIds => throw _privateConstructorUsedError;
  String? get ledgerId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError; // 统计信息
  int get transactionCount => throw _privateConstructorUsedError;
  double? get totalAmount => throw _privateConstructorUsedError;
  String? get travelTagId => throw _privateConstructorUsedError;

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
      bool isActive,
      bool autoTag,
      List<String> travelCategoryIds,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt,
      int transactionCount,
      double? totalAmount,
      String? travelTagId});
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
    Object? isActive = null,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? transactionCount = null,
    Object? totalAmount = freezed,
    Object? travelTagId = freezed,
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
      bool isActive,
      bool autoTag,
      List<String> travelCategoryIds,
      String? ledgerId,
      DateTime? createdAt,
      DateTime? updatedAt,
      int transactionCount,
      double? totalAmount,
      String? travelTagId});
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
    Object? isActive = null,
    Object? autoTag = null,
    Object? travelCategoryIds = null,
    Object? ledgerId = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? transactionCount = null,
    Object? totalAmount = freezed,
    Object? travelTagId = freezed,
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TravelEventImpl implements _TravelEvent {
  const _$TravelEventImpl(
      {this.id,
      required this.name,
      this.description,
      required this.startDate,
      required this.endDate,
      this.location,
      this.isActive = true,
      this.autoTag = false,
      final List<String> travelCategoryIds = const [],
      this.ledgerId,
      this.createdAt,
      this.updatedAt,
      this.transactionCount = 0,
      this.totalAmount,
      this.travelTagId})
      : _travelCategoryIds = travelCategoryIds;

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

  @override
  String toString() {
    return 'TravelEvent(id: $id, name: $name, description: $description, startDate: $startDate, endDate: $endDate, location: $location, isActive: $isActive, autoTag: $autoTag, travelCategoryIds: $travelCategoryIds, ledgerId: $ledgerId, createdAt: $createdAt, updatedAt: $updatedAt, transactionCount: $transactionCount, totalAmount: $totalAmount, travelTagId: $travelTagId)';
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
                other.travelTagId == travelTagId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      startDate,
      endDate,
      location,
      isActive,
      autoTag,
      const DeepCollectionEquality().hash(_travelCategoryIds),
      ledgerId,
      createdAt,
      updatedAt,
      transactionCount,
      totalAmount,
      travelTagId);

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

abstract class _TravelEvent implements TravelEvent {
  const factory _TravelEvent(
      {final String? id,
      required final String name,
      final String? description,
      required final DateTime startDate,
      required final DateTime endDate,
      final String? location,
      final bool isActive,
      final bool autoTag,
      final List<String> travelCategoryIds,
      final String? ledgerId,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final int transactionCount,
      final double? totalAmount,
      final String? travelTagId}) = _$TravelEventImpl;

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
