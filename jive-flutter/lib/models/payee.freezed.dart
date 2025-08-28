// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payee.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Payee _$PayeeFromJson(Map<String, dynamic> json) {
  return _Payee.fromJson(json);
}

/// @nodoc
mixin _$Payee {
  String? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get color => throw _privateConstructorUsedError;
  PayeeType? get payeeType => throw _privateConstructorUsedError;
  PayeeSource? get source => throw _privateConstructorUsedError;
  String? get logo => throw _privateConstructorUsedError;
  String? get website => throw _privateConstructorUsedError;
  int get transactionsCount => throw _privateConstructorUsedError;
  int? get position => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError; // 分类关联
  List<String> get categoryIds => throw _privateConstructorUsedError;
  String? get primaryCategoryId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PayeeCopyWith<Payee> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayeeCopyWith<$Res> {
  factory $PayeeCopyWith(Payee value, $Res Function(Payee) then) =
      _$PayeeCopyWithImpl<$Res, Payee>;
  @useResult
  $Res call(
      {String? id,
      String name,
      String? color,
      PayeeType? payeeType,
      PayeeSource? source,
      String? logo,
      String? website,
      int transactionsCount,
      int? position,
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> categoryIds,
      String? primaryCategoryId});
}

/// @nodoc
class _$PayeeCopyWithImpl<$Res, $Val extends Payee>
    implements $PayeeCopyWith<$Res> {
  _$PayeeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? color = freezed,
    Object? payeeType = freezed,
    Object? source = freezed,
    Object? logo = freezed,
    Object? website = freezed,
    Object? transactionsCount = null,
    Object? position = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? categoryIds = null,
    Object? primaryCategoryId = freezed,
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
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      payeeType: freezed == payeeType
          ? _value.payeeType
          : payeeType // ignore: cast_nullable_to_non_nullable
              as PayeeType?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as PayeeSource?,
      logo: freezed == logo
          ? _value.logo
          : logo // ignore: cast_nullable_to_non_nullable
              as String?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      transactionsCount: null == transactionsCount
          ? _value.transactionsCount
          : transactionsCount // ignore: cast_nullable_to_non_nullable
              as int,
      position: freezed == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryIds: null == categoryIds
          ? _value.categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      primaryCategoryId: freezed == primaryCategoryId
          ? _value.primaryCategoryId
          : primaryCategoryId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PayeeImplCopyWith<$Res> implements $PayeeCopyWith<$Res> {
  factory _$$PayeeImplCopyWith(
          _$PayeeImpl value, $Res Function(_$PayeeImpl) then) =
      __$$PayeeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String name,
      String? color,
      PayeeType? payeeType,
      PayeeSource? source,
      String? logo,
      String? website,
      int transactionsCount,
      int? position,
      DateTime? createdAt,
      DateTime? updatedAt,
      List<String> categoryIds,
      String? primaryCategoryId});
}

