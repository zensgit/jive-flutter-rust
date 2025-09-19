import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/audit_log.dart';
import '../../services/audit_service.dart';
import '../../utils/date_utils.dart' as date_utils;
import '../../widgets/permission_guard.dart';
import '../../services/permission_service.dart';

/// 审计日志页面
class AuditLogsScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const AuditLogsScreen({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  final _auditService = AuditService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<AuditLog> _logs = [];
  AuditLogStatistics? _statistics;
  AuditLogFilter _filter = AuditLogFilter();
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;

  // 过滤选项
  AuditActionType? _selectedActionType;
  AuditSeverity? _selectedSeverity;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _filter = AuditLogFilter(familyId: widget.familyId);
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
    _searchController.dispose();
    _scrollController.dispose();
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
      final logs = await _auditService.getAuditLogs(
        filter: _filter,
        page: _currentPage,
        pageSize: 20,
      );

      setState(() {
        if (reset) {
          _logs = logs;
        } else {
          _logs.addAll(logs);
        }
        _hasMore = logs.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (!_hasMore || _isLoading) return;

    setState(() {
      _currentPage++;
    });

    await _loadLogs(reset: false);
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _auditService.getAuditStatistics(widget.familyId);
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      // 统计信息加载失败不影响主功能
    }
  }

  void _applyFilters() {
    _filter = _filter.copyWith(
      actionTypes: _selectedActionType != null ? [_selectedActionType!] : null,
      severities: _selectedSeverity != null ? [_selectedSeverity!] : null,
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      searchQuery:
          _searchController.text.isNotEmpty ? _searchController.text : null,
    );
    _loadLogs();
  }

  void _clearFilters() {
    setState(() {
      _selectedActionType = null;
      _selectedSeverity = null;
      _selectedDateRange = null;
      _searchController.clear();
      _filter = AuditLogFilter(familyId: widget.familyId);
    });
    _loadLogs();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _applyFilters();
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
            Text('审计日志'),
            Text(
              widget.familyName,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadLogs();
              _loadStatistics();
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('导出日志'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('清理旧日志'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'export') {
                _exportLogs();
              } else if (value == 'clear') {
                _clearOldLogs();
              }
            },
          ),
        ],
      ),
      body: PermissionGuard(
        familyId: widget.familyId,
        action: PermissionAction.viewAuditLogs,
        fallback: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '您没有权限查看审计日志',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '只有管理员和拥有者可以查看',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        child: Column(
          children: [
            // 统计卡片
            if (_statistics != null) _buildStatisticsCard(),

            // 过滤栏
            _buildFilterBar(),

            // 日志列表
            Expanded(
              child: _isLoading && _logs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _logs.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildLogItem(_logs[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final theme = Theme.of(context);
    final stats = _statistics!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '今日',
                stats.todayLogs.toString(),
                Icons.today,
              ),
              _buildStatItem(
                '本周',
                stats.weekLogs.toString(),
                Icons.date_range,
              ),
              _buildStatItem(
                '本月',
                stats.monthLogs.toString(),
                Icons.calendar_month,
              ),
              _buildStatItem(
                '总计',
                stats.totalLogs.toString(),
                Icons.analytics,
              ),
            ],
          ),
          if (stats.recentAlerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '最近警告: ${stats.recentAlerts.first}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onPrimaryContainer,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索日志内容...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),

          const SizedBox(height: 12),

          // 过滤选项
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 操作类型
                FilterChip(
                  label: Text(_selectedActionType?.label ?? '所有操作'),
                  selected: _selectedActionType != null,
                  onSelected: (_) => _showActionTypeSelector(),
                  avatar: Icon(Icons.category, size: 18),
                ),
                const SizedBox(width: 8),

                // 严重级别
                FilterChip(
                  label: Text(_selectedSeverity?.label ?? '所有级别'),
                  selected: _selectedSeverity != null,
                  onSelected: (_) => _showSeveritySelector(),
                  avatar: Icon(Icons.warning, size: 18),
                ),
                const SizedBox(width: 8),

                // 日期范围
                FilterChip(
                  label: Text(_selectedDateRange != null
                      ? '${date_utils.DateUtils.formatDate(_selectedDateRange!.start)} - ${date_utils.DateUtils.formatDate(_selectedDateRange!.end)}'
                      : '时间范围'),
                  selected: _selectedDateRange != null,
                  onSelected: (_) => _selectDateRange(),
                  avatar: Icon(Icons.date_range, size: 18),
                ),
                const SizedBox(width: 8),

                // 清除过滤
                if (_selectedActionType != null ||
                    _selectedSeverity != null ||
                    _selectedDateRange != null ||
                    _searchController.text.isNotEmpty)
                  ActionChip(
                    label: Text('清除过滤'),
                    onPressed: _clearFilters,
                    avatar: Icon(Icons.clear, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(AuditLog log) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(log.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 严重级别指示器
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // 日志内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getActionconst Icon(log.actionType),
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            log.actionDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 用户和时间
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          log.userName ?? 'Unknown',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          log.timeAgo,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),

                    // 变更摘要
                    if (log.oldValue != null || log.newValue != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.changeSummary,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 查看详情按钮
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () => _showLogDetails(log),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无日志记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '系统将自动记录所有重要操作',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showActionTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择操作类型',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AuditActionType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: _selectedActionType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedActionType = selected ? type : null;
                    });
                    Navigator.pop(context);
                    _applyFilters();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeveritySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择严重级别',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...AuditSeverity.values.map((severity) {
              return ListTile(
                leading: Icon(
                  Icons.circle,
                  color: _getSeverityColor(severity),
                ),
                title: Text(severity.label),
                selected: _selectedSeverity == severity,
                onTap: () {
                  setState(() {
                    _selectedSeverity =
                        _selectedSeverity == severity ? null : severity;
                  });
                  Navigator.pop(context);
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showLogDetails(AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('日志详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('操作', log.actionType.label),
              _buildDetailRow('描述', log.actionDescription),
              _buildDetailRow('用户', log.userName ?? 'Unknown'),
              _buildDetailRow(
                  '时间', date_utils.DateUtils.formatDateTime(log.createdAt)),
              _buildDetailRow('IP地址', log.ipAddress),
              if (log.targetName != null)
                _buildDetailRow('目标', log.targetName!),
              if (log.metadata != null)
                _buildDetailRow('元数据', log.metadata.toString()),
              if (log.oldValue != null)
                _buildDetailRow('旧值', log.oldValue.toString()),
              if (log.newValue != null)
                _buildDetailRow('新值', log.newValue.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.info:
        return Colors.blue;
      case AuditSeverity.warning:
        return Colors.orange;
      case AuditSeverity.error:
        return Colors.red;
      case AuditSeverity.critical:
        return Colors.purple;
    }
  }

  IconData _getActionconst Icon(AuditActionType type) {
    switch (type) {
      case AuditActionType.userLogin:
      case AuditActionType.userLogout:
      case AuditActionType.userRegister:
        return Icons.person;
      case AuditActionType.familyCreate:
      case AuditActionType.familyUpdate:
      case AuditActionType.familyDelete:
        return Icons.home;
      case AuditActionType.memberInvite:
      case AuditActionType.memberAccept:
      case AuditActionType.memberRemove:
        return Icons.group;
      case AuditActionType.transactionCreate:
      case AuditActionType.transactionUpdate:
      case AuditActionType.transactionDelete:
        return Icons.receipt;
      case AuditActionType.categoryCreate:
      case AuditActionType.categoryUpdate:
      case AuditActionType.categoryDelete:
        return Icons.category;
      case AuditActionType.settingsUpdate:
        return Icons.settings;
      case AuditActionType.dataExport:
      case AuditActionType.dataImport:
        return Icons.import_export;
      case AuditActionType.securityAlert:
      case AuditActionType.suspiciousActivity:
        return Icons.security;
      default:
        return Icons.info;
    }
  }

  void _exportLogs() {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中')),
    );
  }

  void _clearOldLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理旧日志'),
        content: Text('将删除超过90天的日志记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 实现清理功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('清理功能开发中')),
              );
            },
            child: Text('确定清理'),
          ),
        ],
      ),
    );
  }
}
