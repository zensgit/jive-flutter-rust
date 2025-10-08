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
      location: json['location'] as String?,
      destination: json['destination'] as String?,
      statusString: json['statusString'] as String? ?? 'planning',
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
      notes: json['notes'] as String?,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      travelTagId: json['travelTagId'] as String?,
      totalBudget: (json['totalBudget'] as num?)?.toDouble(),
      budget: (json['budget'] as num?)?.toDouble(),
      budgetCurrencyCode: json['budgetCurrencyCode'] as String?,
      currency: json['currency'] as String? ?? 'CNY',
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      homeCurrencyCode: json['homeCurrencyCode'] as String?,
      budgetUsagePercent: (json['budgetUsagePercent'] as num?)?.toDouble(),
      status: $enumDecodeNullable(_$TravelEventStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$$TravelEventImplToJson(_$TravelEventImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'location': instance.location,
      'destination': instance.destination,
      'statusString': instance.statusString,
      'isActive': instance.isActive,
      'autoTag': instance.autoTag,
      'travelCategoryIds': instance.travelCategoryIds,
      'ledgerId': instance.ledgerId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'notes': instance.notes,
      'transactionCount': instance.transactionCount,
      'totalAmount': instance.totalAmount,
      'travelTagId': instance.travelTagId,
      'totalBudget': instance.totalBudget,
      'budget': instance.budget,
      'budgetCurrencyCode': instance.budgetCurrencyCode,
      'currency': instance.currency,
      'totalSpent': instance.totalSpent,
      'homeCurrencyCode': instance.homeCurrencyCode,
      'budgetUsagePercent': instance.budgetUsagePercent,
      'status': _$TravelEventStatusEnumMap[instance.status],
    };

const _$TravelEventStatusEnumMap = {
  TravelEventStatus.upcoming: 'upcoming',
  TravelEventStatus.ongoing: 'ongoing',
  TravelEventStatus.completed: 'completed',
  TravelEventStatus.cancelled: 'cancelled',
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

_$CreateTravelEventInputImpl _$$CreateTravelEventInputImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateTravelEventInputImpl(
      name: json['name'] as String,
      description: json['description'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      location: json['location'] as String?,
      autoTag: json['autoTag'] as bool? ?? true,
      travelCategoryIds: (json['travelCategoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$CreateTravelEventInputImplToJson(
        _$CreateTravelEventInputImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'location': instance.location,
      'autoTag': instance.autoTag,
      'travelCategoryIds': instance.travelCategoryIds,
    };

_$UpdateTravelEventInputImpl _$$UpdateTravelEventInputImplFromJson(
        Map<String, dynamic> json) =>
    _$UpdateTravelEventInputImpl(
      name: json['name'] as String?,
      description: json['description'] as String?,
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      location: json['location'] as String?,
      autoTag: json['autoTag'] as bool?,
      travelCategoryIds: (json['travelCategoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$UpdateTravelEventInputImplToJson(
        _$UpdateTravelEventInputImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'location': instance.location,
      'autoTag': instance.autoTag,
      'travelCategoryIds': instance.travelCategoryIds,
    };

_$TravelStatisticsImpl _$$TravelStatisticsImplFromJson(
        Map<String, dynamic> json) =>
    _$TravelStatisticsImpl(
      totalSpent: (json['totalSpent'] as num).toDouble(),
      totalBudget: (json['totalBudget'] as num).toDouble(),
      budgetUsage: (json['budgetUsage'] as num).toDouble(),
      spentByCategory: (json['spentByCategory'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      spentByDay: (json['spentByDay'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      transactionCount: (json['transactionCount'] as num).toInt(),
      averagePerDay: (json['averagePerDay'] as num).toDouble(),
    );

Map<String, dynamic> _$$TravelStatisticsImplToJson(
        _$TravelStatisticsImpl instance) =>
    <String, dynamic>{
      'totalSpent': instance.totalSpent,
      'totalBudget': instance.totalBudget,
      'budgetUsage': instance.budgetUsage,
      'spentByCategory': instance.spentByCategory,
      'spentByDay': instance.spentByDay,
      'transactionCount': instance.transactionCount,
      'averagePerDay': instance.averagePerDay,
    };

_$TravelBudgetImpl _$$TravelBudgetImplFromJson(Map<String, dynamic> json) =>
    _$TravelBudgetImpl(
      id: json['id'] as String?,
      travelEventId: json['travelEventId'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      budgetAmount: (json['budgetAmount'] as num).toDouble(),
      budgetCurrencyCode: json['budgetCurrencyCode'] as String?,
      alertThreshold: (json['alertThreshold'] as num?)?.toDouble() ?? 0.8,
      spentAmount: (json['spentAmount'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$TravelBudgetImplToJson(_$TravelBudgetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'travelEventId': instance.travelEventId,
      'categoryId': instance.categoryId,
      'categoryName': instance.categoryName,
      'budgetAmount': instance.budgetAmount,
      'budgetCurrencyCode': instance.budgetCurrencyCode,
      'alertThreshold': instance.alertThreshold,
      'spentAmount': instance.spentAmount,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
