import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/premium/effective_premium.dart';
import '../profiles/data/profiles_api.dart';
import 'foursome_feed_tab.dart';

/// The Feed — open-spots list (Casual / Serious / Tournament).
/// Connect (nearby likes) remains on its own bottom-nav tab.
class GhinderScreen extends StatefulWidget {
  const GhinderScreen({super.key});

  @override
  State<GhinderScreen> createState() => _GhinderScreenState();
}

class _GhinderScreenState extends State<GhinderScreen> {
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPremiumStatus());
  }

  Future<void> _loadPremiumStatus() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final me = await ProfilesApi(session.apiClient).getMe(t);
      if (mounted) {
        setState(() => _isPremium = isEffectivePremiumFromJson(me));
      }
    } catch (_) {
      // Feed loads its own premium flags from list API.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CgColors.cream,
      child: Column(
        children: [
          _FeedHeader(
            isPremium: _isPremium,
            onPremium: () => context.push(AppPaths.appMembership),
          ),
          const Expanded(child: FoursomeFeedTab()),
        ],
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.isPremium, required this.onPremium});

  final bool isPremium;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/pair_up_header.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.3, 0.25),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE60F3A28),
                  Color(0x70144F37),
                  Color(0x30144F37),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: isPremium
                          ? CgColors.premiumGold
                          : CgColors.premiumGoldLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onPremium,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 14,
                                color: isPremium
                                    ? CgColors.green900
                                    : CgColors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isPremium
                                      ? CgColors.green900
                                      : CgColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'The Feed',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: CgColors.white,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find golfers looking for open spots nearby',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CgColors.white.withValues(alpha: 0.96),
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
