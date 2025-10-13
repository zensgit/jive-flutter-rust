import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key});

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'Member';
  bool _isLoading = false;
  bool _showInviteResult = false;
  String _inviteCode = '';
  String _inviteLink = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // 生成邀请码
  String _generateInviteCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // 发送邀请
  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 模拟发送邀请请求
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // 生成邀请码和链接
      _inviteCode = _generateInviteCode();
      _inviteLink = 'https://jivemoney.com/invite/$_inviteCode';

      setState(() {
        _showInviteResult = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('邀请发送失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 复制邀请链接
  void _copyInviteLink() {
    Clipboard.setData(ClipboardData(text: _inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('邀请链接已复制到剪贴板'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 复制邀请邮件内容
  void _copyEmailContent() {
    final emailContent = _generateEmailContent();
    Clipboard.setData(ClipboardData(text: emailContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('邮件内容已复制，可以粘贴到邮件或聊天软件中'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 生成邀请邮件内容
  String _generateEmailContent() {
    const currentUser = 'superadmin'; // 获取当前用户名
    const familyName = 'Jive Money Family'; // 获取家庭名称

    return '''
🏠 Jive Money - 家庭财务管理邀请

您好！

$currentUser 邀请您加入 "$familyName" 家庭，一起管理家庭财务。

👤 邀请角色：$_selectedRole
🔑 邀请码：$_inviteCode
🔗 邀请链接：$_inviteLink

💡 如何加入：
1. 点击上方链接，或
2. 访问 https://jivemoney.com
3. 注册时输入邀请码：$_inviteCode

📱 Jive Money 帮您：
• 记录和分类每笔收支
• 设置预算并追踪花费
• 生成详细的财务报表
• 家庭成员协作管理财务
• 安全的数据加密存储

⏰ 此邀请7天内有效，请尽快注册。

如有问题，请联系邀请人：$currentUser

---
Jive Money - 集腋记账
让家庭财务管理更简单
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_showInviteResult) {
      return _buildInviteResultDialog();
    }

    return _buildInviteFormDialog();
  }

  Widget _buildInviteFormDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue[600]),
          const SizedBox(width: 8),
          const Text('邀请成员'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 邮箱输入框
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                hintText: '输入邀请用户的邮箱地址',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入邮箱地址';
                }
                if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                    .hasMatch(value)) {
                  return '请输入有效的邮箱地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 角色选择
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '成员角色',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedRole,
              items: const [
                DropdownMenuItem(
                    value: 'Admin', child: Text('管理员 (Admin) - 管理家庭和成员')),
                DropdownMenuItem(
                    value: 'Member', child: Text('成员 (Member) - 记录和查看交易')),
                DropdownMenuItem(
                    value: 'Viewer', child: Text('查看者 (Viewer) - 仅查看数据')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 说明文本
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Text(
                        '邀请说明',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '系统将生成邀请码和链接，您可以通过邮件或聊天软件分享给对方',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendInvite,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('发送邀请'),
        ),
      ],
    );
  }

  Widget _buildInviteResultDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功标题
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                const SizedBox(width: 12),
                const Text(
                  '邀请已生成',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 邀请信息卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '邀请信息',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('邮箱', _emailController.text),
                  _buildInfoRow('角色', _selectedRole),
                  _buildInfoRow('邀请码', _inviteCode),
                  const SizedBox(height: 8),
                  const Text(
                    '邀请链接:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _inviteLink,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 操作按钮
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyInviteLink,
                    icon: Icon(Icons.link),
                    label: Text('复制邀请链接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyEmailContent,
                    icon: Icon(Icons.email),
                    label: Text('复制邀请邮件内容'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('关闭'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '邀请码7天内有效，请及时通知被邀请人注册',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
