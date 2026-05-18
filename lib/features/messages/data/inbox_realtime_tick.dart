import 'dart:async';

import 'package:flutter/foundation.dart';

/// Debounced signal when the backend emits a new message over Socket.IO (`inbox` event).
/// Screens listen and refetch conversation / match lists.
class InboxRealtimeTick extends ChangeNotifier {
  Timer? _debounce;

  void ping() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
