class DiscoverCandidateDto {
  DiscoverCandidateDto({
    required this.userId,
    required this.primaryPhoto,
    required this.displayName,
    required this.age,
    required this.distanceKm,
    required this.handicap,
    required this.isVerified,
    required this.isPremium,
    required this.tags,
  });

  final String userId;
  final String primaryPhoto;
  final String displayName;
  final int age;
  final double distanceKm;
  final double? handicap;
  final bool isVerified;
  final bool isPremium;
  final List<String> tags;
}

class PublicProfileDto {
  PublicProfileDto({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.homeCourse,
    required this.lookingFor,
    required this.preferences,
    required this.photos,
    required this.isVerified,
    required this.canMessage,
    required this.isBlocked,
    required this.isMatched,
  });

  final String userId;
  final String displayName;
  final String? bio;
  final String? homeCourse;
  final String? lookingFor;
  final Map<String, String> preferences;
  final List<String> photos;
  final bool isVerified;
  final bool canMessage;
  final bool isBlocked;
  final bool isMatched;
}

class ConversationListItemDto {
  ConversationListItemDto({
    required this.conversationId,
    required this.otherUserId,
    required this.otherDisplayName,
    required this.otherPrimaryPhoto,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String conversationId;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherPrimaryPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
}

class NotificationItemDto {
  NotificationItemDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.iconHint,
    required this.deepLink,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String iconHint;
  final String? deepLink;
  final bool isRead;
  final DateTime createdAt;
}
