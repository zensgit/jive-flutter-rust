import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket服务 - 提供实时数据更新
class WebSocketService {
  static const String wsUrl = 'ws://localhost:8012/ws';

  WebSocketChannel? _channel;
  StreamController<WsMessage>? _messageController;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _token;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // 消息流
  Stream<WsMessage> get messages =>
      _messageController?.stream ?? const Stream.empty();

  // 连接状态
  bool get isConnected => _isConnected;

  /// 连接WebSocket
  Future<void> connect(String token) async {
    _token = token;
    _messageController ??= StreamController<WsMessage>.broadcast();

    try {
      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // 监听消息
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();

      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    _isConnected = false;
    _stopHeartbeat();
    _stopReconnect();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
  }

  /// 订阅主题
  void subscribe(String topic) {
    _sendCommand(WsCommand.subscribe(topic));
  }

  /// 取消订阅
  void unsubscribe(String topic) {
    _sendCommand(WsCommand.unsubscribe(topic));
  }

  /// 请求数据
  void requestData(String resource, Map<String, dynamic> params) {
    _sendCommand(WsCommand.request(resource, params));
  }

  /// 发送命令
  void _sendCommand(WsCommand command) {
    if (!_isConnected || _channel == null) {
      debugPrint('WebSocket not connected');
      return;
    }

    try {
      final json = jsonEncode(command.toJson());
      _channel!.sink.add(json);
    } catch (e) {
      debugPrint('Failed to send command: $e');
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final message = WsMessage.fromJson(json);
      _messageController?.add(message);

      // 处理特殊消息
      if (message.type == 'Ping') {
        _sendCommand(WsCommand.ping());
      }
    } catch (e) {
      debugPrint('Failed to parse message: $e');
    }
  }

  /// 处理错误
  void _handleError(error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// 处理连接断开
  void _handleDone() {
    debugPrint('WebSocket connection closed');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// 开始心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendCommand(WsCommand.ping()),
    );
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _stopReconnect();
    _reconnectAttempts++;

    final delay = Duration(seconds: _reconnectAttempts * 2);
    debugPrint('Reconnecting in ${delay.inSeconds} seconds...');

    _reconnectTimer = Timer(delay, () {
      if (_token != null) {
        connect(_token!);
      }
    });
  }

  /// 停止重连
  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 清理资源
  void dispose() {
    disconnect();
    _messageController?.close();
    _messageController = null;
  }
}

/// WebSocket消息
class WsMessage {
  final String type;
  final Map<String, dynamic>? data;

  WsMessage({required this.type, this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (data != null) 'data': data,
      };

  // 便捷构造函数
  bool get isConnected => type == 'Connected';
  bool get isTransactionUpdate => type == 'TransactionUpdate';
  bool get isAccountBalanceUpdate => type == 'AccountBalanceUpdate';
  bool get isNotification => type == 'Notification';
  bool get isError => type == 'Error';

  // 获取特定数据
  String? get transactionId => data?['transaction_id'] as String?;
  String? get accountId => data?['account_id'] as String?;
  double? get balance => data?['balance'] as double?;
  String? get errorMessage => data?['message'] as String?;
}

/// WebSocket命令
class WsCommand {
  final String command;
  final Map<String, dynamic>? data;

  WsCommand({required this.command, this.data});

  Map<String, dynamic> toJson() => {
        'command': command,
        if (data != null) 'data': data,
      };

  // 便捷构造函数
  static WsCommand subscribe(String topic) => WsCommand(
        command: 'Subscribe',
        data: {'topic': topic},
      );

  static WsCommand unsubscribe(String topic) => WsCommand(
        command: 'Unsubscribe',
        data: {'topic': topic},
      );

  static WsCommand ping() => WsCommand(command: 'Ping');

  static WsCommand request(String resource, Map<String, dynamic> params) =>
      WsCommand(
        command: 'Request',
        data: {'resource': resource, 'params': params},
      );
}

/// WebSocket消息处理Mixin
mixin WebSocketListener {
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription<WsMessage>? _messageSubscription;

  /// 初始化WebSocket监听
  void initWebSocket(String token) {
    _wsService.connect(token);
    _messageSubscription = _wsService.messages.listen(handleWsMessage);
  }

  /// 处理WebSocket消息
  void handleWsMessage(WsMessage message);

  /// 订阅家庭频道
  void subscribeFamilyChannel(String familyId) {
    _wsService.subscribe('family:$familyId');
  }

  /// 订阅用户频道
  void subscribeUserChannel(String userId) {
    _wsService.subscribe('user:$userId');
  }

  /// 清理WebSocket资源
  void disposeWebSocket() {
    _messageSubscription?.cancel();
    _wsService.dispose();
  }
}

/// 全局WebSocket服务实例
final webSocketService = WebSocketService();
