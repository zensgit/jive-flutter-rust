// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'travel_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TravelEventImpl _$$TravelEventImplFromJson(Map<String, dynamic> json) =>
    _$TravelEventImpl(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      destination: json['destination'] as String?,
      currency: json['currency'] as String? ?? 'CNY',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      location: json['location'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      autoTag: json['autoTag'] as bool? ?? false,
      travelCategoryIds: (json['travelCategoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      ledgerId: json['ledgerId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      travelTagId: json['travelTagId'] as String?,
    );

Map<String, dynamic> _$$TravelEventImplToJson(_$TravelEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'destination': instance.destination,
      'currency': instance.currency,
      'budget': instance.budget,
      'totalSpent': instance.totalSpent,
      'notes': instance.notes,
      'location': instance.location,
      'isActive': instance.isActive,
      'autoTag': instance.autoTag,
      'travelCategoryIds': instance.travelCategoryIds,
      'ledgerId': instance.ledgerId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'transactionCount': instance.transactionCount,
      'totalAmount': instance.totalAmount,
      'travelTagId': instance.travelTagId,
    };

_$TravelEventTemplateImpl _$$TravelEventTemplateImplFromJson(
        Map<String, dynamic> json) =>
    _$TravelEventTemplateImpl(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      templateType:
          $enumDecode(_$TravelTemplateTypeEnumMap, json['templateType']),
      categoryIds: (json['categoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isSystemTemplate: json['isSystemTemplate'] as bool? ?? false,
      ledgerId: json['ledgerId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$TravelEventTemplateImplToJson(
        _$TravelEventTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'templateType': _$TravelTemplateTypeEnumMap[instance.templateType]!,
      'categoryIds': instance.categoryIds,
      'isSystemTemplate': instance.isSystemTemplate,
      'ledgerId': instance.ledgerId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$TravelTemplateTypeEnumMap = {
  TravelTemplateType.inclusion: 'inclusion',
  TravelTemplateType.exclusion: 'exclusion',
};
