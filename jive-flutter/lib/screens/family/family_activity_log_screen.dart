import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/audit_log.dart';
import '../../services/audit_service.dart';
import '../../utils/date_utils.dart' as date_utils;

/// 家庭活动日志页面
class FamilyActivityLogScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const FamilyActivityLogScreen({
    Key? key,
    required this.familyId,
    required this.familyName,
  }) : super(key: key);

  @override
  ConsumerState<FamilyActivityLogScreen> createState() => _FamilyActivityLogScreenState();
}

class _FamilyActivityLogScreenState extends ConsumerState<FamilyActivityLogScreen> {
  final _auditService = AuditService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  
  List<AuditLog> _logs = [];
  Map<String, List<AuditLog>> _groupedLogs = {};
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  
  // 过滤选项
  AuditActionType? _selectedActionType;
  String? _selectedMemberId;
  DateTimeRange? _selectedDateRange;
  
  // 活动统计
  ActivityStatistics? _statistics;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadStatistics();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreLogs();
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLogs({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
      });
    }
    
    try {
      final filter = AuditLogFilter(
        familyId: widget.familyId,
        actionType: _selectedActionType,
        userId: _selectedMemberId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );
      
      final logs = await _auditService.getAuditLogs(
        filter: filter,
        page: _currentPage,
        pageSize: 20,
      );
      
      setState(() {
        if (reset) {
          _logs = logs;
        } else {
          _logs.addAll(logs);
        }
        _groupLogs();
        _hasMore = logs.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载活动日志失败: $e')),
        );
      }
    }
  }
  
  Future<void> _loadMoreLogs() async {
    if (!_hasMore || _isLoading) return;
    
    setState(() => _currentPage++);
    await _loadLogs(reset: false);
  }
  
  Future<void> _loadStatistics() async {
    try {
      final stats = await _auditService.getActivityStatistics(widget.familyId);
      setState(() => _statistics = stats);
    } catch (e) {
      // 忽略统计加载失败
    }
  }
  
  void _groupLogs() {
    _groupedLogs.clear();
    
    for (final log in _logs) {
      final dateKey = DateFormat('yyyy-MM-dd').format(log.createdAt);
      if (!_groupedLogs.containsKey(dateKey)) {
        _groupedLogs[dateKey] = [];
      }
      _groupedLogs[dateKey]!.add(log);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('活动日志'),
            Text(
              widget.familyName,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: _showStatisticsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索活动内容...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadLogs();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onSubmitted: (_) => _loadLogs(),
            ),
          ),
          
          // 快速筛选
          if (_statistics != null)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildQuickFilter(
                    '全部',
                    _selectedActionType == null,
                    () {
                      setState(() => _selectedActionType = null);
                      _loadLogs();
                    },
                  ),
                  ...AuditActionType.values.take(5).map((type) =>
                      _buildQuickFilter(
                        _getActionTypeLabel(type),
                        _selectedActionType == type,
                        () {
                          setState(() => _selectedActionType = type);
                          _loadLogs();
                        },
                      )),
                ],
              ),
            ),
          
          // 活动列表
          Expanded(
            child: _isLoading && _logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? _buildEmptyState()
                    : _buildActivityList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickFilter(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: theme.colorScheme.surfaceVariant,
        selectedColor: theme.colorScheme.primaryContainer,
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无活动记录',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '家庭成员的操作都会记录在这里',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityList() {
    return RefreshIndicator(
      onRefresh: () => _loadLogs(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _groupedLogs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _groupedLogs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final dateKey = _groupedLogs.keys.elementAt(index);
          final logs = _groupedLogs[dateKey]!;
          
          return _buildDaySection(dateKey, logs);
        },
      ),
    );
  }
  
  Widget _buildDaySection(String dateKey, List<AuditLog> logs) {
    final theme = Theme.of(context);
    final date = DateTime.parse(dateKey);
    final isToday = date_utils.DateUtils.isToday(date);
    final isYesterday = date_utils.DateUtils.isYesterday(date);
    
    String dateLabel;
    if (isToday) {
      dateLabel = '今天';
    } else if (isYesterday) {
      dateLabel = '昨天';
    } else {
      dateLabel = DateFormat('MM月dd日 EEEE', 'zh_CN').format(date);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${logs.length} 条活动',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // 活动列表
        ...logs.map((log) => _buildActivityItem(log)),
      ],
    );
  }
  
  Widget _buildActivityItem(AuditLog log) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('HH:mm').format(log.createdAt);
    
    return InkWell(
      onTap: () => _showActivityDetail(log),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.surfaceVariant,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间轴
            Column(
              children: [
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getActionColor(log.actionType).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getActionIcon(log.actionType),
                    size: 20,
                    color: _getActionColor(log.actionType),
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            // 活动内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.userName ?? '未知用户',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      _buildSeverityBadge(log.severity),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.details!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (log.entityName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.entityName!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showActivityDetail(AuditLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ActivityDetailSheet(log: log),
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedActionType: _selectedActionType,
        selectedMemberId: _selectedMemberId,
        selectedDateRange: _selectedDateRange,
        onApply: (actionType, memberId, dateRange) {
          setState(() {
            _selectedActionType = actionType;
            _selectedMemberId = memberId;
            _selectedDateRange = dateRange;
          });
          _loadLogs();
        },
      ),
    );
  }
  
  void _showStatisticsDialog() {
    if (_statistics == null) return;
    
    showDialog(
      context: context,
      builder: (context) => _StatisticsDialog(statistics: _statistics!),
    );
  }
  
  Widget _buildSeverityBadge(AuditSeverity severity) {
    Color color;
    String label;
    
    switch (severity) {
      case AuditSeverity.info:
        color = Colors.blue;
        label = '信息';
        break;
      case AuditSeverity.warning:
        color = Colors.orange;
        label = '警告';
        break;
      case AuditSeverity.error:
        color = Colors.red;
        label = '错误';
        break;
      case AuditSeverity.critical:
        color = Colors.purple;
        label = '严重';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  IconData _getActionIcon(AuditActionType type) {
    switch (type) {
      case AuditActionType.create:
        return Icons.add_circle_outline;
      case AuditActionType.update:
        return Icons.edit;
      case AuditActionType.delete:
        return Icons.delete_outline;
      case AuditActionType.login:
        return Icons.login;
      case AuditActionType.logout:
        return Icons.logout;
      case AuditActionType.invite:
        return Icons.person_add;
      case AuditActionType.join:
        return Icons.group_add;
      case AuditActionType.leave:
        return Icons.exit_to_app;
      case AuditActionType.permission_grant:
        return Icons.security;
      case AuditActionType.permission_revoke:
        return Icons.remove_moderator;
      default:
        return Icons.history;
    }
  }
  
  Color _getActionColor(AuditActionType type) {
    switch (type) {
      case AuditActionType.create:
        return Colors.green;
      case AuditActionType.update:
        return Colors.blue;
      case AuditActionType.delete:
        return Colors.red;
      case AuditActionType.login:
      case AuditActionType.logout:
        return Colors.purple;
      case AuditActionType.invite:
      case AuditActionType.join:
      case AuditActionType.leave:
        return Colors.orange;
      case AuditActionType.permission_grant:
      case AuditActionType.permission_revoke:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
  
  String _getActionTypeLabel(AuditActionType type) {
    switch (type) {
      case AuditActionType.create:
        return '创建';
      case AuditActionType.update:
        return '更新';
      case AuditActionType.delete:
        return '删除';
      case AuditActionType.login:
        return '登录';
      case AuditActionType.logout:
        return '登出';
      case AuditActionType.invite:
        return '邀请';
      case AuditActionType.join:
        return '加入';
      case AuditActionType.leave:
        return '离开';
      case AuditActionType.permission_grant:
        return '授权';
      case AuditActionType.permission_revoke:
        return '撤权';
      default:
        return '其他';
    }
  }
}

/// 活动详情弹窗
class _ActivityDetailSheet extends StatelessWidget {
  final AuditLog log;

  const _ActivityDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('活动详情', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    
                    _buildDetailRow('操作者', log.userName ?? '未知用户'),
                    _buildDetailRow('操作类型', log.actionType.toString().split('.').last),
                    _buildDetailRow('时间', dateFormatter.format(log.createdAt)),
                    _buildDetailRow('描述', log.description),
                    
                    if (log.entityType != null)
                      _buildDetailRow('实体类型', log.entityType!),
                    if (log.entityId != null)
                      _buildDetailRow('实体ID', log.entityId!),
                    if (log.entityName != null)
                      _buildDetailRow('实体名称', log.entityName!),
                    
                    if (log.details != null) ...[
                      const SizedBox(height: 16),
                      Text('详细信息', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(log.details!),
                      ),
                    ],
                    
                    if (log.ipAddress != null) ...[
                      const SizedBox(height: 16),
                      Text('技术信息', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildDetailRow('IP地址', log.ipAddress!),
                      if (log.userAgent != null)
                        _buildDetailRow('用户代理', log.userAgent!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

/// 过滤对话框
class _FilterDialog extends StatefulWidget {
  final AuditActionType? selectedActionType;
  final String? selectedMemberId;
  final DateTimeRange? selectedDateRange;
  final Function(AuditActionType?, String?, DateTimeRange?) onApply;

  const _FilterDialog({
    this.selectedActionType,
    this.selectedMemberId,
    this.selectedDateRange,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  AuditActionType? _actionType;
  String? _memberId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _actionType = widget.selectedActionType;
    _memberId = widget.selectedMemberId;
    _dateRange = widget.selectedDateRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('筛选活动'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 操作类型
          Text('操作类型', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<AuditActionType?>(
            value: _actionType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('全部'),
              ),
              ...AuditActionType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.toString().split('.').last),
              )),
            ],
            onChanged: (value) => setState(() => _actionType = value),
          ),
          
          const SizedBox(height: 16),
          
          // 日期范围
          Text('日期范围', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateRange == null
                        ? '选择日期范围'
                        : '${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}',
                  ),
                  const Icon(Icons.calendar_today, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _actionType = null;
              _memberId = null;
              _dateRange = null;
            });
          },
          child: const Text('重置'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_actionType, _memberId, _dateRange);
            Navigator.pop(context);
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}

/// 统计对话框
class _StatisticsDialog extends StatelessWidget {
  final ActivityStatistics statistics;

  const _StatisticsDialog({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('活动统计'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatItem('今日活动', '${statistics.todayCount}'),
          _buildStatItem('本周活动', '${statistics.weekCount}'),
          _buildStatItem('本月活动', '${statistics.monthCount}'),
          const Divider(),
          _buildStatItem('最活跃用户', statistics.mostActiveUser),
          _buildStatItem('最常操作', statistics.mostFrequentAction),
          const Divider(),
          _buildStatItem('平均每日', '${statistics.dailyAverage.toStringAsFixed(1)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// 活动统计数据
class ActivityStatistics {
  final int todayCount;
  final int weekCount;
  final int monthCount;
  final String mostActiveUser;
  final String mostFrequentAction;
  final double dailyAverage;

  ActivityStatistics({
    required this.todayCount,
    required this.weekCount,
    required this.monthCount,
    required this.mostActiveUser,
    required this.mostFrequentAction,
    required this.dailyAverage,
  });
}