/// @nodoc
class __$$PayeeImplCopyWithImpl<$Res>
    extends _$PayeeCopyWithImpl<$Res, _$PayeeImpl>
    implements _$$PayeeImplCopyWith<$Res> {
  __$$PayeeImplCopyWithImpl(
      _$PayeeImpl _value, $Res Function(_$PayeeImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? color = freezed,
    Object? payeeType = freezed,
    Object? source = freezed,
    Object? logo = freezed,
    Object? website = freezed,
    Object? transactionsCount = null,
    Object? position = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? categoryIds = null,
    Object? primaryCategoryId = freezed,
  }) {
    return _then(_$PayeeImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      color: freezed == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String?,
      payeeType: freezed == payeeType
          ? _value.payeeType
          : payeeType // ignore: cast_nullable_to_non_nullable
              as PayeeType?,
      source: freezed == source
          ? _value.source
          : source // ignore: cast_nullable_to_non_nullable
              as PayeeSource?,
      logo: freezed == logo
          ? _value.logo
          : logo // ignore: cast_nullable_to_non_nullable
              as String?,
      website: freezed == website
          ? _value.website
          : website // ignore: cast_nullable_to_non_nullable
              as String?,
      transactionsCount: null == transactionsCount
          ? _value.transactionsCount
          : transactionsCount // ignore: cast_nullable_to_non_nullable
              as int,
      position: freezed == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryIds: null == categoryIds
          ? _value._categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      primaryCategoryId: freezed == primaryCategoryId
          ? _value.primaryCategoryId
          : primaryCategoryId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PayeeImpl implements _Payee {
  const _$PayeeImpl(
      {this.id,
      required this.name,
      this.color,
      this.payeeType,
      this.source,
      this.logo,
      this.website,
      this.transactionsCount = 0,
      this.position,
      this.createdAt,
      this.updatedAt,
      final List<String> categoryIds = const [],
      this.primaryCategoryId})
      : _categoryIds = categoryIds;

  factory _$PayeeImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayeeImplFromJson(json);

  @override
  final String? id;
  @override
  final String name;
  @override
  final String? color;
  @override
  final PayeeType? payeeType;
  @override
  final PayeeSource? source;
  @override
  final String? logo;
  @override
  final String? website;
  @override
  @JsonKey()
  final int transactionsCount;
  @override
  final int? position;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
// 分类关联
  final List<String> _categoryIds;
// 分类关联
  @override
  @JsonKey()
  List<String> get categoryIds {
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categoryIds);
  }

  @override
  final String? primaryCategoryId;

  @override
  String toString() {
    return 'Payee(id: $id, name: $name, color: $color, payeeType: $payeeType, source: $source, logo: $logo, website: $website, transactionsCount: $transactionsCount, position: $position, createdAt: $createdAt, updatedAt: $updatedAt, categoryIds: $categoryIds, primaryCategoryId: $primaryCategoryId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayeeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.payeeType, payeeType) ||
                other.payeeType == payeeType) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.logo, logo) || other.logo == logo) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.transactionsCount, transactionsCount) ||
                other.transactionsCount == transactionsCount) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality()
                .equals(other._categoryIds, _categoryIds) &&
            (identical(other.primaryCategoryId, primaryCategoryId) ||
                other.primaryCategoryId == primaryCategoryId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      color,
      payeeType,
      source,
      logo,
      website,
      transactionsCount,
      position,
      createdAt,
      updatedAt,
      const DeepCollectionEquality().hash(_categoryIds),
      primaryCategoryId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PayeeImplCopyWith<_$PayeeImpl> get copyWith =>
      __$$PayeeImplCopyWithImpl<_$PayeeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayeeImplToJson(
      this,
    );
  }
}

abstract class _Payee implements Payee {
  const factory _Payee(
      {final String? id,
      required final String name,
      final String? color,
      final PayeeType? payeeType,
      final PayeeSource? source,
      final String? logo,
      final String? website,
      final int transactionsCount,
      final int? position,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final List<String> categoryIds,
      final String? primaryCategoryId}) = _$PayeeImpl;

  factory _Payee.fromJson(Map<String, dynamic> json) = _$PayeeImpl.fromJson;

