import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import '../screens/invitations/accept_invitation_screen.dart';
import '../screens/family/family_dashboard_screen.dart';
import '../models/ledger.dart';

/// 深链接服务 - 处理应用内外部链接跳转
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription? _linkSubscription;
  final _linkController = StreamController<DeepLinkData>.broadcast();

  Stream<DeepLinkData> get linkStream => _linkController.stream;

  /// 初始化深链接监听
  Future<void> initialize() async {
    // 处理应用启动时的链接
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // 监听应用运行时的链接
    _linkSubscription = linkStream.listen((link) {
      _handleDeepLink(link.url);
    }, onError: (err) {
      debugPrint('Link stream error: $err');
    });
  }

  /// 处理深链接
  void _handleDeepLink(String link) {
    final uri = Uri.parse(link);
    final data = _parseDeepLink(uri);

    if (data != null) {
      _linkController.add(data);
    }
  }

  /// 解析深链接
  DeepLinkData? _parseDeepLink(Uri uri) {
    // 支持的链接格式：
    // jivemoney://invite/{token}
    // https://jivemoney.app/invite/{token}
    // jivemoney://family/{familyId}
    // jivemoney://transaction/{transactionId}
    // jivemoney://share/{type}/{id}

    if (uri.scheme == 'jivemoney' || uri.host == 'jivemoney.app') {
      final pathSegments = uri.pathSegments;

      if (pathSegments.isEmpty) return null;

      switch (pathSegments[0]) {
        case 'invite':
          if (pathSegments.length > 1) {
            return DeepLinkData(
              type: DeepLinkType.invitation,
              data: {'token': pathSegments[1]},
              queryParams: uri.queryParameters,
            );
          }
          break;

        case 'family':
          if (pathSegments.length > 1) {
            return DeepLinkData(
              type: DeepLinkType.family,
              data: {'familyId': pathSegments[1]},
              queryParams: uri.queryParameters,
            );
          }
          break;

        case 'transaction':
          if (pathSegments.length > 1) {
            return DeepLinkData(
              type: DeepLinkType.transaction,
              data: {'transactionId': pathSegments[1]},
              queryParams: uri.queryParameters,
            );
          }
          break;

        case 'share':
          if (pathSegments.length > 2) {
            return DeepLinkData(
              type: DeepLinkType.share,
              data: {
                'shareType': pathSegments[1],
                'shareId': pathSegments[2],
              },
              queryParams: uri.queryParameters,
            );
          }
          break;

        case 'auth':
          if (pathSegments.length > 1) {
            return DeepLinkData(
              type: DeepLinkType.auth,
              data: {'action': pathSegments[1]},
              queryParams: uri.queryParameters,
            );
          }
          break;
      }
    }

    return null;
  }

  /// 导航到深链接目标
  static Future<void> navigateToDeepLink(
    BuildContext context,
    DeepLinkData data,
  ) async {
    switch (data.type) {
      case DeepLinkType.invitation:
        await _navigateToInvitation(context, data);
        break;

      case DeepLinkType.family:
        await _navigateToFamily(context, data);
        break;

      case DeepLinkType.transaction:
        await _navigateToTransaction(context, data);
        break;

      case DeepLinkType.share:
        await _navigateToShare(context, data);
        break;

      case DeepLinkType.auth:
        await _navigateToAuth(context, data);
        break;
    }
  }

  /// 导航到邀请页面
  static Future<void> _navigateToInvitation(
    BuildContext context,
    DeepLinkData data,
  ) async {
    final token = data.data['token'];
    if (token == null) return;

    // 检查是否已登录
    final isLoggedIn = await _checkLoginStatus();

    if (!isLoggedIn) {
      // 先导航到登录页面，登录后再处理邀请
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              pendingInviteToken: token,
            ),
          ),
          (route) => false,
        );
      }
    } else {
      // 直接导航到接受邀请页面
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AcceptInvitationScreen(
              inviteToken: token,
            ),
          ),
        );
      }
    }
  }

  /// 导航到家庭页面
  static Future<void> _navigateToFamily(
    BuildContext context,
    DeepLinkData data,
  ) async {
    final familyId = data.data['familyId'];
    if (familyId == null) return;

    final isLoggedIn = await _checkLoginStatus();

    if (!isLoggedIn) {
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      // TODO: 获取Family/Ledger信息
      final ledger = Ledger(
        id: familyId,
        name: 'Family',
        type: LedgerType.family,
        currency: 'CNY',
        isDefault: false,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyDashboardScreen(ledger: ledger),
          ),
        );
      }
    }
  }

  /// 导航到交易页面
  static Future<void> _navigateToTransaction(
    BuildContext context,
    DeepLinkData data,
  ) async {
    final transactionId = data.data['transactionId'];
    if (transactionId == null) return;

    final isLoggedIn = await _checkLoginStatus();

    if (!isLoggedIn) {
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      // TODO: 导航到交易详情页面
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/transaction/detail',
          arguments: transactionId,
        );
      }
    }
  }

  /// 导航到分享页面
  static Future<void> _navigateToShare(
    BuildContext context,
    DeepLinkData data,
  ) async {
    final shareType = data.data['shareType'];
    final shareId = data.data['shareId'];

    if (shareType == null || shareId == null) return;

    // 根据分享类型处理
    switch (shareType) {
      case 'statistics':
        // TODO: 导航到统计分享页面
        break;
      case 'report':
        // TODO: 导航到报告分享页面
        break;
      default:
        break;
    }
  }

  /// 导航到认证页面
  static Future<void> _navigateToAuth(
    BuildContext context,
    DeepLinkData data,
  ) async {
    final action = data.data['action'];

    switch (action) {
      case 'login':
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
        break;

      case 'register':
        if (context.mounted) {
          Navigator.pushNamed(context, '/auth/register');
        }
        break;

      case 'reset-password':
        final token = data.queryParams['token'];
        if (token != null && context.mounted) {
          Navigator.pushNamed(
            context,
            '/auth/reset-password',
            arguments: token,
          );
        }
        break;

      case 'verify-email':
        final token = data.queryParams['token'];
        if (token != null && context.mounted) {
          Navigator.pushNamed(
            context,
            '/auth/verify-email',
            arguments: token,
          );
        }
        break;
    }
  }

  /// 检查登录状态
  static Future<bool> _checkLoginStatus() async {
    // TODO: 实际检查登录状态
    // 这里应该检查本地存储的token是否有效
    return false;
  }

  /// 生成深链接
  static String generateDeepLink({
    required DeepLinkType type,
    required Map<String, String> data,
    Map<String, String>? queryParams,
    bool useHttps = true,
  }) {
    String baseUrl = useHttps ? 'https://jivemoney.app' : 'jivemoney://';

    String path = '';

    switch (type) {
      case DeepLinkType.invitation:
        path = 'invite/${data['token']}';
        break;

      case DeepLinkType.family:
        path = 'family/${data['familyId']}';
        break;

      case DeepLinkType.transaction:
        path = 'transaction/${data['transactionId']}';
        break;

      case DeepLinkType.share:
        path = 'share/${data['shareType']}/${data['shareId']}';
        break;

      case DeepLinkType.auth:
        path = 'auth/${data['action']}';
        break;
    }

    final uri = Uri.parse('$baseUrl/$path');

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams).toString();
    }

    return uri.toString();
  }

  /// 生成邀请链接
  static String generateInvitationLink(String token, {bool useHttps = true}) {
    return generateDeepLink(
      type: DeepLinkType.invitation,
      data: {'token': token},
      useHttps: useHttps,
    );
  }

  /// 生成家庭链接
  static String generateFamilyLink(String familyId, {bool useHttps = true}) {
    return generateDeepLink(
      type: DeepLinkType.family,
      data: {'familyId': familyId},
      useHttps: useHttps,
    );
  }

  /// 生成分享链接
  static String generateShareLink(
    String shareType,
    String shareId, {
    Map<String, String>? params,
    bool useHttps = true,
  }) {
    return generateDeepLink(
      type: DeepLinkType.share,
      data: {
        'shareType': shareType,
        'shareId': shareId,
      },
      queryParams: params,
      useHttps: useHttps,
    );
  }

  /// 释放资源
  void dispose() {
    _linkSubscription?.cancel();
    _linkController.close();
  }
}

