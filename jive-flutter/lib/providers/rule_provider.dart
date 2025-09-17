import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';

/// 规则状态管理 - 基于Riverpod
class RuleNotifier extends StateNotifier<List<Rule>> {
  RuleNotifier() : super([]) {
    _loadRules();
  }

  void _loadRules() {
    // TODO: 从存储加载规则，目前使用示例数据
    state = [
      // 自动分类规则
      Rule(
        id: '1',
        name: '星巴克自动分类',
        description: '识别星巴克支出并自动分类为餐饮',
        resourceType: ResourceType.transaction,
        active: true,
        priority: 1,
        conditions: [
          RuleCondition(
            id: 'c1',
            type: ConditionType.description,
            operator: ConditionOperator.contains,
            value: '星巴克',
          ),
        ],
        actions: [
          RuleAction(
            id: 'a1',
            type: ActionType.setCategory,
            value: 'dining_category_id',
          ),
          RuleAction(
            id: 'a2',
            type: ActionType.addTag,
            value: 'coffee_tag_id',
          ),
        ],
        executionCount: 15,
        lastExecutedAt: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),

      // 工资收入规则
      Rule(
        id: '2',
        name: '工资收入分类',
        description: '自动识别工资收入',
        resourceType: ResourceType.transaction,
        active: true,
        priority: 2,
        conditions: [
          RuleCondition(
            id: 'c2',
            type: ConditionType.description,
            operator: ConditionOperator.contains,
            value: '工资',
          ),
          RuleCondition(
            id: 'c3',
            type: ConditionType.amount,
            operator: ConditionOperator.greaterThan,
            value: 5000.0,
          ),
        ],
        actions: [
          RuleAction(
            id: 'a3',
            type: ActionType.setCategory,
            value: 'salary_category_id',
          ),
          RuleAction(
            id: 'a4',
            type: ActionType.addTag,
            value: 'work_tag_id',
          ),
        ],
        executionCount: 6,
        lastExecutedAt: DateTime.now().subtract(const Duration(days: 30)),
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),

      // 大额支出提醒
      Rule(
        id: '3',
        name: '大额支出提醒',
        description: '单笔支出超过1000元时发送通知',
        resourceType: ResourceType.transaction,
        active: true,
        priority: 3,
        conditions: [
          RuleCondition(
            id: 'c4',
            type: ConditionType.amount,
            operator: ConditionOperator.greaterThan,
            value: 1000.0,
          ),
        ],
        actions: [
          RuleAction(
            id: 'a5',
            type: ActionType.notify,
            value: '检测到大额支出，请注意核实',
          ),
          RuleAction(
            id: 'a6',
            type: ActionType.addTag,
            value: 'large_expense_tag_id',
          ),
        ],
        executionCount: 3,
        lastExecutedAt: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),

      // 已停用的规则
      Rule(
        id: '4',
        name: '旧版转账规则',
        description: '已停用的转账识别规则',
        resourceType: ResourceType.transaction,
        active: false,
        priority: 0,
        conditions: [
          RuleCondition(
            id: 'c5',
            type: ConditionType.description,
            operator: ConditionOperator.contains,
            value: '转账',
          ),
        ],
        actions: [
          RuleAction(
            id: 'a7',
            type: ActionType.markAsTransfer,
          ),
        ],
        executionCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
    ];
  }

  /// 添加规则
  void addRule(Rule rule) {
    final newRule = rule.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    state = [...state, newRule];
    // TODO: 保存到存储
  }

  /// 更新规则
  void updateRule(Rule updatedRule) {
    state = state.map((rule) {
      if (rule.id == updatedRule.id) {
        return updatedRule.copyWith(updatedAt: DateTime.now());
      }
      return rule;
    }).toList();
    // TODO: 保存到存储
  }

  /// 删除规则
  void deleteRule(String ruleId) {
    state = state.where((rule) => rule.id != ruleId).toList();
    // TODO: 保存到存储
  }

  /// 启用/停用规则
  void toggleRuleActive(String ruleId, bool active) {
    state = state.map((rule) {
      if (rule.id == ruleId) {
        return rule.copyWith(
          active: active,
          updatedAt: DateTime.now(),
        );
      }
      return rule;
    }).toList();
    // TODO: 保存到存储
  }

  /// 更新规则优先级
  void updateRulePriority(String ruleId, int priority) {
    state = state.map((rule) {
      if (rule.id == ruleId) {
        return rule.copyWith(
          priority: priority,
          updatedAt: DateTime.now(),
        );
      }
      return rule;
    }).toList();
    // TODO: 保存到存储
  }

  /// 记录规则执行
  void recordExecution(String ruleId, bool success) {
    state = state.map((rule) {
      if (rule.id == ruleId) {
        return rule.copyWith(
          executionCount: rule.executionCount + 1,
          lastExecutedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return rule;
    }).toList();
    // TODO: 保存到存储
  }

  /// 重新排序规则（按优先级）
  void reorderRules(List<Rule> reorderedRules) {
    final updatedRules = <Rule>[];
    for (int i = 0; i < reorderedRules.length; i++) {
      updatedRules.add(reorderedRules[i].copyWith(
        priority: i + 1,
        updatedAt: DateTime.now(),
      ));
    }
    state = updatedRules;
    // TODO: 保存到存储
  }

  /// 复制规则
  Rule duplicateRule(String ruleId) {
    final originalRule = state.firstWhere((rule) => rule.id == ruleId);
    final duplicatedRule = originalRule.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${originalRule.name} (副本)',
      executionCount: 0,
      lastExecutedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    addRule(duplicatedRule);
    return duplicatedRule;
  }
}

/// 规则日志状态管理
class RuleLogNotifier extends StateNotifier<List<RuleLog>> {
  RuleLogNotifier() : super([]);

  /// 添加执行日志
  void addLog(RuleLog log) {
    final newLog = log.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      executedAt: DateTime.now(),
    );

    state = [newLog, ...state];
    // TODO: 保存到存储，限制日志数量
  }

  /// 清理旧日志
  void cleanOldLogs({int keepDays = 30}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    state = state.where((log) {
      final logDate = log.executedAt ?? DateTime.fromMicrosecondsSinceEpoch(0);
      return logDate.isAfter(cutoffDate);
    }).toList();
    // TODO: 保存到存储
  }

  /// 获取规则的执行日志
  List<RuleLog> getRuleLog(String ruleId) {
    return state.where((log) => log.ruleId == ruleId).toList();
  }
}

/// 规则Provider
final rulesProvider = StateNotifierProvider<RuleNotifier, List<Rule>>((ref) {
  return RuleNotifier();
});

/// 规则日志Provider
final ruleLogsProvider =
    StateNotifierProvider<RuleLogNotifier, List<RuleLog>>((ref) {
  return RuleLogNotifier();
});

/// 活跃规则Provider
final activeRulesProvider = Provider<List<Rule>>((ref) {
  final rules = ref.watch(rulesProvider);
  return rules.where((rule) => rule.active).toList()
    ..sort((a, b) => (a.priority ?? 999).compareTo(b.priority ?? 999));
});

/// 停用规则Provider
final inactiveRulesProvider = Provider<List<Rule>>((ref) {
  final rules = ref.watch(rulesProvider);
  return rules.where((rule) => !rule.active).toList();
});

/// 按资源类型过滤的规则Provider
final rulesByResourceTypeProvider =
    Provider.family<List<Rule>, ResourceType>((ref, type) {
  final rules = ref.watch(rulesProvider);
  return rules.where((rule) => rule.resourceType == type).toList();
});

/// 交易规则Provider
final transactionRulesProvider = Provider<List<Rule>>((ref) {
  return ref.watch(rulesByResourceTypeProvider(ResourceType.transaction));
});

/// 最近执行的规则Provider
final recentlyExecutedRulesProvider = Provider<List<Rule>>((ref) {
  final rules = ref.watch(rulesProvider);
  final recentRules =
      rules.where((rule) => rule.lastExecutedAt != null).toList();
  recentRules.sort((a, b) => b.lastExecutedAt!.compareTo(a.lastExecutedAt!));
  return recentRules.take(5).toList();
});

/// 规则统计Provider
final ruleStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final rules = ref.watch(rulesProvider);
  final logs = ref.watch(ruleLogsProvider);

  return {
    'totalRules': rules.length,
    'activeRules': rules.where((r) => r.active).length,
    'inactiveRules': rules.where((r) => !r.active).length,
    'totalExecutions': rules.fold(0, (sum, rule) => sum + rule.executionCount),
    'recentLogs': logs.take(10).length,
    'successRate':
        logs.isEmpty ? 0.0 : logs.where((l) => l.success).length / logs.length,
  };
});
