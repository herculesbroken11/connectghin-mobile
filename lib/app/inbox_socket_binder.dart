import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import '../features/messages/data/chat_realtime.dart';
import '../features/messages/data/inbox_realtime_tick.dart';
import 'session/auth_session.dart';

/// Keeps one inbox Socket.IO connection while logged in; debounced [InboxRealtimeTick] on each `inbox` event.
class InboxSocketBinder extends StatefulWidget {
  const InboxSocketBinder({super.key, required this.child});

  final Widget child;

  @override
  State<InboxSocketBinder> createState() => _InboxSocketBinderState();
}

class _InboxSocketBinderState extends State<InboxSocketBinder> {
  InboxRealtimeConnection? _conn;
  String? _token;
  late final AuthSession _session;
  late final VoidCallback _authListener;

  @override
  void initState() {
    super.initState();
    _session = context.read<AuthSession>();
    _authListener = () => _syncFromSession(_session);
    _session.addListener(_authListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromSession(_session));
  }

  @override
  void dispose() {
    _session.removeListener(_authListener);
    _conn?.disconnect();
    super.dispose();
  }

  void _syncFromSession(AuthSession session) {
    if (!mounted) {
      return;
    }
    final t = session.accessToken;
    if (t == null || t.isEmpty) {
      _token = null;
      _conn?.disconnect();
      _conn = null;
      return;
    }
    if (t == _token && _conn != null) {
      return;
    }
    _token = t;
    _conn?.disconnect();
    final tick = context.read<InboxRealtimeTick>();
    _conn = InboxRealtimeConnection(
      socketUrl: ApiConfig.socketChatUrl,
      accessToken: t,
      onInbox: (_) => tick.ping(),
    );
    _conn!.connect();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
