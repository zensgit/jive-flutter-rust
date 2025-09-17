import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:collection';
import 'dart:async';
import '../models/family.dart' as family_model;
import '../models/transaction.dart';
import 'api/family_service.dart';

/// 邮件通知服务
class EmailNotificationService extends ChangeNotifier {
  static EmailNotificationService? _instance;

  // SMTP配置
  late SmtpServer _smtpServer;
  bool _isConfigured = false;

  // 邮件队列
  final Queue<EmailMessage> _emailQueue = Queue();
  bool _isProcessing = false;
  Timer? _processTimer;

  // 邮件模板
  final Map<EmailTemplate, String> _templates = {};

  // 批量发送配置
  static const int _batchSize = 50;
  static const Duration _batchDelay = Duration(seconds: 2);

  // 退订管理
  final Set<String> _unsubscribedEmails = {};

  // 发送统计
  int _sentCount = 0;
  int _failedCount = 0;
  final List<EmailLog> _logs = [];

  EmailNotificationService._();

  factory EmailNotificationService() {
    _instance ??= EmailNotificationService._();
    return _instance!;
  }

  bool get isConfigured => _isConfigured;
  int get pendingEmailsCount => _emailQueue.length;
  int get sentEmailsCount => _sentCount;
  int get failedEmailsCount => _failedCount;
  List<EmailLog> get recentLogs => _logs.take(100).toList();

  /// 配置SMTP服务器
  Future<void> configureSMTP({
    required String host,
    required int port,
    required String username,
    required String password,
    bool ssl = true,
    bool allowInsecure = false,
  }) async {
    try {
      _smtpServer = SmtpServer(
        host,
        port: port,
        username: username,
        password: password,
        ssl: ssl,
        allowInsecure: allowInsecure,
      );

      _isConfigured = true;
      _initializeTemplates();
      _startProcessingQueue();

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to configure SMTP: $e');
      _isConfigured = false;
      throw e;
    }
  }

  /// 配置使用Gmail
  void configureGmail(String username, String password) {
    _smtpServer = gmail(username, password);
    _isConfigured = true;
    _initializeTemplates();
    _startProcessingQueue();
    notifyListeners();
  }

  /// 配置使用Outlook
  void configureOutlook(String username, String password) {
    _smtpServer = SmtpServer(
      'smtp-mail.outlook.com',
      port: 587,
      username: username,
      password: password,
    );
    _isConfigured = true;
    _initializeTemplates();
    _startProcessingQueue();
    notifyListeners();
  }

