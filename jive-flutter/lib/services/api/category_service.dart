import 'dart:convert';
import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/category.dart';
import '../../models/category_template.dart';

/// 分类API服务
class CategoryService {
  final HttpClient _client;

  CategoryService({HttpClient? client})
      : _client = client ?? HttpClient.instance;

  /// 获取分类列表
  Future<List<Category>> getCategories(String ledgerId) async {
    try {
      final response = await _client.get(
        '${ApiConfig.apiUrl}/categories',
        queryParameters: {'ledger_id': ledgerId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to fetch categories: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 创建分类
  Future<Category> createCategory({
    required String ledgerId,
    required String name,
    required CategoryClassification classification,
    required String color,
    String? icon,
    String? parentId,
    String? description,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConfig.apiUrl}/categories',
        data: {
          'ledger_id': ledgerId,
          'name': name,
          'classification': classification.toString().split('.').last,
          'color': color,
          if (icon != null) 'icon': icon,
          if (parentId != null) 'parent_id': parentId,
          if (description != null) 'description': description,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Category.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to create category: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// 更新分类
  Future<Category> updateCategory(
    String categoryId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client.put(
        '${ApiConfig.apiUrl}/categories/$categoryId',
        data: updates,
      );

      if (response.statusCode == 200) {
        return Category.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to update category: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// 删除分类
  Future<void> deleteCategory(String categoryId, {bool force = false}) async {
    try {
      final response = await _client.delete(
        '${ApiConfig.apiUrl}/categories/$categoryId',
        queryParameters: force ? {'force': 'true'} : null,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete category: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  /// 获取所有系统分类模板
  Future<List<SystemCategoryTemplate>> getAllTemplates({
    bool forceRefresh = false,
  }) async {
    return getSystemTemplates();
  }

  /// 获取系统分类模板
  Future<List<SystemCategoryTemplate>> getSystemTemplates({
    String? group,
    CategoryClassification? classification,
    bool? featuredOnly,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (group != null) queryParams['group'] = group;
      if (classification != null) {
        queryParams['classification'] =
            classification.toString().split('.').last;
      }
      if (featuredOnly == true) queryParams['featured'] = 'true';

      final response = await _client.get(
        '${ApiConfig.apiUrl}/category-templates',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data
            .map((json) => SystemCategoryTemplate.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to fetch templates: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to fetch templates: $e');
    }
  }

  /// 从模板导入分类
  Future<ImportResult> importFromTemplates({
    required String ledgerId,
    required List<String> templateIds,
    Map<String, String>? customizations,
    bool skipExisting = true,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConfig.apiUrl}/categories/import',
        data: {
          'ledger_id': ledgerId,
          'template_ids': templateIds,
          'options': {
            'skip_existing': skipExisting,
            if (customizations != null) 'customize': customizations,
          },
        },
      );

      if (response.statusCode == 200) {
        return ImportResult.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to import templates: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to import templates: $e');
    }
  }

  /// 批量从模板导入（高级：支持 per-item overrides 与冲突策略）
  Future<ImportResult> importTemplatesAdvanced({
    required String ledgerId,
    required List<Map<String, dynamic>> items,
    String onConflict = 'skip', // skip|rename|update
    bool dryRun = false,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConfig.apiUrl}/categories/import',
        data: {
          'ledger_id': ledgerId,
          'items': items,
          'on_conflict': onConflict,
          'dry_run': dryRun,
        },
      );

      if (response.statusCode == 200) {
        return ImportResult.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to import templates (advanced): ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to import templates (advanced): $e');
    }
  }

  /// 移动分类（调整层级或位置）
  Future<Category> moveCategory(
    String categoryId, {
    String? newParentId,
    int? position,
  }) async {
    try {
      final response = await _client.put(
        '${ApiConfig.apiUrl}/categories/$categoryId/move',
        data: {
          if (newParentId != null) 'parent_id': newParentId,
          if (position != null) 'position': position,
        },
      );

      if (response.statusCode == 200) {
        return Category.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception('Failed to move category: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to move category: $e');
    }
  }

  /// 分类转为标签
  Future<ConversionResult> convertToTag(
    String categoryId, {
    String? tagName,
    bool applyToTransactions = true,
    bool deleteCategory = false,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConfig.apiUrl}/categories/$categoryId/convert-to-tag',
        data: {
          if (tagName != null) 'tag_name': tagName,
          'apply_to_transactions': applyToTransactions,
          'delete_category': deleteCategory,
        },
      );

      if (response.statusCode == 200) {
        return ConversionResult.fromJson(response.data);
      } else {
        throw Exception('Failed to convert to tag: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to convert to tag: $e');
    }
  }

  /// 批量重分类
  Future<BatchOperationResult> batchRecategorize({
    required List<String> transactionIds,
    required String targetCategoryId,
    String? addTag,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConfig.apiUrl}/transactions/batch-recategorize',
        data: {
          'transaction_ids': transactionIds,
          'target_category_id': targetCategoryId,
          if (addTag != null) 'add_tag': addTag,
          'create_batch_record': true,
        },
      );

      if (response.statusCode == 200) {
        return BatchOperationResult.fromJson(response.data);
      } else {
        throw Exception(
            'Failed to batch recategorize: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to batch recategorize: $e');
    }
  }

  /// 带 ETag 与分页的模板获取（与后端 /api/v1/templates/list 对齐）
  Future<TemplateCatalogResult> getTemplatesWithEtag({
    String? etag,
    int page = 1,
    int perPage = 50,
    String? group,
    CategoryClassification? classification,
    bool? featuredOnly,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        if (group != null) 'group': group,
        if (classification != null)
          'type': classification.toString().split('.').last,
        if (featuredOnly != null) 'featured': featuredOnly,
        if (etag != null && etag.isNotEmpty) 'etag': etag,
      };
      final resp = await _client.get(
        '${ApiConfig.apiUrl}/templates/list',
        queryParameters: qp,
      );

      if (resp.statusCode == 304) {
        return TemplateCatalogResult(const [], etag, true, 0, page, perPage);
      }
      if (resp.statusCode == 200) {
        final data = resp.data is Map ? resp.data as Map<String, dynamic> : jsonDecode(resp.data as String) as Map<String, dynamic>;
        final List<dynamic> itemsJson = data['templates'] ?? [];
        final items = itemsJson.map((e) => SystemCategoryTemplate.fromJson(Map<String, dynamic>.from(e))).toList();
        final total = (data['total'] as num?)?.toInt() ?? items.length;
        final lastUpdated = data['last_updated']?.toString();
        final newEtag = _computeWeakEtag(lastUpdated, total);
        return TemplateCatalogResult(items, newEtag, false, total, page, perPage);
      }
      throw Exception('Failed to load templates: ${resp.statusCode}');
    } catch (e) {
      // 网络失败时返回 notModified=false 且 items 为空，交由调用方决定回退策略
      return TemplateCatalogResult(const [], etag, false, 0, page, perPage, error: e.toString());
    }
  }

  String? _computeWeakEtag(String? lastUpdatedIso, int total) {
    if (lastUpdatedIso == null) return null;
    try {
      final dt = DateTime.parse(lastUpdatedIso).toUtc();
      final ts = (dt.millisecondsSinceEpoch / 1000).floor();
      return 'W/"$ts:$total"';
    } catch (_) {
      return null;
    }
  }

  // Stub methods for template management - TODO: Implement with actual API
  Future<dynamic> createTemplate(dynamic template) async {
    // Stub implementation
    return Future.value({'id': 'stub', 'status': 'created'});
  }

  Future<dynamic> updateTemplate(String id, dynamic updates) async {
    // Stub implementation
    return Future.value({'id': id, 'status': 'updated'});
  }

  Future<void> deleteTemplate(String id) async {
    // Stub implementation
    return Future.value();
  }

  // Import template as category - stub implementation
  Future<dynamic> importTemplateAsCategory(String templateId) async {
    // TODO: Implement actual import logic
    return Future.value({
      'id': 'imported-$templateId',
      'status': 'imported',
      'message': 'Template imported successfully'
    });
  }
}

/// 模板目录结果（含 ETag）
class TemplateCatalogResult {
  final List<SystemCategoryTemplate> items;
  final String? etag;
  final bool notModified;
  final int total;
  final int page;
  final int perPage;
  final String? error;

  const TemplateCatalogResult(
    this.items,
    this.etag,
    this.notModified,
    this.total,
    this.page,
    this.perPage, {
    this.error,
  });
}

/// 导入结果
class ImportResult {
  final int imported;
  final int skipped;
  final int failed;
  final List<Category> categories;
  final List<ImportActionDetail> details;

  ImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.categories,
    required this.details,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      imported: json['imported'] ?? 0,
      skipped: json['skipped'] ?? 0,
      failed: json['failed'] ?? 0,
      categories: (json['categories'] as List?)
              ?.map((e) => Category.fromJson(e))
              .toList() ??
          [],
      details: (json['details'] as List?)
              ?.map((e) => ImportActionDetail.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ImportActionDetail {
  final String templateId;
  final String action; // imported|updated|renamed|skipped|failed
  final String originalName;
  final String? finalName;
  final String? categoryId;
  final String? reason;
  // Enriched preview fields (server-provided)
  final String? predictedName; // from predicted_name
  final String? existingCategoryId; // from existing_category_id
  final String? existingCategoryName; // from existing_category_name
  final String? finalClassification; // from final_classification
  final String? finalParentId; // from final_parent_id

  ImportActionDetail({
    required this.templateId,
    required this.action,
    required this.originalName,
    this.finalName,
    this.categoryId,
    this.reason,
    this.predictedName,
    this.existingCategoryId,
    this.existingCategoryName,
    this.finalClassification,
    this.finalParentId,
  });

  factory ImportActionDetail.fromJson(Map<String, dynamic> json) {
    return ImportActionDetail(
      templateId: json['template_id']?.toString() ?? '',
      action: json['action']?.toString() ?? 'unknown',
      originalName: json['original_name']?.toString() ?? '',
      finalName: json['final_name']?.toString(),
      categoryId: json['category_id']?.toString(),
      reason: json['reason']?.toString(),
      predictedName: json['predicted_name']?.toString(),
      existingCategoryId: json['existing_category_id']?.toString(),
      existingCategoryName: json['existing_category_name']?.toString(),
      finalClassification: json['final_classification']?.toString(),
      finalParentId: json['final_parent_id']?.toString(),
    );
  }
}

/// 转换结果
class ConversionResult {
  final String tagId;
  final String tagName;
  final int transactionsUpdated;
  final String categoryStatus;

  ConversionResult({
    required this.tagId,
    required this.tagName,
    required this.transactionsUpdated,
    required this.categoryStatus,
  });

  factory ConversionResult.fromJson(Map<String, dynamic> json) {
    return ConversionResult(
      tagId: json['tag']['id'],
      tagName: json['tag']['name'],
      transactionsUpdated: json['transactions_updated'] ?? 0,
      categoryStatus: json['category_status'] ?? 'unknown',
    );
  }
}

/// 批量操作结果
class BatchOperationResult {
  final String batchId;
  final int affectedTransactions;
  final bool canRevert;
  final DateTime expiresAt;

  BatchOperationResult({
    required this.batchId,
    required this.affectedTransactions,
    required this.canRevert,
    required this.expiresAt,
  });

  factory BatchOperationResult.fromJson(Map<String, dynamic> json) {
    return BatchOperationResult(
      batchId: json['batch_id'],
      affectedTransactions: json['affected_transactions'] ?? 0,
      canRevert: json['can_revert'] ?? false,
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
}
