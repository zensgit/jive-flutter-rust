import 'package:flutter/material.dart';
import '../../utils/string_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/family.dart' as family_model;
import '../../services/api/family_service.dart';
import '../../widgets/loading_overlay.dart';

/// 权限审计界面
class FamilyPermissionsAuditScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String familyName;

  const FamilyPermissionsAuditScreen({
    Key? key,
    required this.familyId,
    required this.familyName,
  }) : super(key: key);

  @override
  ConsumerState<FamilyPermissionsAuditScreen> createState() =>
      _FamilyPermissionsAuditScreenState();
}

class _FamilyPermissionsAuditScreenState
    extends ConsumerState<FamilyPermissionsAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FamilyService _familyService = FamilyService();
  
  bool _isLoading = false;
  List<PermissionAuditLog> _auditLogs = [];
  Map<String, PermissionUsageStats> _usageStats = {};
  List<AnomalyDetection> _anomalies = [];
  ComplianceReport? _complianceReport;
  
  // 筛选条件
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedUser;
  String? _selectedPermission;
  AuditEventType? _selectedEventType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAuditData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditData() async {
    setState(() => _isLoading = true);
    
    try {
      // 并行加载所有数据
      final results = await Future.wait([
        _familyService.getPermissionAuditLogs(
          widget.familyId,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _familyService.getPermissionUsageStats(widget.familyId),
        _familyService.detectPermissionAnomalies(widget.familyId),
        _familyService.generateComplianceReport(widget.familyId),
      ]);
      
      setState(() {
        _auditLogs = results[0] as List<PermissionAuditLog>? ?? [];
        _usageStats = results[1] as Map<String, PermissionUsageStats>? ?? {};
        _anomalies = results[2] as List<AnomalyDetection>? ?? [];
        _complianceReport = results[3] as ComplianceReport?;
      });
    } catch (e) {
      _showError('加载审计数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('权限审计'),
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
              tooltip: '筛选',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAuditData,
              tooltip: '刷新',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportAuditReport();
                    break;
                  case 'schedule':
                    _scheduleAutomaticAudit();
                    break;
                  case 'settings':
                    _showAuditSettings();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('导出报告'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'schedule',
                  child: ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('定时审计'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('审计设置'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '变更历史'),
              Tab(text: '使用分析'),
              Tab(text: '异常检测'),
              Tab(text: '合规报告'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChangeHistory(),
            _buildUsageAnalysis(),
            _buildAnomalyDetection(),
            _buildComplianceReport(),
          ],
        ),
      ),
    );
  }

  /// 构建变更历史标签页
  Widget _buildChangeHistory() {
    final filteredLogs = _filterAuditLogs();
    
    if (filteredLogs.isEmpty) {
      return const Center(
        child: Text('暂无权限变更记录'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildAuditLogCard(log);
      },
    );
  }

  /// 构建审计日志卡片
  Widget _buildAuditLogCard(PermissionAuditLog log) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getEventColor(log.eventType).withOpacity(0.2),
          child: Icon(
            _getEventIcon(log.eventType),
            color: _getEventColor(log.eventType),
            size: 20,
          ),
        ),
        title: Text(log.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  log.performedBy,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MM-dd HH:mm').format(log.timestamp),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.targetUser != null) ...[
                  _buildDetailRow('目标用户', log.targetUser!),
                  const SizedBox(height: 8),
                ],
                if (log.permissions.isNotEmpty) ...[
                  _buildDetailRow('涉及权限', log.permissions.join(', ')),
                  const SizedBox(height: 8),
                ],
                if (log.oldValue != null) ...[
                  _buildDetailRow('原值', log.oldValue!),
                  const SizedBox(height: 8),
                ],
                if (log.newValue != null) ...[
                  _buildDetailRow('新值', log.newValue!),
                  const SizedBox(height: 8),
                ],
                if (log.reason != null) ...[
                  _buildDetailRow('原因', log.reason!),
                  const SizedBox(height: 8),
                ],
                if (log.ipAddress != null) ...[
                  _buildDetailRow('IP地址', log.ipAddress!),
                  const SizedBox(height: 8),
                ],
                if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                  const Text(
                    '其他信息：',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...log.metadata!.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建使用分析标签页
  Widget _buildUsageAnalysis() {
    if (_usageStats.isEmpty) {
      return const Center(
        child: Text('暂无使用统计数据'),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 权限使用频率图表
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '权限使用频率',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildUsageFrequencyChart(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 用户活跃度
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '用户活跃度',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._buildUserActivityList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 权限使用趋势
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '权限使用趋势',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildUsageTrendChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建异常检测标签页
  Widget _buildAnomalyDetection() {
    if (_anomalies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '未检测到异常行为',
              style: TextStyle(fontSize: 18, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              '权限使用正常',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _anomalies.length,
      itemBuilder: (context, index) {
        final anomaly = _anomalies[index];
        return _buildAnomalyCard(anomaly);
      },
    );
  }

  /// 构建异常卡片
  Widget _buildAnomalyCard(AnomalyDetection anomaly) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(anomaly.severity);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withOpacity(0.2),
          child: Icon(
            _getSeverityIcon(anomaly.severity),
            color: severityColor,
          ),
        ),
        title: Text(anomaly.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(anomaly.description),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    anomaly.type.toString().split('.').last,
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MM-dd HH:mm').format(anomaly.detectedAt),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                ),
              ],
            ),
            if (anomaly.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '建议措施：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              ...anomaly.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $r', style: const TextStyle(fontSize: 12)),
              )),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => _showAnomalyDetails(anomaly),
        ),
      ),
    );
  }

  /// 构建合规报告标签页
  Widget _buildComplianceReport() {
    if (_complianceReport == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final report = _complianceReport!;
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 合规评分
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    '合规评分',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: report.score / 100,
                          strokeWidth: 12,
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getScoreColor(report.score),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${report.score}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(report.score),
                            ),
                          ),
                          Text(
                            _getScoreLabel(report.score),
                            style: TextStyle(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '生成时间：${DateFormat('yyyy-MM-dd HH:mm').format(report.generatedAt)}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 合规项检查
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '合规项检查',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...report.checkItems.map((item) => _buildComplianceCheckItem(item)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 问题与建议
          if (report.issues.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '发现的问题',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...report.issues.map((issue) => _buildIssueItem(issue)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建使用频率图表
  Widget _buildUsageFrequencyChart() {
    final sortedStats = _usageStats.entries.toList()
      ..sort((a, b) => b.value.usageCount.compareTo(a.value.usageCount));
    
    final topStats = sortedStats.take(10).toList();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: topStats.isEmpty ? 0 : topStats.first.value.usageCount.toDouble(),
        barGroups: topStats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: stat.value.usageCount.toDouble(),
                color: Theme.of(context).colorScheme.primary,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= topStats.length) return const SizedBox();
                final permission = topStats[value.toInt()].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    permission.split('.').last,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /// 构建使用趋势图表
  Widget _buildUsageTrendChart() {
    // 模拟趋势数据
    final trendData = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return FlSpot(index.toDouble(), (50 + index * 10).toDouble());
    });
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: trendData,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户活跃度列表
  List<Widget> _buildUserActivityList() {
    // 模拟用户活跃度数据
    final users = [
      ('张三', 156, true),
      ('李四', 98, true),
      ('王五', 45, false),
      ('赵六', 23, false),
    ];
    
    return users.map((user) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: user.$3 ? Colors.green : Colors.orange,
          child: Text(
            StringUtils.safeInitial(user.$1),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user.$1),
        subtitle: Text('${user.$2} 次操作'),
        trailing: Chip(
          label: Text(
            user.$3 ? '活跃' : '不活跃',
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: user.$3 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  /// 构建合规检查项
  Widget _buildComplianceCheckItem(ComplianceCheckItem item) {
    final passed = item.status == ComplianceStatus.passed;
    final color = passed ? Colors.green : Colors.red;
    
    return ListTile(
      leading: Icon(
        passed ? Icons.check_circle : Icons.cancel,
        color: color,
      ),
      title: Text(item.name),
      subtitle: Text(item.description),
      trailing: Text(
        passed ? '通过' : '未通过',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建问题项
  Widget _buildIssueItem(ComplianceIssue issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.warning,
          color: _getSeverityColor(issue.severity),
        ),
        title: Text(issue.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(issue.description),
            if (issue.recommendation != null) ...[
              const SizedBox(height: 8),
              Text(
                '建议：${issue.recommendation}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label：',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// 过滤审计日志
  List<PermissionAuditLog> _filterAuditLogs() {
    return _auditLogs.where((log) {
      if (_selectedUser != null && log.performedBy != _selectedUser) {
        return false;
      }
      if (_selectedPermission != null &&
          !log.permissions.contains(_selectedPermission)) {
        return false;
      }
      if (_selectedEventType != null && log.eventType != _selectedEventType) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 显示筛选对话框
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: _startDate,
        endDate: _endDate,
        selectedUser: _selectedUser,
        selectedPermission: _selectedPermission,
        selectedEventType: _selectedEventType,
        onApply: (startDate, endDate, user, permission, eventType) {
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
            _selectedUser = user;
            _selectedPermission = permission;
            _selectedEventType = eventType;
          });
          _loadAuditData();
        },
      ),
    );
  }

  /// 显示异常详情
  void _showAnomalyDetails(AnomalyDetection anomaly) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(anomaly.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(anomaly.description),
              const SizedBox(height: 16),
              _buildDetailRow('类型', anomaly.type.toString().split('.').last),
              const SizedBox(height: 8),
              _buildDetailRow('严重程度', anomaly.severity.toString().split('.').last),
              const SizedBox(height: 8),
              _buildDetailRow('检测时间', DateFormat('yyyy-MM-dd HH:mm').format(anomaly.detectedAt)),
              if (anomaly.affectedUsers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '影响用户：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...anomaly.affectedUsers.map((user) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $user'),
                )),
              ],
              if (anomaly.recommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '建议措施：',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...anomaly.recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $r'),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAnomaly(anomaly);
            },
            child: const Text('处理'),
          ),
        ],
      ),
    );
  }

  /// 处理异常
  void _handleAnomaly(AnomalyDetection anomaly) {
    // TODO: 实现异常处理逻辑
    _showMessage('正在处理异常...');
  }

  /// 导出审计报告
  void _exportAuditReport() {
    // TODO: 实现导出功能
    _showMessage('导出功能开发中');
  }

  /// 定时审计设置
  void _scheduleAutomaticAudit() {
    // TODO: 实现定时审计
    _showMessage('定时审计功能开发中');
  }

  /// 显示审计设置
  void _showAuditSettings() {
    // TODO: 实现审计设置
    _showMessage('审计设置功能开发中');
  }

  /// 获取事件颜色
  Color _getEventColor(AuditEventType type) {
    switch (type) {
      case AuditEventType.grant:
        return Colors.green;
      case AuditEventType.revoke:
        return Colors.red;
      case AuditEventType.modify:
        return Colors.orange;
      case AuditEventType.access:
        return Colors.blue;
      case AuditEventType.deny:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 获取事件图标
  IconData _getEventIcon(AuditEventType type) {
    switch (type) {
      case AuditEventType.grant:
        return Icons.add_circle;
      case AuditEventType.revoke:
        return Icons.remove_circle;
      case AuditEventType.modify:
        return Icons.edit;
      case AuditEventType.access:
        return Icons.login;
      case AuditEventType.deny:
        return Icons.block;
      default:
        return Icons.info;
    }
  }

  /// 获取严重程度颜色
  Color _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return Colors.red;
      case Severity.high:
        return Colors.orange;
      case Severity.medium:
        return Colors.yellow;
      case Severity.low:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// 获取严重程度图标
  IconData _getSeverityIcon(Severity severity) {
    switch (severity) {
      case Severity.critical:
        return Icons.error;
      case Severity.high:
        return Icons.warning;
      case Severity.medium:
        return Icons.info;
      case Severity.low:
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// 获取评分颜色
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  /// 获取评分标签
  String _getScoreLabel(double score) {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 60) return '合格';
    return '需改进';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// 模型类定义

/// 权限审计日志
class PermissionAuditLog {
  final String id;
  final AuditEventType eventType;
  final String description;
  final String performedBy;
  final String? targetUser;
  final List<String> permissions;
  final DateTime timestamp;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String? ipAddress;
  final Map<String, dynamic>? metadata;

  PermissionAuditLog({
    required this.id,
    required this.eventType,
    required this.description,
    required this.performedBy,
    this.targetUser,
    required this.permissions,
    required this.timestamp,
    this.oldValue,
    this.newValue,
    this.reason,
    this.ipAddress,
    this.metadata,
  });
}

/// 审计事件类型
enum AuditEventType {
  grant,    // 授予权限
  revoke,   // 撤销权限
  modify,   // 修改权限
  access,   // 访问权限
  deny,     // 拒绝访问
  delegate, // 委托权限
  expire,   // 权限过期
}

/// 权限使用统计
class PermissionUsageStats {
  final String permission;
  final int usageCount;
  final int uniqueUsers;
  final DateTime lastUsed;
  final double averageDaily;

  PermissionUsageStats({
    required this.permission,
    required this.usageCount,
    required this.uniqueUsers,
    required this.lastUsed,
    required this.averageDaily,
  });
}

/// 异常检测
class AnomalyDetection {
  final String id;
  final String title;
  final String description;
  final AnomalyType type;
  final Severity severity;
  final DateTime detectedAt;
  final List<String> affectedUsers;
  final List<String> recommendations;

  AnomalyDetection({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.severity,
    required this.detectedAt,
    required this.affectedUsers,
    required this.recommendations,
  });
}

/// 异常类型
enum AnomalyType {
  unusualAccess,      // 异常访问
  privilegeEscalation, // 权限提升
  excessiveUsage,     // 过度使用
  unauthorizedAttempt, // 未授权尝试
  suspiciousPattern,  // 可疑模式
}

/// 严重程度
enum Severity {
  critical,
  high,
  medium,
  low,
}

/// 合规报告
class ComplianceReport {
  final double score;
  final DateTime generatedAt;
  final List<ComplianceCheckItem> checkItems;
  final List<ComplianceIssue> issues;

  ComplianceReport({
    required this.score,
    required this.generatedAt,
    required this.checkItems,
    required this.issues,
  });
}

/// 合规检查项
class ComplianceCheckItem {
  final String name;
  final String description;
  final ComplianceStatus status;

  ComplianceCheckItem({
    required this.name,
    required this.description,
    required this.status,
  });
}

/// 合规状态
enum ComplianceStatus {
  passed,
  failed,
  warning,
}

/// 合规问题
class ComplianceIssue {
  final String title;
  final String description;
  final Severity severity;
  final String? recommendation;

  ComplianceIssue({
    required this.title,
    required this.description,
    required this.severity,
    this.recommendation,
  });
}

/// 筛选对话框
class _FilterDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedUser;
  final String? selectedPermission;
  final AuditEventType? selectedEventType;
  final Function(DateTime, DateTime, String?, String?, AuditEventType?) onApply;

  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    this.selectedUser,
    this.selectedPermission,
    this.selectedEventType,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedUser;
  String? _selectedPermission;
  AuditEventType? _selectedEventType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedUser = widget.selectedUser;
    _selectedPermission = widget.selectedPermission;
    _selectedEventType = widget.selectedEventType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('筛选条件'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 日期范围选择
            ListTile(
              title: const Text('开始日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('结束日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
            ),
            
            // 其他筛选条件
            // TODO: 实现用户、权限、事件类型的选择
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _startDate = DateTime.now().subtract(const Duration(days: 30));
              _endDate = DateTime.now();
              _selectedUser = null;
              _selectedPermission = null;
              _selectedEventType = null;
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
            Navigator.pop(context);
            widget.onApply(
              _startDate,
              _endDate,
              _selectedUser,
              _selectedPermission,
              _selectedEventType,
            );
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}
