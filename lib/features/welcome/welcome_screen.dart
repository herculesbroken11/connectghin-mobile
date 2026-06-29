import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../core/layout/cg_fit_height_body.dart';
import '../../data/demo_content.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';

/// Landing screen — hero photo (logo baked into asset), mockup-aligned content.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _heroAsset = 'assets/images/welcome_hero.png';

  @override
  Widget build(BuildContext context) {
    final short = cgIsShortScreen(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              flex: short ? 44 : 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _heroAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => CachedNetworkImage(
                      imageUrl: DemoImages.heroGolf,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      placeholder: (_, __) => Container(color: CgColors.gray300),
                      errorWidget: (_, __, ___) => Container(color: CgColors.gray300),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.38),
                        ],
                        stops: const [0.62, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: short ? 12 : 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroTrustChip(
                            icon: Icons.groups_outlined,
                            label: '10,000+ Golfers',
                            compact: short,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroTrustChip(
                            icon: Icons.verified_outlined,
                            label: 'Handicap Verified',
                            compact: short,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: short ? 56 : 52,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  short ? 14 : 20,
                  22,
                  8 + MediaQuery.paddingOf(context).bottom,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width - 44,
                    child: CgResponsiveContainer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Join the Premier Golf Network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: wide ? 26 : (short ? 20 : 23),
                              fontWeight: FontWeight.w800,
                              color: CgColors.gray900,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: short ? 8 : 10),
                          Text(
                            'Connect with verified golfers and find your next partner',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: CgColors.gray600,
                              height: 1.35,
                              fontSize: short ? 13 : 14,
                            ),
                          ),
                          SizedBox(height: short ? 14 : 20),
                          _FeatureCardsRow(compact: short),
                          SizedBox(height: short ? 16 : 20),
                          CgPrimaryButton(
                            label: 'Get Started',
                            onPressed: () => context.push(AppPaths.register),
                            borderRadius: 12,
                            minHeight: short ? 50 : 52,
                          ),
                          const SizedBox(height: 12),
                          CgOutlineButton(
                            label: 'Sign In',
                            onPressed: () => context.push(AppPaths.login),
                            borderColor: CgColors.green700,
                            borderRadius: 12,
                            minHeight: short ? 50 : 52,
                          ),
                          SizedBox(height: short ? 12 : 14),
                          Text(
                            'Free to join • Connect with verified golfers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: short ? 12 : 13,
                              color: CgColors.gray500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTrustChip extends StatelessWidget {
  const _HeroTrustChip({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14532D).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 16 : 18, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardsRow extends StatelessWidget {
  const _FeatureCardsRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const cards = [
      _MiniFeatureCard(icon: Icons.verified_user_outlined, title: 'Verified\nHandicaps'),
      _MiniFeatureCard(icon: Icons.star_outline_rounded, title: 'Player\nRatings'),
      _MiniFeatureCard(icon: Icons.groups_2_outlined, title: 'Smart\nMatching'),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(width: compact ? 8 : 10),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _MiniFeatureCard extends StatelessWidget {
  const _MiniFeatureCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = cgIsShortScreen(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CgColors.gray200),
        boxShadow: [
          BoxShadow(
            color: CgColors.gray900.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 12 : 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 24 : 26, color: CgColors.green700),
            SizedBox(height: compact ? 8 : 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: CgColors.gray900,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
