// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      id: json['id'] as String?,
      name: json['name'] as String,
      nameEn: json['nameEn'] as String?,
      color: json['color'] as String,
      icon: json['icon'] as String,
      classification:
          $enumDecode(_$CategoryClassificationEnumMap, json['classification']),
      parentId: json['parentId'] as String?,
      ledgerId: json['ledgerId'] as String?,
      position: (json['position'] as num?)?.toInt(),
      usageCount: (json['usageCount'] as num?)?.toInt(),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      subcategories: (json['subcategories'] as List<dynamic>?)
              ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nameEn': instance.nameEn,
      'color': instance.color,
      'icon': instance.icon,
      'classification':
          _$CategoryClassificationEnumMap[instance.classification]!,
      'parentId': instance.parentId,
      'ledgerId': instance.ledgerId,
      'position': instance.position,
      'usageCount': instance.usageCount,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'subcategories': instance.subcategories,
    };

const _$CategoryClassificationEnumMap = {
  CategoryClassification.income: 'income',
  CategoryClassification.expense: 'expense',
  CategoryClassification.transfer: 'transfer',
};