/// 深链接数据
class DeepLinkData {
  final DeepLinkType type;
  final Map<String, String> data;
  final Map<String, String> queryParams;
  final String url;

  DeepLinkData({
    required this.type,
    required this.data,
    this.queryParams = const {},
    String? url,
  }) : url = url ?? '';
}

/// 深链接类型
enum DeepLinkType {
  invitation, // 邀请链接
  family, // 家庭链接
  transaction, // 交易链接
  share, // 分享链接
  auth, // 认证链接
}

/// 接受邀请页面（示例）
class AcceptInvitationScreen extends StatefulWidget {
  final String inviteToken;

  const AcceptInvitationScreen({
    Key? key,
    required this.inviteToken,
  }) : super(key: key);

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _invitationData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    // TODO: 调用API验证邀请token
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _invitationData = {
        'familyName': '示例家庭',
        'inviterName': '张三',
        'role': '成员',
        'expiresAt': DateTime.now().add(const Duration(days: 7)),
      };
    });
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isLoading = true);

    try {
      // TODO: 调用API接受邀请
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: const Text('成功加入家庭！')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                '邀请无效或已过期',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                _error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('接受邀请'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_add,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              '${_invitationData!['inviterName']} 邀请你加入',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              _invitationData!['familyName'],
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('角色', _invitationData!['role']),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    '有效期',
                    '${(_invitationData!['expiresAt'] as DateTime).difference(DateTime.now()).inDays} 天',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acceptInvitation,
                    child: const Text('接受邀请'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(label),
        const Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 登录页面（示例）
class LoginScreen extends StatelessWidget {
  final String? pendingInviteToken;

  const LoginScreen({
    Key? key,
    this.pendingInviteToken,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (pendingInviteToken != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '登录后将自动处理邀请',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            const Text('登录页面'),
          ],
        ),
      ),
    );
  }
}
