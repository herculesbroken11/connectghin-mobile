import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Feed tabs. Stored and queried as these exact enum values.
const kFeedGameStyles = <String>['CASUAL', 'SERIOUS', 'TOURNAMENT'];

const kFeedGameStyleLabels = <String, String>{
  'CASUAL': 'Casual',
  'SERIOUS': 'Serious',
  'TOURNAMENT': 'Tournament',
};

/// Maps a selected style to the persisted enum.
/// Missing or unknown values are not turned into CASUAL.
String? canonicalFeedGameStyle(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'CASUAL':
      return 'CASUAL';
    case 'SERIOUS':
      return 'SERIOUS';
    case 'TOURNAMENT':
      return 'TOURNAMENT';
    default:
      return null;
  }
}

/// Rows for one tab. A Serious post is never kept in the Casual list.
List<T> postsForFeedStyle<T>(List<T> posts, String style, String Function(T post) readStyle) {
  final wanted = canonicalFeedGameStyle(style);
  if (wanted == null) return const [];
  return posts.where((post) => canonicalFeedGameStyle(readStyle(post)) == wanted).toList();
}

/// Body for `POST /foursome-feed`. [gameStyle] is the selected enum, not a label.
Map<String, dynamic> foursomeFeedCreateBody({
  required String courseName,
  String? city,
  String? state,
  required String roundDateIso,
  required String teeTime,
  required int spotsNeeded,
  required String gameStyle,
  String? handicapPreference,
  String? feeLabel,
  String? notes,
}) {
  final style = canonicalFeedGameStyle(gameStyle);
  if (style == null) {
    throw ArgumentError('Select Casual, Serious, or Tournament');
  }
  return <String, dynamic>{
    'courseName': courseName,
    if (city != null && city.isNotEmpty) 'city': city,
    if (state != null && state.isNotEmpty) 'state': state,
    'roundDate': roundDateIso,
    'teeTime': teeTime,
    'spotsNeeded': spotsNeeded,
    'gameStyle': style,
    if (handicapPreference != null && handicapPreference.isNotEmpty)
      'handicapPreference': handicapPreference,
    if (feeLabel != null && feeLabel.isNotEmpty) 'feeLabel': feeLabel,
    if (notes != null && notes.isNotEmpty) 'notes': notes,
  };
}

/// After a successful post, the next fetch must be that post's category.
Future<void> refreshFeedForCreatedStyle({
  required String gameStyle,
  required void Function(String style) selectStyle,
  required Future<void> Function() reload,
}) async {
  final style = canonicalFeedGameStyle(gameStyle);
  if (style == null) {
    throw ArgumentError('Select Casual, Serious, or Tournament');
  }
  selectStyle(style);
  await reload();
}

class FeedGameStyleChips extends StatelessWidget {
  const FeedGameStyleChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final style in kFeedGameStyles)
          Material(
            key: ValueKey<String>('feed-style-$style'),
            color: selected == style ? CgColors.green700 : CgColors.gray100,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(style),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  kFeedGameStyleLabels[style] ?? style,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected == style ? CgColors.white : CgColors.gray700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
