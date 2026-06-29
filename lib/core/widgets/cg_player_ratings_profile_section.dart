import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../core/formatting/relative_time.dart';
import '../../data/api_profile.dart';
import 'cg_rating_chip.dart';

/// Compact stats row for profile detail header (rating, play again %, rounds rated).
class CgProfileRatingStatsCard extends StatelessWidget {
  const CgProfileRatingStatsCard({
    super.key,
    required this.summary,
    this.onRatePlayer,
    this.showRateButton = true,
  });

  final GolferRatingSummary summary;
  final VoidCallback? onRatePlayer;
  final bool showRateButton;

  @override
  Widget build(BuildContext context) {
    final avg = summary.averageRating;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CgColors.gray200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCol(
              value: summary.hasRating ? avg!.toStringAsFixed(1) : '—',
              label: 'Rating',
              leading: summary.hasRating
                  ? const Icon(Icons.star_rounded, color: CgColors.yellow500, size: 20)
                  : null,
            ),
          ),
          Container(width: 1, height: 44, color: CgColors.gray200),
          Expanded(
            child: _statCol(
              value: summary.reviewCount > 0 ? '${summary.playAgainPercent}%' : '—',
              label: 'play again',
              valueColor: CgColors.green700,
            ),
          ),
          Container(width: 1, height: 44, color: CgColors.gray200),
          Expanded(
            child: _statCol(
              value: summary.reviewCount > 0 ? '${summary.reviewCount}' : '—',
              label: 'rounds rated',
            ),
          ),
          if (showRateButton && onRatePlayer != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRatePlayer,
              style: TextButton.styleFrom(
                backgroundColor: CgColors.green50,
                foregroundColor: CgColors.green700,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('Rate\nPlayer', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCol({
    required String value,
    required String label,
    Widget? leading,
    Color? valueColor,
  }) {
    return Column(
      children: [
        if (leading != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: valueColor ?? CgColors.gray900),
              ),
            ],
          )
        else
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: valueColor ?? CgColors.gray900),
          ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: CgColors.gray500)),
      ],
    );
  }
}

/// Player ratings breakdown, play-again banner, and recent reviews for profile detail.
class CgPlayerRatingsProfileSection extends StatelessWidget {
  const CgPlayerRatingsProfileSection({
    super.key,
    required this.summary,
    required this.recentReviews,
    required this.totalReviewCount,
    required this.userId,
  });

  final GolferRatingSummary summary;
  final List<Map<String, dynamic>> recentReviews;
  final int totalReviewCount;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasRating && recentReviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CgColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CgColors.gray200),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Player Ratings',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CgColors.gray900),
                  ),
                  const Spacer(),
                  if (summary.hasRating)
                    CgRatingChip(
                      averageRating: summary.averageRating,
                      reviewCount: summary.reviewCount,
                      compact: true,
                    ),
                ],
              ),
              if (summary.hasRating) ...[
                const SizedBox(height: 16),
                _RatingBarRow(label: 'Overall', value: summary.averageRating!),
                const SizedBox(height: 10),
                if (summary.averageHandicapAccuracy != null)
                  _RatingBarRow(label: 'Handicap Accuracy', value: summary.averageHandicapAccuracy!),
                if (summary.averageHandicapAccuracy != null) const SizedBox(height: 10),
                if (summary.averageSportsmanship != null)
                  _RatingBarRow(label: 'Sportsmanship', value: summary.averageSportsmanship!),
                if (summary.averageSportsmanship != null) const SizedBox(height: 10),
                if (summary.averagePaceOfPlay != null)
                  _RatingBarRow(label: 'Pace of Play', value: summary.averagePaceOfPlay!),
              ],
            ],
          ),
        ),
        if (summary.reviewCount > 0 && summary.playAgainPercent > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CgColors.green50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CgColors.green100),
            ),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_alt_rounded, color: CgColors.green700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.playAgainPercent}% would play again',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: CgColors.green800, fontSize: 15),
                      ),
                      Text(
                        'Based on ${summary.reviewCount} rated round${summary.reviewCount == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 13, color: CgColors.green700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (recentReviews.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'RECENT REVIEWS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CgColors.gray500, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CgColors.gray200),
            ),
            child: Column(
              children: [
                for (var i = 0; i < recentReviews.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: CgColors.gray100),
                  _RecentReviewTile(review: recentReviews[i]),
                ],
              ],
            ),
          ),
        ],
        if (totalReviewCount > 0) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push(
              '${AppPaths.appPlayerRatings}?userId=${Uri.encodeComponent(userId)}',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: CgColors.gray900,
              side: const BorderSide(color: CgColors.gray300),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('View All Reviews ($totalReviewCount)'),
          ),
        ],
      ],
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final fill = (value / 5).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(label, style: const TextStyle(fontSize: 13, color: CgColors.gray700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 8,
              backgroundColor: CgColors.gray100,
              color: CgColors.green600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CgColors.gray900),
        ),
      ],
    );
  }
}

class _RecentReviewTile extends StatelessWidget {
  const _RecentReviewTile({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final name = review['reviewerName'] as String? ?? 'Golfer';
    final rating = (review['overallRating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final submitted = review['submittedDate'] as String?;
    final submittedAt = submitted != null ? DateTime.tryParse(submitted) : null;
    final timeLabel = submittedAt != null ? formatRelativeTime(submittedAt) : '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (timeLabel.isNotEmpty)
                Text(timeLabel, style: const TextStyle(fontSize: 12, color: CgColors.gray500)),
            ],
          ),
          const SizedBox(height: 6),
          _StarsRow(rating: rating),
          const SizedBox(height: 8),
          Text(
            comment,
            style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final rounded = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < rounded ? Icons.star_rounded : Icons.star_border_rounded,
            color: CgColors.yellow500,
            size: 16,
          ),
      ],
    );
  }
}
