import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/family.dart' as family_model;
import '../models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/currency_provider.dart';

/// 分享服务
class ShareService {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  /// 分享家庭邀请
  static Future<void> shareFamilyInvitation({
    required BuildContext context,
    required String familyName,
    required String inviteCode,
    required String inviteLink,
    required family_model.FamilyRole role,
    required DateTime expiresAt,
  }) async {
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;

    final shareText = '''
🏠 邀请你加入家庭账本「$familyName」

📱 使用 Jive Money 一起管理家庭财务
让记账变得简单有趣！

🔑 邀请码：$inviteCode
👤 角色：${_getRoleDisplayName(role)}
⏰ 有效期：$daysLeft 天

点击链接加入 👇
$inviteLink

━━━━━━━━━━━━━━━━
Jive Money - 您的智能家庭财务管家
''';

    try {
      await Share.share(
        shareText,
        subject: '邀请你加入家庭「$familyName」',
      );
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 分享统计报告
  static Future<void> shareStatisticsReport({
    required BuildContext context,
    required String familyName,
    required String period,
    required double income,
    required double expense,
    required double balance,
    required Widget? chartWidget,
  }) async {
    // Use currency provider to format amounts consistently
    final container = ProviderScope.containerOf(context, listen: false);
    final base = container.read(baseCurrencyProvider).code;
    final formatter = container.read(currencyProvider.notifier);
    final incomeStr = formatter.formatCurrency(income, base);
    final expenseStr = formatter.formatCurrency(expense, base);
    final balanceStr = formatter.formatCurrency(balance, base);

    String shareText = '''
📊 $familyName - $period 财务报告

💰 收入：$incomeStr
💸 支出：$expenseStr
💎 结余：$balanceStr
📈 储蓄率：${((balance / income) * 100).toStringAsFixed(1)}%

━━━━━━━━━━━━━━━━
由 Jive Money 生成
''';

    try {
      if (chartWidget != null) {
        // 生成图表截图
        final image = await _screenshotController.captureFromWidget(
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$familyName - $period',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                chartWidget,
                const SizedBox(height: 20),
                const Text(
                  'Powered by Jive Money',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );

        // 保存图片
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/statistics_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(image);

        // 分享图片和文字
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: shareText,
        );
      } else {
        // 仅分享文字
        await Share.share(shareText);
      }
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 分享交易详情
  static Future<void> shareTransaction({
    required BuildContext context,
    required Transaction transaction,
    required String familyName,
  }) async {
    final icon = transaction.type == TransactionType.income ? '💰' : '💸';
    final typeText = transaction.type == TransactionType.income ? '收入' : '支出';
    final container = ProviderScope.containerOf(context, listen: false);
    final base = container.read(baseCurrencyProvider).code;
    final formatter = container.read(currencyProvider.notifier);
    final amountStr = formatter.formatCurrency(transaction.amount, base);

    final shareText = '''
$icon $typeText记录

📝 ${transaction.description}
💵 金额：$amountStr
📂 分类：${transaction.categoryName}
📅 日期：${_formatDate(transaction.date)}
🏠 账本：$familyName

${transaction.tags.isNotEmpty ? '🏷️ 标签：${transaction.tags.join(', ')}' : ''}
${transaction.note?.isNotEmpty == true ? '📝 备注：${transaction.note}' : ''}

━━━━━━━━━━━━━━━━
由 Jive Money 记录
''';

    try {
      await Share.share(shareText);
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 复制到剪贴板
  static Future<void> copyToClipboard({
    required BuildContext context,
    required String text,
    String? message,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? '已复制到剪贴板'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError(context, '复制失败: $e');
    }
  }

  /// 分享到特定平台
  static Future<void> shareToSocialMedia({
    required BuildContext context,
    required String text,
    required SocialPlatform platform,
    String? url,
    List<String>? hashtags,
  }) async {
    String shareContent = text;

    // 添加话题标签
    if (hashtags != null && hashtags.isNotEmpty) {
      shareContent += '\n\n${hashtags.map((tag) => '#$tag').join(' ')}';
    }

    // 添加链接
    if (url != null) {
      shareContent += '\n\n$url';
    }

    try {
      // 根据平台定制分享内容
      switch (platform) {
        case SocialPlatform.wechat:
          // 微信分享需要特殊处理
          await _shareToWechat(context, shareContent);
          break;

        case SocialPlatform.weibo:
          // 微博分享
          final weiboUrl = Uri.encodeFull(
            'https://service.weibo.com/share/share.php?title=$shareContent',
          );
          await Share.share(shareContent);
          break;

        case SocialPlatform.qq:
          // QQ分享
          await Share.share(shareContent);
          break;

        default:
          await Share.share(shareContent);
      }
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 分享二维码图片
  static Future<void> shareQrCode({
    required BuildContext context,
    required String data,
    required String title,
    String? description,
  }) async {
    try {
      // 这里应该生成二维码图片
      // 暂时使用文本分享
      final shareText = '''
$title
${description ?? ''}

扫描二维码或访问：
$data
''';

      await Share.share(shareText);
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 分享文件
  static Future<void> shareFile({
    required BuildContext context,
    required File file,
    String? text,
    String? mimeType,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        text: text,
      );
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 批量分享图片
  static Future<void> shareImages({
    required BuildContext context,
    required List<File> images,
    String? text,
  }) async {
    try {
      final xFiles = images.map((file) => XFile(file.path)).toList();
      await Share.shareXFiles(xFiles, text: text);
    } catch (e) {
      _showError(context, '分享失败: $e');
    }
  }

  /// 分享到微信（需要集成微信SDK）
  static Future<void> _shareToWechat(
      BuildContext context, String content) async {
    // TODO: 集成微信SDK后实现
    // 暂时使用系统分享
    await Share.share(content);
  }

  static String _getRoleDisplayName(family_model.FamilyRole role) {
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

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// 社交平台
enum SocialPlatform {
  wechat,
  weibo,
  qq,
  twitter,
  facebook,
  instagram,
  other,
}

/// 分享对话框
class ShareDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? url;
  final VoidCallback? onCopy;
  final VoidCallback? onShareWechat;
  final VoidCallback? onShareWeibo;
  final VoidCallback? onShareQQ;
  final VoidCallback? onShareMore;

  const ShareDialog({
    Key? key,
    required this.title,
    required this.content,
    this.url,
    this.onCopy,
    this.onShareWechat,
    this.onShareWeibo,
    this.onShareQQ,
    this.onShareMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 内容预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (url != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        url!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: onCopy ??
                          () {
                            ShareService.copyToClipboard(
                              context: context,
                              text: url!,
                              message: '链接已复制',
                            );
                          },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 分享平台
            Text(
              '分享到',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SharePlatformButton(
                  icon: Icons.wechat,
                  label: '微信',
                  color: const Color(0xFF07C160),
                  onPressed: onShareWechat ??
                      () {
                        ShareService.shareToSocialMedia(
                          context: context,
                          text: content,
                          platform: SocialPlatform.wechat,
                          url: url,
                        );
                        Navigator.pop(context);
                      },
                ),
                _SharePlatformButton(
                  icon: Icons.wb_sunny,
                  label: '微博',
                  color: const Color(0xFFE6162D),
                  onPressed: onShareWeibo ??
                      () {
                        ShareService.shareToSocialMedia(
                          context: context,
                          text: content,
                          platform: SocialPlatform.weibo,
                          url: url,
                        );
                        Navigator.pop(context);
                      },
                ),
                _SharePlatformButton(
                  icon: Icons.chat_bubble,
                  label: 'QQ',
                  color: const Color(0xFF12B7F5),
                  onPressed: onShareQQ ??
                      () {
                        ShareService.shareToSocialMedia(
                          context: context,
                          text: content,
                          platform: SocialPlatform.qq,
                          url: url,
                        );
                        Navigator.pop(context);
                      },
                ),
                _SharePlatformButton(
                  icon: Icons.more_horiz,
                  label: '更多',
                  color: theme.colorScheme.primary,
                  onPressed: onShareMore ??
                      () async {
                        await Share.share('$content\n\n$url');
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 取消按钮
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分享平台按钮
class _SharePlatformButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SharePlatformButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
