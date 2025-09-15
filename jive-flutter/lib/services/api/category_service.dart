import '../../core/network/http_client.dart';
import '../../core/config/api_config.dart';
import '../../models/category.dart';

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
        throw Exception('Failed to fetch categories: ${response.statusMessage}');
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
        queryParams['classification'] = classification.toString().split('.').last;
      }
      if (featuredOnly == true) queryParams['featured'] = 'true';

      final response = await _client.get(
        '${ApiConfig.apiUrl}/category-templates',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? response.data;
        return data.map((json) => SystemCategoryTemplate.fromJson(json)).toList();
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
        throw Exception('Failed to import templates: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to import templates: $e');
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
        throw Exception('Failed to batch recategorize: ${response.statusMessage}');
      }
    } catch (e) {
      throw Exception('Failed to batch recategorize: $e');
    }
  }
}

/// 导入结果
class ImportResult {
  final int imported;
  final int skipped;
  final int failed;
  final List<Category> categories;

  ImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.categories,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      imported: json['imported'] ?? 0,
      skipped: json['skipped'] ?? 0,
      failed: json['failed'] ?? 0,
      categories: (json['categories'] as List?)
          ?.map((e) => Category.fromJson(e))
          .toList() ?? [],
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

/// 系统分类模板
class SystemCategoryTemplate {
  final String id;
  final String name;
  final String? nameEn;
  final String? description;
  final CategoryClassification classification;
  final String color;
  final String? icon;
  final String? group;
  final bool isFeatured;
  final List<String> tags;

  SystemCategoryTemplate({
    required this.id,
    required this.name,
    this.nameEn,
    this.description,
    required this.classification,
    required this.color,
    this.icon,
    this.group,
    this.isFeatured = false,
    this.tags = const [],
  });

  factory SystemCategoryTemplate.fromJson(Map<String, dynamic> json) {
    return SystemCategoryTemplate(
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      description: json['description'],
      classification: CategoryClassification.values.firstWhere(
        (e) => e.toString().split('.').last == json['classification'],
        orElse: () => CategoryClassification.expense,
      ),
      color: json['color'],
      icon: json['icon'],
      group: json['group'],
      isFeatured: json['is_featured'] ?? false,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }
}
