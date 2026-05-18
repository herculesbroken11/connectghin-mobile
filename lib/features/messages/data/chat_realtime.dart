import 'package:socket_io_client/socket_io_client.dart' as io;

Map<String, dynamic>? socketPayloadAsMap(dynamic data) {
  if (data is Map) {
    return data.map((k, dynamic v) => MapEntry(k.toString(), v));
  }
  if (data is List && data.isNotEmpty) {
    return socketPayloadAsMap(data.first);
  }
  return null;
}

/// Socket.IO client for Nest `ChatGateway` (`namespace /chat`, JWT in `auth.token`).
class ChatRealtimeConnection {
  ChatRealtimeConnection({
    required this.socketUrl,
    required this.accessToken,
    required this.conversationId,
    required this.onIncomingMessage,
    this.onMessagesRead,
  });

  final String socketUrl;
  final String accessToken;
  final String conversationId;
  final void Function(Map<String, dynamic> payload) onIncomingMessage;
  /// Fired when a participant marks the thread read (`messagesRead` from `ChatGateway`).
  final void Function(Map<String, dynamic> payload)? onMessagesRead;

  io.Socket? _socket;

  void connect() {
    disconnect();
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth(<String, dynamic>{'token': accessToken})
          .build(),
    );
    _socket!.onConnect((_) {
      _socket!.emit('join', <String, dynamic>{'conversationId': conversationId});
    });
    _socket!.on('message', _onRawMessage);
    if (onMessagesRead != null) {
      _socket!.on('messagesRead', _onMessagesReadRaw);
    }
    _socket!.connect();
  }

  void _onRawMessage(dynamic data) {
    final map = socketPayloadAsMap(data);
    if (map != null) {
      onIncomingMessage(map);
    }
  }

  void _onMessagesReadRaw(dynamic data) {
    final map = socketPayloadAsMap(data);
    if (map != null) {
      onMessagesRead!(map);
    }
  }

  void disconnect() {
    final s = _socket;
    _socket = null;
    if (s == null) return;
    try {
      s.emit('leave', <String, dynamic>{'conversationId': conversationId});
    } catch (_) {}
    s.dispose();
  }
}

/// Subscribes to per-user `inbox` events (server joins `user:{id}` on connect).
class InboxRealtimeConnection {
  InboxRealtimeConnection({
    required this.socketUrl,
    required this.accessToken,
    required this.onInbox,
  });

  final String socketUrl;
  final String accessToken;
  final void Function(Map<String, dynamic> payload) onInbox;

  io.Socket? _socket;

  void connect() {
    disconnect();
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth(<String, dynamic>{'token': accessToken})
          .build(),
    );
    _socket!.on('inbox', _onInboxRaw);
    _socket!.connect();
  }

  void _onInboxRaw(dynamic data) {
    final map = socketPayloadAsMap(data);
    if (map != null) {
      onInbox(map);
    }
  }

  void disconnect() {
    final s = _socket;
    _socket = null;
    if (s == null) return;
    s.dispose();
  }
}