  @override
  String? get id;
  @override
  String get name;
  @override
  String? get color;
  @override
  PayeeType? get payeeType;
  @override
  PayeeSource? get source;
  @override
  String? get logo;
  @override
  String? get website;
  @override
  int get transactionsCount;
  @override
  int? get position;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override // 分类关联
  List<String> get categoryIds;
  @override
  String? get primaryCategoryId;
  @override
  @JsonKey(ignore: true)
  _$$PayeeImplCopyWith<_$PayeeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PayeeCategory _$PayeeCategoryFromJson(Map<String, dynamic> json) {
  return _PayeeCategory.fromJson(json);
}

/// @nodoc
mixin _$PayeeCategory {
  String? get id => throw _privateConstructorUsedError;
  String get payeeId => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  int get usageCount => throw _privateConstructorUsedError;
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PayeeCategoryCopyWith<PayeeCategory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayeeCategoryCopyWith<$Res> {
  factory $PayeeCategoryCopyWith(
          PayeeCategory value, $Res Function(PayeeCategory) then) =
      _$PayeeCategoryCopyWithImpl<$Res, PayeeCategory>;
  @useResult
  $Res call(
      {String? id,
      String payeeId,
      String categoryId,
      int usageCount,
      DateTime? lastUsedAt});
}

/// @nodoc
class _$PayeeCategoryCopyWithImpl<$Res, $Val extends PayeeCategory>
    implements $PayeeCategoryCopyWith<$Res> {
  _$PayeeCategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? payeeId = null,
    Object? categoryId = null,
    Object? usageCount = null,
    Object? lastUsedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      payeeId: null == payeeId
          ? _value.payeeId
          : payeeId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      usageCount: null == usageCount
          ? _value.usageCount
          : usageCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PayeeCategoryImplCopyWith<$Res>
    implements $PayeeCategoryCopyWith<$Res> {
  factory _$$PayeeCategoryImplCopyWith(
          _$PayeeCategoryImpl value, $Res Function(_$PayeeCategoryImpl) then) =
      __$$PayeeCategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? id,
      String payeeId,
      String categoryId,
      int usageCount,
      DateTime? lastUsedAt});
}

/// @nodoc
class __$$PayeeCategoryImplCopyWithImpl<$Res>
    extends _$PayeeCategoryCopyWithImpl<$Res, _$PayeeCategoryImpl>
    implements _$$PayeeCategoryImplCopyWith<$Res> {
  __$$PayeeCategoryImplCopyWithImpl(
      _$PayeeCategoryImpl _value, $Res Function(_$PayeeCategoryImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? payeeId = null,
    Object? categoryId = null,
    Object? usageCount = null,
    Object? lastUsedAt = freezed,
  }) {
    return _then(_$PayeeCategoryImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      payeeId: null == payeeId
          ? _value.payeeId
          : payeeId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      usageCount: null == usageCount
          ? _value.usageCount
          : usageCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PayeeCategoryImpl implements _PayeeCategory {
  const _$PayeeCategoryImpl(
      {this.id,
      required this.payeeId,
      required this.categoryId,
      this.usageCount = 0,
      this.lastUsedAt});

  factory _$PayeeCategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayeeCategoryImplFromJson(json);

  @override
  final String? id;
  @override
  final String payeeId;
  @override
  final String categoryId;
  @override
  @JsonKey()
  final int usageCount;
  @override
  final DateTime? lastUsedAt;

  @override
  String toString() {
    return 'PayeeCategory(id: $id, payeeId: $payeeId, categoryId: $categoryId, usageCount: $usageCount, lastUsedAt: $lastUsedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayeeCategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.payeeId, payeeId) || other.payeeId == payeeId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.usageCount, usageCount) ||
                other.usageCount == usageCount) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, payeeId, categoryId, usageCount, lastUsedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PayeeCategoryImplCopyWith<_$PayeeCategoryImpl> get copyWith =>
      __$$PayeeCategoryImplCopyWithImpl<_$PayeeCategoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayeeCategoryImplToJson(
      this,
    );
  }
}

abstract class _PayeeCategory implements PayeeCategory {
  const factory _PayeeCategory(
      {final String? id,
      required final String payeeId,
      required final String categoryId,
      final int usageCount,
      final DateTime? lastUsedAt}) = _$PayeeCategoryImpl;

  factory _PayeeCategory.fromJson(Map<String, dynamic> json) =
      _$PayeeCategoryImpl.fromJson;

  @override
  String? get id;
  @override
  String get payeeId;
  @override
  String get categoryId;
  @override
  int get usageCount;
  @override
  DateTime? get lastUsedAt;
  @override
  @JsonKey(ignore: true)
  _$$PayeeCategoryImplCopyWith<_$PayeeCategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