  /// 初始化邮件模板
  void _initializeTemplates() {
    _templates[EmailTemplate.invitation] = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
    .content { background: white; padding: 30px; border: 1px solid #e0e0e0; border-radius: 0 0 10px 10px; }
    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { text-align: center; color: #666; font-size: 12px; margin-top: 30px; }
    .code-box { background: #f5f5f5; padding: 15px; border-radius: 5px; font-size: 24px; font-weight: bold; text-align: center; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🏠 邀请你加入家庭账本</h1>
    </div>
    <div class="content">
      <p>你好，</p>
      <p><strong>{{inviterName}}</strong> 邀请你加入家庭账本 <strong>「{{familyName}}」</strong>。</p>
      
      <div class="code-box">
        邀请码：{{inviteCode}}
      </div>
      
      <p>📅 有效期至：{{expiresAt}}</p>
      <p>👤 你的角色：{{role}}</p>
      
      <a href="{{inviteLink}}" class="button">立即加入</a>
      
      <p>或者在应用中输入邀请码：<strong>{{inviteCode}}</strong></p>
      
      <div class="footer">
        <p>此邮件由 Jive Money 系统自动发送，请勿回复。</p>
        <p>如果你不想接收此类邮件，请点击 <a href="{{unsubscribeLink}}">退订</a></p>
      </div>
    </div>
  </div>
</body>
</html>
''';

    _templates[EmailTemplate.weeklyReport] = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
    .content { background: white; padding: 30px; border: 1px solid #e0e0e0; border-radius: 0 0 10px 10px; }
    .stat-box { display: inline-block; padding: 20px; margin: 10px; background: #f8f9fa; border-radius: 8px; text-align: center; }
    .stat-value { font-size: 28px; font-weight: bold; color: #667eea; }
    .stat-label { font-size: 14px; color: #666; margin-top: 5px; }
    .progress-bar { background: #e0e0e0; height: 20px; border-radius: 10px; overflow: hidden; margin: 20px 0; }
    .progress-fill { background: linear-gradient(90deg, #667eea, #764ba2); height: 100%; transition: width 0.3s; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>📊 {{familyName}} 周报</h1>
      <p>{{dateRange}}</p>
    </div>
    <div class="content">
      <h2>本周概览</h2>
      
      <div style="text-align: center;">
        <div class="stat-box">
          <div class="stat-value">¥{{totalIncome}}</div>
          <div class="stat-label">总收入</div>
        </div>
        <div class="stat-box">
          <div class="stat-value">¥{{totalExpense}}</div>
          <div class="stat-label">总支出</div>
        </div>
        <div class="stat-box">
          <div class="stat-value">¥{{balance}}</div>
          <div class="stat-label">结余</div>
        </div>
      </div>
      
      <h3>预算执行情况</h3>
      <div class="progress-bar">
        <div class="progress-fill" style="width: {{budgetPercentage}}%"></div>
      </div>
      <p>已使用预算：{{budgetPercentage}}%</p>
      
      <h3>支出分类 TOP 5</h3>
      <ol>
        {{categoryList}}
      </ol>
      
      <h3>活跃成员</h3>
      <p>{{activeMembersList}}</p>
      
      <div class="footer">
        <p>查看完整报告，请登录 Jive Money 应用。</p>
        <p>退订周报，请点击 <a href="{{unsubscribeLink}}">退订</a></p>
      </div>
    </div>
  </div>
</body>
</html>
''';

    _templates[EmailTemplate.budgetAlert] = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
    .content { background: white; padding: 30px; border: 1px solid #e0e0e0; border-radius: 0 0 10px 10px; }
    .alert-box { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚠️ 预算提醒</h1>
    </div>
    <div class="content">
      <div class="alert-box">
        <strong>{{familyName}}</strong> 的 <strong>{{categoryName}}</strong> 分类预算即将超支！
      </div>
      
      <h3>预算详情</h3>
      <ul>
        <li>预算金额：{{budgetAmountFormatted}}</li>
        <li>已使用：¥{{usedAmount}}</li>
        <li>剩余：¥{{remainingAmount}}</li>
        <li>使用率：{{usagePercentage}}%</li>
      </ul>
      
      <p>{{alertMessage}}</p>
      
      <a href="{{viewDetailsLink}}" class="button">查看详情</a>
      
      <div class="footer">
        <p>此邮件由 Jive Money 系统自动发送。</p>
        <p>管理通知设置，请点击 <a href="{{settingsLink}}">设置</a></p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// 发送家庭邀请邮件
  Future<void> sendInvitationEmail({
    required String toEmail,
    required String inviterName,
    required String familyName,
    required String inviteCode,
    required String inviteLink,
    required family_model.FamilyRole role,
    required DateTime expiresAt,
  }) async {
    if (!_isConfigured) {
      throw Exception('Email service not configured');
    }

    if (_unsubscribedEmails.contains(toEmail.toLowerCase())) {
      debugPrint('Email $toEmail has unsubscribed');
      return;
    }

    final html = _renderTemplate(EmailTemplate.invitation, {
      'inviterName': inviterName,
      'familyName': familyName,
      'inviteCode': inviteCode,
      'inviteLink': inviteLink,
      'role': _getRoleDisplayName(role),
      'expiresAt': _formatDate(expiresAt),
      'unsubscribeLink': _generateUnsubscribeLink(toEmail),
    });

    _queueEmail(EmailMessage(
      to: toEmail,
      subject: '$inviterName 邀请你加入家庭账本「$familyName」',
      html: html,
      type: EmailType.invitation,
      metadata: {
        'familyName': familyName,
        'inviteCode': inviteCode,
      },
    ));
  }

  /// 发送周报邮件
  Future<void> sendWeeklyReport({
    required String toEmail,
    required String familyName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalIncome,
    required double totalExpense,
    required double budgetUsage,
    required List<CategoryUsage> topCategories,
    required List<String> activeMembers,
  }) async {
    if (!_isConfigured) return;
    if (_unsubscribedEmails.contains(toEmail.toLowerCase())) return;

    final balance = totalIncome - totalExpense;
    final categoryList = topCategories
        .map((c) => '<li>${c.name}: ¥${c.amount.toStringAsFixed(2)}</li>')
        .join('\n');
    final membersList = activeMembers.join('、');

    final html = _renderTemplate(EmailTemplate.weeklyReport, {
      'familyName': familyName,
      'dateRange': '${_formatDate(startDate)} - ${_formatDate(endDate)}',
      'totalIncome': totalIncome.toStringAsFixed(2),
      'totalExpense': totalExpense.toStringAsFixed(2),
      'balance': balance.toStringAsFixed(2),
      'budgetPercentage': budgetUsage.toStringAsFixed(0),
      'categoryList': categoryList,
      'activeMembersList': membersList,
      'unsubscribeLink': _generateUnsubscribeLink(toEmail),
    });

    _queueEmail(EmailMessage(
      to: toEmail,
      subject:
          '$familyName 周报 (${_formatDate(startDate)} - ${_formatDate(endDate)})',
      html: html,
      type: EmailType.weeklyReport,
      metadata: {
        'familyName': familyName,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    ));
  }

  /// 发送预算提醒邮件
  Future<void> sendBudgetAlert({
    required String toEmail,
    required String familyName,
    required String categoryName,
    required double budgetAmount,
    required double usedAmount,
    required String alertMessage,
  }) async {
    if (!_isConfigured) return;
    if (_unsubscribedEmails.contains(toEmail.toLowerCase())) return;

    final remainingAmount = budgetAmount - usedAmount;
    final usagePercentage = (usedAmount / budgetAmount * 100);

    final html = _renderTemplate(EmailTemplate.budgetAlert, {
      'familyName': familyName,
      'categoryName': categoryName,
      'budgetAmount': budgetAmount.toStringAsFixed(2),
      'usedAmount': usedAmount.toStringAsFixed(2),
      'remainingAmount': remainingAmount.toStringAsFixed(2),
      'usagePercentage': usagePercentage.toStringAsFixed(0),
      'alertMessage': alertMessage,
      'viewDetailsLink': 'jivemoney://family/$familyName/budget',
      'settingsLink': 'jivemoney://settings/notifications',
    });

    _queueEmail(EmailMessage(
      to: toEmail,
      subject: '⚠️ 预算提醒：$categoryName 即将超支',
      html: html,
      type: EmailType.budgetAlert,
      priority: EmailPriority.high,
      metadata: {
        'familyName': familyName,
        'categoryName': categoryName,
        'usagePercentage': usagePercentage,
      },
    ));
  }

  /// 批量发送邮件
  Future<void> sendBulkEmails({
    required List<String> recipients,
    required String subject,
    required String htmlContent,
    EmailType type = EmailType.custom,
    Map<String, String>? personalizations,
  }) async {
    if (!_isConfigured) return;

    // 过滤退订用户
    final validRecipients = recipients
        .where((email) => !_unsubscribedEmails.contains(email.toLowerCase()))
        .toList();

    // 分批处理
    for (var i = 0; i < validRecipients.length; i += _batchSize) {
      final batch = validRecipients.skip(i).take(_batchSize).toList();

      for (final email in batch) {
        var personalizedHtml = htmlContent;

        // 应用个性化
        if (personalizations != null && personalizations.containsKey(email)) {
          personalizedHtml = personalizedHtml.replaceAll(
            '{{name}}',
            personalizations[email]!,
          );
        }

        _queueEmail(EmailMessage(
          to: email,
          subject: subject,
          html: personalizedHtml,
          type: type,
        ));
      }

      // 批次间延迟
      if (i + _batchSize < validRecipients.length) {
        await Future.delayed(_batchDelay);
      }
    }
  }

  /// 添加邮件到队列
  void _queueEmail(EmailMessage email) {
    _emailQueue.add(email);
    notifyListeners();
  }

  /// 开始处理队列
  void _startProcessingQueue() {
    if (_processTimer != null) return;

    _processTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _processEmailQueue();
    });
  }

  /// 处理邮件队列
  Future<void> _processEmailQueue() async {
    if (_isProcessing || _emailQueue.isEmpty) return;

    _isProcessing = true;

    while (_emailQueue.isNotEmpty) {
      final email = _emailQueue.removeFirst();

      try {
        await _sendEmail(email);
        _sentCount++;
        _logEmail(email, EmailStatus.sent);
      } catch (e) {
        _failedCount++;
        _logEmail(email, EmailStatus.failed, error: e.toString());

        // 重试高优先级邮件
        if (email.priority == EmailPriority.high && email.retryCount < 3) {
          email.retryCount++;
          _emailQueue.add(email);
        }
      }

      notifyListeners();

      // 发送间隔
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isProcessing = false;
  }

  /// 发送单个邮件
  Future<void> _sendEmail(EmailMessage email) async {
    final message = Message()
      ..from = const Address('noreply@jivemoney.com', 'Jive Money')
      ..recipients.add(email.to)
      ..subject = email.subject
      ..html = email.html;

    await send(message, _smtpServer);
  }

  /// 渲染模板
  String _renderTemplate(
      EmailTemplate template, Map<String, String> variables) {
    var html = _templates[template] ?? '';

    variables.forEach((key, value) {
      html = html.replaceAll('{{$key}}', value);
    });

    return html;
  }

  /// 记录邮件日志
  void _logEmail(EmailMessage email, EmailStatus status, {String? error}) {
    _logs.insert(
        0,
        EmailLog(
          to: email.to,
          subject: email.subject,
          type: email.type,
          status: status,
          timestamp: DateTime.now(),
          error: error,
          metadata: email.metadata,
        ));

    // 保持日志数量
    if (_logs.length > 1000) {
      _logs.removeRange(1000, _logs.length);
    }
  }

  /// 处理退订
  void unsubscribe(String email) {
    _unsubscribedEmails.add(email.toLowerCase());
    notifyListeners();
  }

  /// 重新订阅
  void resubscribe(String email) {
    _unsubscribedEmails.remove(email.toLowerCase());
    notifyListeners();
  }

  /// 检查是否已退订
  bool isUnsubscribed(String email) {
    return _unsubscribedEmails.contains(email.toLowerCase());
  }

  /// 生成退订链接
  String _generateUnsubscribeLink(String email) {
    final encodedEmail = Uri.encodeComponent(email);
    return 'https://jivemoney.com/unsubscribe?email=$encodedEmail';
  }

  /// 获取角色显示名称
  String _getRoleDisplayName(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return '拥有者';
      case family_model.FamilyRole.admin:
        return '管理员';
      case family_model.FamilyRole.member:
        return '成员';
      case family_model.FamilyRole.viewer:
        return '观察者';
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 清理资源
  void dispose() {
    _processTimer?.cancel();
    super.dispose();
  }
}

/// 邮件消息
class EmailMessage {
  final String to;
  final String subject;
  final String html;
  final EmailType type;
  final EmailPriority priority;
  final Map<String, dynamic>? metadata;
  int retryCount;

  EmailMessage({
    required this.to,
    required this.subject,
    required this.html,
    required this.type,
    this.priority = EmailPriority.normal,
    this.metadata,
    this.retryCount = 0,
  });
}

/// 邮件类型
enum EmailType {
  invitation,
  weeklyReport,
  monthlyReport,
  budgetAlert,
  transactionNotification,
  memberActivity,
  systemNotification,
  custom,
}

/// 邮件优先级
enum EmailPriority {
  low,
  normal,
  high,
}

/// 邮件模板
enum EmailTemplate {
  invitation,
  weeklyReport,
  monthlyReport,
  budgetAlert,
  transactionNotification,
  memberJoined,
  memberLeft,
  passwordReset,
  accountVerification,
}

/// 邮件状态
enum EmailStatus {
  pending,
  sent,
  failed,
  bounced,
}

/// 邮件日志
class EmailLog {
  final String to;
  final String subject;
  final EmailType type;
  final EmailStatus status;
  final DateTime timestamp;
  final String? error;
  final Map<String, dynamic>? metadata;

  EmailLog({
    required this.to,
    required this.subject,
    required this.type,
    required this.status,
    required this.timestamp,
    this.error,
    this.metadata,
  });
}

/// 分类使用情况
class CategoryUsage {
  final String name;
  final double amount;

  CategoryUsage({required this.name, required this.amount});
}
