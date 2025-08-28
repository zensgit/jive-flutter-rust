import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';

/// 标签状态管理 - 基于Riverpod
class TagNotifier extends StateNotifier<List<Tag>> {
  TagNotifier() : super([]) {
    _loadTags();
  }

  void _loadTags() {
    // TODO: 从存储加载标签，目前使用示例数据
    state = [
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
  }

  /// 添加标签
  void addTag(Tag tag) {
    final newTag = tag.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = [...state, newTag];
    // TODO: 保存到存储
  }

  /// 更新标签
  void updateTag(Tag updatedTag) {
    state = state.map((tag) {
      if (tag.id == updatedTag.id) {
        return updatedTag.copyWith(updatedAt: DateTime.now());
      }
      return tag;
    }).toList();
    // TODO: 保存到存储
  }

  /// 删除标签
  void deleteTag(String tagId) {
    state = state.where((tag) => tag.id != tagId).toList();
    // TODO: 保存到存储
  }

  /// 归档标签
  void archiveTag(String tagId, bool archived) {
    state = state.map((tag) {
      if (tag.id == tagId) {
        return tag.copyWith(
          archived: archived,
          updatedAt: DateTime.now(),
        );
      }
      return tag;
    }).toList();
    // TODO: 保存到存储
  }

  /// 更新标签使用次数
  void incrementUsageCount(String tagId) {
    state = state.map((tag) {
      if (tag.id == tagId) {
        return tag.copyWith(
          usageCount: tag.usageCount + 1,
          lastUsedAt: DateTime.now(),
        );
      }
      return tag;
    }).toList();
    // TODO: 保存到存储
  }

  /// 重新排序标签
  void reorderTags(List<Tag> reorderedTags) {
    final updatedTags = <Tag>[];
    for (int i = 0; i < reorderedTags.length; i++) {
      updatedTags.add(reorderedTags[i].copyWith(
        position: i,
        updatedAt: DateTime.now(),
      ));
    }
    state = updatedTags;
    // TODO: 保存到存储
  }
}

/// 标签组状态管理
class TagGroupNotifier extends StateNotifier<List<TagGroup>> {
  TagGroupNotifier() : super([]) {
    _loadTagGroups();
  }

  void _loadTagGroups() {
    // TODO: 从存储加载标签组，目前使用示例数据
    state = [
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
  }

  /// 添加标签组
  void addTagGroup(TagGroup group) {
    final newGroup = group.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = [...state, newGroup];
    // TODO: 保存到存储
  }

  /// 更新标签组
  void updateTagGroup(TagGroup updatedGroup) {
    state = state.map((group) {
      if (group.id == updatedGroup.id) {
        return updatedGroup.copyWith(updatedAt: DateTime.now());
      }
      return group;
    }).toList();
    // TODO: 保存到存储
  }

  /// 删除标签组
  void deleteTagGroup(String groupId) {
    state = state.where((group) => group.id != groupId).toList();
    // TODO: 保存到存储，同时处理该组下的标签
  }

  /// 归档标签组
  void archiveTagGroup(String groupId, bool archived) {
    state = state.map((group) {
      if (group.id == groupId) {
        return group.copyWith(
          archived: archived,
          updatedAt: DateTime.now(),
        );
      }
      return group;
    }).toList();
    // TODO: 保存到存储
  }
}

/// 标签Provider
final tagsProvider = StateNotifierProvider<TagNotifier, List<Tag>>((ref) {
  return TagNotifier();
});

/// 标签组Provider
final tagGroupsProvider = StateNotifierProvider<TagGroupNotifier, List<TagGroup>>((ref) {
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