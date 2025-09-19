import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// AI助理页面
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 添加欢迎消息
    _messages.add({
      'isUser': false,
      'content':
          '你好！我是集腋记账的AI助理，可以帮助您：\n\n• 分析财务数据\n• 制定理财计划\n• 回答记账相关问题\n• 提供智能建议\n\n有什么可以帮助您的吗？',
      'timestamp': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'content': message,
        'timestamp': DateTime.now(),
      });
      _isLoading = true;
    });

    _messageController.clear();

    // 模拟AI回复
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _messages.add({
          'isUser': false,
          'content': _generateAIResponse(message),
          'timestamp': DateTime.now(),
        });
        _isLoading = false;
      });
    });
  }

  String _generateAIResponse(String userMessage) {
    // 简单的关键词回复逻辑
    final msg = userMessage.toLowerCase();

    if (msg.contains('预算') || msg.contains('budget')) {
      return '根据您的消费记录，我建议您：\n\n1. 设定月度预算目标\n2. 按类别分配预算（如餐饮30%，交通15%等）\n3. 使用预算追踪功能监控支出\n4. 每月检查并调整预算计划\n\n需要我帮您制定具体的预算方案吗？';
    } else if (msg.contains('投资') || msg.contains('理财')) {
      return '关于投资理财，我建议您：\n\n1. 建立应急资金（3-6个月生活费）\n2. 了解自己的风险承受能力\n3. 考虑分散投资组合\n4. 定期定投可以降低风险\n\n请注意，投资有风险，建议咨询专业理财顾问。';
    } else if (msg.contains('消费') || msg.contains('支出')) {
      return '从您的消费模式来看：\n\n• 建议设定每日支出提醒\n• 区分必要和非必要支出\n• 考虑使用信封预算法\n• 定期回顾消费习惯\n\n要不要查看您的消费分析报告？';
    } else if (msg.contains('收入') || msg.contains('赚钱')) {
      return '提升收入的建议：\n\n1. 技能提升和学习投资\n2. 开发副业或兼职机会\n3. 优化现有工作效率\n4. 考虑被动收入来源\n\n记住，开源节流同样重要！';
    }

    return '谢谢您的问题！我正在学习更多财务知识来更好地帮助您。\n\n您可以问我关于：\n• 预算制定\n• 消费分析\n• 理财建议\n• 记账技巧\n\n还有什么其他问题吗？';
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final content = message['content'] as String;
    final timestamp = message['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SvgPicture.asset(
                'assets/images/Jiva.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Text(
                '我',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 自定义顶部栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back),
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/images/Jiva.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI助理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // 显示加载指示器
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: SvgPicture.asset(
                              'assets/images/Jiva.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('正在思考...'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: '输入您的问题...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: Icon(Icons.send, color: Colors.white),
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
}
