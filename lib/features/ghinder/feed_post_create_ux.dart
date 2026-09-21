/// User-facing copy after a successful `POST /foursome-feed`.
const kFoursomeFeedPostSuccessMessage =
    'Your open spot was posted successfully.';

/// Neutral label on the viewer's own Feed card.
const kFoursomeFeedOwnPostLabel = 'Your post';

/// True when [posterId] is the logged-in user.
bool isOwnFeedPost({
  required String posterId,
  required String? currentUserId,
}) {
  final id = currentUserId?.trim();
  return id != null && id.isNotEmpty && posterId == id;
}

/// Own posts are visible in The Feed but must not open self-chat.
bool feedPostAllowsContact({required bool isOwnPost}) => !isOwnPost;

/// Own posts must not be self-reported.
bool feedPostAllowsReport({required bool isOwnPost}) => !isOwnPost;

/// Runs [create], then closes the sheet and shows success only if create
/// completed without throwing. Feed reload runs after success UX so the new
/// own post appears in the list (backend includes the viewer's posts).
Future<void> afterSuccessfulFeedPostCreate({
  required Future<void> Function() create,
  required void Function() closeSheet,
  required void Function(String message) showSuccess,
  required Future<void> Function() reloadFeed,
}) async {
  await create();
  closeSheet();
  showSuccess(kFoursomeFeedPostSuccessMessage);
  await reloadFeed();
}

/// Prevents overlapping submit actions while a request is in flight.
class FeedPostSubmitGate {
  bool _busy = false;

  bool get isBusy => _busy;

  Future<void> run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }
}
