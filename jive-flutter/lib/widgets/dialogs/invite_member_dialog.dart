import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ledger.dart';
import '../../providers/ledger_provider.dart';
import '../../utils/string_utils.dart';

/// 邀请成员对话框
class InviteMemberDialog extends ConsumerStatefulWidget {
  final Ledger ledger;

  const InviteMemberDialog({
    super.key,
    required this.ledger,
  });

  @override
  ConsumerState<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends ConsumerState<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final List<String> _emailList = [];

  LedgerRole _selectedRole = LedgerRole.viewer;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && _isValidEmail(email)) {
      if (!_emailList.contains(email)) {
        setState(() {
          _emailList.add(email);
          _emailController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('该邮箱已添加'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _emailList.remove(email);
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _inviteMembers() async {
    if (_emailList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少添加一个邮箱'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(ledgerServiceProvider);

      // 邀请成员
      await service.shareLedger(widget.ledger.id!, _emailList);

      // TODO: 设置成员角色（需要后端API支持）
      // for (final email in _emailList) {
      //   await service.updateMemberRole(widget.ledger.id!, email, _selectedRole);
      // }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功邀请 ${_emailList.length} 位成员'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('邀请失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: theme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '邀请成员',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '邀请加入: ${widget.ledger.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 表单内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 邮箱输入
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: '邮箱地址',
                                hintText: '输入邮箱地址',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onFieldSubmitted: (_) => _addEmail(),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!_isValidEmail(value)) {
                                    return '请输入有效的邮箱地址';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _addEmail();
                              }
                            },
                            icon: Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 已添加的邮箱列表
                      if (_emailList.isNotEmpty) ...[
                        Text(
                          '待邀请成员 (${_emailList.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _emailList.length,
                            itemBuilder: (context, index) {
                              final email = _emailList[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      theme.primaryColor.withValues(alpha: 0.1),
                                  child: Text(
                                    StringUtils.safeInitial(email),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                                title: Text(email),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, size: 18),
                                  onPressed: () => _removeEmail(email),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 角色选择
                      DropdownButtonFormField<LedgerRole>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: '成员角色',
                          prefixIcon: Icon(Icons.security),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: LedgerRole.viewer,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('观察者 (Viewer)'),
                                Text(
                                  '只能查看，不能修改',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: LedgerRole.editor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('编辑者 (Editor)'),
                                Text(
                                  '可以记账和编辑',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: LedgerRole.admin,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('管理员 (Admin)'),
                                Text(
                                  '可以管理成员和设置',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 权限说明
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '角色权限说明',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildPermissionRow(
                                '查看账本', [true, true, true, true]),
                            _buildPermissionRow(
                                '记录交易', [false, false, true, true]),
                            _buildPermissionRow(
                                '编辑账户', [false, false, true, true]),
                            _buildPermissionRow(
                                '邀请成员', [false, true, true, false]),
                            _buildPermissionRow(
                                '删除账本', [true, false, false, false]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 按钮栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _inviteMembers,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send),
                    label: Text(_isLoading ? '发送中...' : '发送邀请'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildPermissionRow(String permission, List<bool> roles) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              permission,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ...['Owner', 'Admin', 'Editor', 'Viewer']
              .asMap()
              .entries
              .map((entry) {
            final hasPermission = roles[entry.key];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                hasPermission ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: hasPermission ? Colors.green : Colors.grey[400],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
