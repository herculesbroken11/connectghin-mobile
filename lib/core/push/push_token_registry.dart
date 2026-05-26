/// Lets settings / permission screens force an FCM token sync after permission changes.
abstract final class PushTokenRegistry {
  static Future<void> Function()? resync;

  static Future<void> requestResync() async {
    final fn = resync;
    if (fn != null) {
      await fn();
    }
  }
}
