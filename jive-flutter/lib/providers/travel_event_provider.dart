import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/travel_event.dart';

/// 旅行事件状态管理
class TravelEventNotifier extends StateNotifier<List<TravelEvent>> {
  TravelEventNotifier() : super([]) {
    _loadTravelEvents();
  }

  void _loadTravelEvents() {
    // TODO: 从存储加载旅行事件，目前使用示例数据
    final now = DateTime.now();
    state = [
      TravelEvent(
        id: '1',
        name: '春节回家',
        description: '回老家过春节',
        startDate: DateTime(2025, 2, 8),
        endDate: DateTime(2025, 2, 18),
        location: '北京',
        isActive: true,
        autoTag: true,
        travelCategoryIds: [
          'transportation',
          'dining',
          'shopping',
          'entertainment'
        ],
        transactionCount: 15,
        totalAmount: 3500.0,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      TravelEvent(
        id: '2',
        name: '上海出差',
        description: '参加技术大会',
        startDate: DateTime(2025, 3, 15),
        endDate: DateTime(2025, 3, 18),
        location: '上海',
        isActive: true,
        autoTag: true,
        travelCategoryIds: ['transportation', 'accommodation', 'dining'],
        transactionCount: 8,
        totalAmount: 2200.0,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      TravelEvent(
        id: '3',
        name: '三亚度假',
        description: '全家三亚旅游',
        startDate: DateTime(2025, 5, 1),
        endDate: DateTime(2025, 5, 7),
        location: '三亚',
        isActive: false,
        autoTag: false,
        travelCategoryIds: [
          'transportation',
          'accommodation',
          'dining',
          'attractions',
          'shopping'
        ],
        transactionCount: 0,
        totalAmount: 0.0,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  /// 添加旅行事件
  void addTravelEvent(TravelEvent event) {
    final newEvent = event.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = [...state, newEvent];
    // TODO: 保存到存储，创建旅行标签，触发自动标记
  }

  /// 更新旅行事件
  void updateTravelEvent(TravelEvent updatedEvent) {
    state = state.map((event) {
      if (event.id == updatedEvent.id) {
        return updatedEvent.copyWith(updatedAt: DateTime.now());
      }
      return event;
    }).toList();
    // TODO: 保存到存储，重新执行自动标记
  }

  /// 删除旅行事件
  void deleteTravelEvent(String eventId) {
    final event = state.firstWhere((e) => e.id == eventId);
    state = state.where((event) => event.id != eventId).toList();
    // TODO: 保存到存储，移除相关旅行标签
  }

  /// 切换事件激活状态
  void toggleEventActive(String eventId, bool isActive) {
    state = state.map((event) {
      if (event.id == eventId) {
        return event.copyWith(
          isActive: isActive,
          updatedAt: DateTime.now(),
        );
      }
      return event;
    }).toList();
    // TODO: 保存到存储
  }

  /// 切换自动标记
  void toggleAutoTag(String eventId, bool autoTag) {
    state = state.map((event) {
      if (event.id == eventId) {
        return event.copyWith(
          autoTag: autoTag,
          updatedAt: DateTime.now(),
        );
      }
      return event;
    }).toList();
    // TODO: 保存到存储，重新执行自动标记
  }

  /// 执行自动标记
  void executeAutoTagging(String eventId) {
    // TODO: 实现自动标记逻辑
    // 1. 查找指定日期范围内的交易
    // 2. 根据分类设置过滤交易
    // 3. 为符合条件的交易添加旅行标签
    // 4. 更新事件的交易统计
  }

  /// 更新事件统计
  void updateEventStats(
      String eventId, int transactionCount, double totalAmount) {
    state = state.map((event) {
      if (event.id == eventId) {
        return event.copyWith(
          transactionCount: transactionCount,
          totalAmount: totalAmount,
          updatedAt: DateTime.now(),
        );
      }
      return event;
    }).toList();
    // TODO: 保存到存储
  }
}

/// 旅行事件模板管理
class TravelEventTemplateNotifier
    extends StateNotifier<List<TravelEventTemplate>> {
  TravelEventTemplateNotifier() : super([]) {
    _loadTemplates();
  }

  void _loadTemplates() {
    // 加载系统模板和用户自定义模板
    state = [
      ...TravelEventTemplateLibrary.getSystemTemplates(),
      // TODO: 加载用户自定义模板
    ];
  }

  /// 添加自定义模板
  void addCustomTemplate(TravelEventTemplate template) {
    final newTemplate = template.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isSystemTemplate: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = [...state, newTemplate];
    // TODO: 保存到存储
  }

  /// 删除自定义模板
  void deleteCustomTemplate(String templateId) {
    state = state
        .where((template) =>
            template.id != templateId || template.isSystemTemplate)
        .toList();
    // TODO: 保存到存储
  }
}

/// 旅行事件Provider
final travelEventsProvider =
    StateNotifierProvider<TravelEventNotifier, List<TravelEvent>>((ref) {
  return TravelEventNotifier();
});

/// 旅行事件模板Provider
final travelEventTemplatesProvider = StateNotifierProvider<
    TravelEventTemplateNotifier, List<TravelEventTemplate>>((ref) {
  return TravelEventTemplateNotifier();
});

/// 按状态过滤的旅行事件Provider
final travelEventsByStatusProvider =
    Provider.family<List<TravelEvent>, TravelEventStatus>((ref, status) {
  final events = ref.watch(travelEventsProvider);
  return events.where((event) => event.status == status).toList();
});

/// 即将开始的旅行事件
final upcomingTravelEventsProvider = Provider<List<TravelEvent>>((ref) {
  return ref.watch(travelEventsByStatusProvider(TravelEventStatus.upcoming));
});

/// 进行中的旅行事件
final activeTravelEventsProvider = Provider<List<TravelEvent>>((ref) {
  return ref.watch(travelEventsByStatusProvider(TravelEventStatus.active));
});

/// 已完成的旅行事件
final completedTravelEventsProvider = Provider<List<TravelEvent>>((ref) {
  return ref.watch(travelEventsByStatusProvider(TravelEventStatus.completed));
});

/// 启用的旅行事件
final enabledTravelEventsProvider = Provider<List<TravelEvent>>((ref) {
  final events = ref.watch(travelEventsProvider);
  return events.where((event) => event.isActive).toList();
});

/// 系统模板Provider
final systemTemplatesProvider = Provider<List<TravelEventTemplate>>((ref) {
  final templates = ref.watch(travelEventTemplatesProvider);
  return templates.where((template) => template.isSystemTemplate).toList();
});

/// 用户自定义模板Provider
final customTemplatesProvider = Provider<List<TravelEventTemplate>>((ref) {
  final templates = ref.watch(travelEventTemplatesProvider);
  return templates.where((template) => !template.isSystemTemplate).toList();
});

/// 旅行事件统计Provider
final travelEventStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final events = ref.watch(travelEventsProvider);
  final now = DateTime.now();

  return {
    'totalEvents': events.length,
    'upcomingEvents':
        events.where((e) => e.status == TravelEventStatus.upcoming).length,
    'activeEvents':
        events.where((e) => e.status == TravelEventStatus.active).length,
    'completedEvents':
        events.where((e) => e.status == TravelEventStatus.completed).length,
    'enabledEvents': events.where((e) => e.isActive).length,
    'totalTransactions':
        events.fold(0, (sum, event) => sum + event.transactionCount),
    'totalAmount':
        events.fold(0.0, (sum, event) => sum + (event.totalAmount ?? 0.0)),
    'thisYearEvents': events.where((e) => e.startDate.year == now.year).length,
  };
});
