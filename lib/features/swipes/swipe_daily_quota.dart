import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../core/network/api_client.dart';
import '../../core/network/nest_http_error.dart';

/// Server `GET /swipes/daily-status` payload.
class SwipeDailyQuota {
  const SwipeDailyQuota({
    required this.isPremium,
    required this.used,
    this.dailyLimit,
    this.remaining,
  });

  final bool isPremium;
  final int? dailyLimit;
  final int used;
  final int? remaining;

  factory SwipeDailyQuota.fromJson(Map<String, dynamic> json) {
    final premium = json['isPremium'] == true;
    final used = (json['used'] as num?)?.toInt() ?? 0;
    final limit = (json['dailyLimit'] as num?)?.toInt();
    final rem = json['remaining'] == null ? null : (json['remaining'] as num).toInt();
    return SwipeDailyQuota(
      isPremium: premium,
      dailyLimit: limit,
      used: used,
      remaining: rem,
    );
  }
}

DailySwipeLimitError? tryParseDailySwipeLimit(Object error) {
  if (error is! ApiHttpException || error.statusCode != 403) return null;
  final payload = parseNestHttpErrorBody(error.body);
  if (payload == null || payload['code'] != 'DAILY_SWIPE_LIMIT') return null;
  final limit = payload['limit'];
  final used = payload['used'];
  if (limit is! num || used is! num) return null;
  return DailySwipeLimitError(limit: limit.toInt(), used: used.toInt());
}

class DailySwipeLimitError {
  const DailySwipeLimitError({required this.limit, required this.used});

  final int limit;
  final int used;
}

Future<void> showDailySwipeLimitSheet(BuildContext context, DailySwipeLimitError err) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: CgColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(color: Color(0xFFFFF7ED), shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium_rounded, size: 32, color: CgColors.orange600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Daily swipe limit',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CgColors.gray900),
              ),
              const SizedBox(height: 10),
              Text(
                'Free members can swipe up to ${err.limit} new profiles per day (UTC). Upgrade to Premium for unlimited swipes.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.45, color: CgColors.gray600),
              ),
              const SizedBox(height: 8),
              Text(
                '${err.used} / ${err.limit} used today',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CgColors.gray700),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(AppPaths.appMembership);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CgColors.orange600,
                    foregroundColor: CgColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Upgrade to Premium', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
