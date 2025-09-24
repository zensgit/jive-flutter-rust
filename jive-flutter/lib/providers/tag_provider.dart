import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/tag.dart';
import 'package:jive_money/services/storage_service.dart';

/// 标签状态管理 - 基于Riverpod
class TagNotifier extends StateNotifier<List<Tag>> {
  final _storage = StorageService();

  TagNotifier() : super([]) {
    _loadTags();
  }

  void _loadTags() async {
    try {
      // 从存储加载标签
      final tagData = await _storage.getTags();
      if (tagData.isNotEmpty) {
        final tags = tagData.map((json) => Tag.fromJson(json)).toList();
        state = tags;
        return;
      }
    } catch (e) {
      debugPrint('从存储加载标签失败: $e');
    }

    // 如果存储中没有数据，使用示例数据并保存
    final defaultTags = [
      Tag(
        id: '1',
        name: '工作',
        color: TagColors.colors[0],
        groupId: 'work',
        usageCount: 15,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Tag(
        id: '2',
        name: '旅行',
        color: TagColors.colors[1],
        groupId: 'lifestyle',
        usageCount: 8,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      Tag(
        id: '3',
        name: '礼物',
        color: TagColors.colors[2],
        groupId: 'personal',
        usageCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Tag(
        id: '4',
        name: '紧急',
        color: TagColors.colors[3],
        groupId: 'priority',
        usageCount: 2,
        archived: true,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];

    state = defaultTags;
    _saveTags(); // 保存默认数据到存储
  }

  /// 保存标签到存储
  Future<void> _saveTags() async {
    try {
      final tagData = state.map((tag) => tag.toJson()).toList();
      await _storage.saveTags(tagData);
    } catch (e) {
      debugPrint('保存标签到存储失败: $e');
    }
  }

  /// 添加标签
  Future<void> addTag(Tag tag) async {
    final newTag = tag.copyWith(
      id: tag.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: tag.createdAt ?? DateTime.now(),
      updatedAt: tag.updatedAt ?? DateTime.now(),
    );

    state = [...state, newTag];
    await _saveTags();
  }

  /// 更新标签
  Future<void> updateTag(Tag updatedTag) async {
    state = state.map((tag) {
      if (tag.id == updatedTag.id) {
        return updatedTag.copyWith(updatedAt: DateTime.now());
      }
      return tag;
    }).toList();
    await _saveTags();
  }

  /// 删除标签
  Future<void> deleteTag(String tagId) async {
    state = state.where((tag) => tag.id != tagId).toList();
    await _saveTags();
  }

  /// 归档标签
  Future<void> archiveTag(String tagId, bool archived) async {
    state = state.map((tag) {
      if (tag.id == tagId) {
        return tag.copyWith(
          archived: archived,
          updatedAt: DateTime.now(),
        );
      }
      return tag;
    }).toList();
    await _saveTags();
  }

  /// 更新标签使用次数
  Future<void> incrementUsageCount(String tagId) async {
    state = state.map((tag) {
      if (tag.id == tagId) {
        return tag.copyWith(
          usageCount: tag.usageCount + 1,
          lastUsedAt: DateTime.now(),
        );
      }
      return tag;
    }).toList();
    await _saveTags();
  }

  /// 重新排序标签
  Future<void> reorderTags(List<Tag> reorderedTags) async {
    final updatedTags = <Tag>[];
    for (int i = 0; i < reorderedTags.length; i++) {
      updatedTags.add(reorderedTags[i].copyWith(
        position: i,
        updatedAt: DateTime.now(),
      ));
    }
    state = updatedTags;
    await _saveTags();
  }
}

/// 标签组状态管理
class TagGroupNotifier extends StateNotifier<List<TagGroup>> {
  final _storage = StorageService();

  TagGroupNotifier() : super([]) {
    _loadTagGroups();
  }

  void _loadTagGroups() async {
    try {
      // 从存储加载标签组
      final groupData = await _storage.getTagGroups();
      if (groupData.isNotEmpty) {
        final groups =
            groupData.map((json) => TagGroup.fromJson(json)).toList();
        state = groups;
        return;
      }
    } catch (e) {
      debugPrint('从存储加载标签组失败: $e');
    }

    // 如果存储中没有数据，使用示例数据并保存
    final defaultGroups = [
      TagGroup(
        id: 'work',
        name: '工作相关',
        color: TagColors.colors[0],
        icon: 'work',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      TagGroup(
        id: 'lifestyle',
        name: '生活方式',
        color: TagColors.colors[1],
        icon: 'lifestyle',
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      TagGroup(
        id: 'personal',
        name: '个人',
        color: TagColors.colors[2],
        icon: 'person',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      TagGroup(
        id: 'priority',
        name: '优先级',
        color: TagColors.colors[3],
        icon: 'priority',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];

    state = defaultGroups;
    _saveTagGroups(); // 保存默认数据到存储
  }

  /// 保存标签组到存储
  Future<void> _saveTagGroups() async {
    try {
      final groupData = state.map((group) => group.toJson()).toList();
      await _storage.saveTagGroups(groupData);
    } catch (e) {
      debugPrint('保存标签组到存储失败: $e');
    }
  }

  /// 添加标签组
  Future<void> addTagGroup(TagGroup group) async {
    final newGroup = group.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = [...state, newGroup];
    await _saveTagGroups();
  }

  /// 更新标签组
  Future<void> updateTagGroup(TagGroup updatedGroup) async {
    state = state.map((group) {
      if (group.id == updatedGroup.id) {
        return updatedGroup.copyWith(updatedAt: DateTime.now());
      }
      return group;
    }).toList();
    await _saveTagGroups();
  }

  /// 删除标签组
  Future<void> deleteTagGroup(String groupId) async {
    state = state.where((group) => group.id != groupId).toList();
    await _saveTagGroups();
  }

  /// 归档标签组
  Future<void> archiveTagGroup(String groupId, bool archived) async {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(
          archived: archived,
          updatedAt: DateTime.now(),
        );
      }
      return group;
    }).toList();
    await _saveTagGroups();
  }
}

/// 标签Provider
final tagsProvider = StateNotifierProvider<TagNotifier, List<Tag>>((ref) {
  return TagNotifier();
});

/// 标签组Provider
final tagGroupsProvider =
    StateNotifierProvider<TagGroupNotifier, List<TagGroup>>((ref) {
  return TagGroupNotifier();
});

/// 活跃标签Provider（未归档）
final activeTagsProvider = Provider<List<Tag>>((ref) {
  final tags = ref.watch(tagsProvider);
  return tags.where((tag) => !tag.archived).toList();
});

/// 归档标签Provider
final archivedTagsProvider = Provider<List<Tag>>((ref) {
  final tags = ref.watch(tagsProvider);
  return tags.where((tag) => tag.archived).toList();
});

/// 按组分类的标签Provider
final tagsByGroupProvider = Provider.family<List<Tag>, String>((ref, groupId) {
  final tags = ref.watch(tagsProvider);
  return tags.where((tag) => tag.groupId == groupId).toList();
});

/// 常用标签Provider（按使用次数排序）
final popularTagsProvider = Provider<List<Tag>>((ref) {
  final tags = ref.watch(activeTagsProvider);
  final sortedTags = [...tags];
  sortedTags.sort((a, b) => b.usageCount.compareTo(a.usageCount));
  return sortedTags.take(10).toList();
});

/// 最近使用的标签Provider
final recentTagsProvider = Provider<List<Tag>>((ref) {
  final tags = ref.watch(activeTagsProvider);
  final recentTags = tags.where((tag) => tag.lastUsedAt != null).toList();
  recentTags.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
  return recentTags.take(5).toList();
});
