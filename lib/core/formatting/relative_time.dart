/// Compact relative labels for inbox rows (e.g. "2m ago", "3h ago", "Apr 7").
String formatRelativeTime(DateTime utcOrLocal) {
  final now = DateTime.now();
  final t = utcOrLocal.isUtc ? utcOrLocal.toLocal() : utcOrLocal;
  final diff = now.difference(t);
  if (diff.isNegative || diff.inSeconds < 45) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[t.month - 1]} ${t.day}';
}

DateTime? tryParseIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso);
}
