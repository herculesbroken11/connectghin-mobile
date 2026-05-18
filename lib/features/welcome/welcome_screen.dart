import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../data/demo_content.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_responsive_container.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final heroH = (screenH * 0.52).clamp(300.0, 440.0);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: CgColors.white,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  SizedBox(
                    height: heroH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: DemoImages.heroGolf,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: CgColors.gray300),
                          errorWidget: (_, __, ___) => Container(color: CgColors.gray300),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.35),
                                Colors.black.withValues(alpha: 0.82),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 44,
                          left: 24,
                          right: 24,
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: CgColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.sports_golf, color: CgColors.green700, size: 30),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'ConnectGHIN',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'The premier golf networking platform',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Row(
                            children: [
                              Expanded(
                                child: _HeroTrustChip(
                                  icon: Icons.groups_outlined,
                                  label: '10,000+ Golfers',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _HeroTrustChip(
                                  icon: Icons.verified_outlined,
                                  label: 'GHIN Verified',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: CgResponsiveContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Join the Premier Golf Network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: wide ? 28 : 22,
                              fontWeight: FontWeight.w700,
                              color: CgColors.gray900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Connect with verified golfers and find your next partner',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: CgColors.gray600,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 22),
                          _FeatureCardsRow(wide: wide),
                          const SizedBox(height: 26),
                          CgPrimaryButton(
                            label: 'Get Started',
                            onPressed: () => context.push(AppPaths.register),
                            borderRadius: 12,
                            minHeight: 52,
                          ),
                          const SizedBox(height: 12),
                          CgOutlineButton(
                            label: 'Sign In',
                            onPressed: () => context.push(AppPaths.login),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Free to join • Connect with verified golfers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: CgColors.gray500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroTrustChip extends StatelessWidget {
  const _HeroTrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
  const _FeatureCardsRow({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _MiniFeatureCard(
        icon: Icons.verified_user_outlined,
        title: 'Verified Handicaps',
      ),
      const _MiniFeatureCard(
        icon: Icons.star_outline_rounded,
        title: 'Player Ratings',
      ),
      const _MiniFeatureCard(
        icon: Icons.groups_2_outlined,
        title: 'Smart Matching',
      ),
    ];
    if (!wide && MediaQuery.sizeOf(context).width < 380) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cards[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CgColors.gray200),
        boxShadow: [
          BoxShadow(
            color: CgColors.gray900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: CgColors.green700),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CgColors.gray900,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
