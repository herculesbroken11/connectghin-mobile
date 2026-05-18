import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design_tokens.dart';
import '../../core/widgets/cg_primary_button.dart';

/// Help & Support hub (contact rows, FAQ, CTA card).
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);
  static const _supportEmail = 'support@connectghin.com';

  static const _faqs = <(String, String)>[
    (
      'How do I verify my GHIN?',
      'Open Profile → GHIN verification and enter your GHIN number. We verify against the official database. '
          'Your handicap may appear on your profile after approval.',
    ),
    (
      'What are Premium benefits?',
      'Premium unlocks expanded discovery, priority placement, and member-only features shown on the Membership screen. '
          'Exact benefits may vary by release.',
    ),
    (
      'How do I cancel my subscription?',
      'Open Membership or your platform subscription settings (App Store / Google Play) to manage or cancel billing. '
          'You keep access until the end of the paid period.',
    ),
    (
      'How does matching work?',
      'Swipe on golfers you want to meet. When you both like each other, you match and can start chatting.',
    ),
    (
      'How do I report a user?',
      'Open their profile and use Report, or go through Help & Support with the user’s details. '
          'Our team reviews safety reports promptly.',
    ),
  ];

  static Future<void> _mailto() async {
    final uri = Uri.parse('mailto:$_supportEmail');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static void _liveChatNote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live chat is available Monday–Friday, 9AM–5PM EST. Email us anytime.'),
      ),
    );
  }

  static void _showFaq(BuildContext context, String q, String a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CgColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CgColors.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              q,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CgColors.gray900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              a,
              style: const TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        backgroundColor: CgColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: () => context.pop(),
        ),
        title: const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _headingBlue,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Text(
              "We're here to help",
              style: TextStyle(fontSize: 15, color: CgColors.blue700, fontWeight: FontWeight.w500),
            ),
          ),
          _sectionBar('CONTACT US'),
          _contactTile(
            circleColor: CgColors.green100,
            icon: Icons.mail_outline,
            iconColor: CgColors.green700,
            title: 'Email Support',
            subtitle: _supportEmail,
            subtitleColor: CgColors.blue700,
            onTap: _mailto,
          ),
          const Divider(height: 1, color: CgColors.gray200),
          _contactTile(
            circleColor: CgColors.blue50,
            icon: Icons.chat_bubble_outline,
            iconColor: CgColors.blue600,
            title: 'Live Chat',
            subtitle: 'Available 9AM - 5PM EST',
            subtitleColor: CgColors.blue700,
            onTap: () => _liveChatNote(context),
          ),
          const SizedBox(height: 8),
          _sectionBar('FREQUENTLY ASKED QUESTIONS'),
          ...List.generate(_faqs.length, (i) {
            final (q, a) = _faqs[i];
            final bg = i >= 3 ? CgColors.gray100 : CgColors.white;
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: CgColors.gray200),
                Material(
                  color: bg,
                  child: InkWell(
                    onTap: () => _showFaq(context, q, a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CgColors.gray900,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: CgColors.gray400),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: CgColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: CgColors.green50,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: CgColors.green100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: CgColors.green700, size: 22),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Still need help?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CgColors.gray900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is available Monday - Friday, 9AM - 5PM EST',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                  ),
                  const SizedBox(height: 20),
                  CgPrimaryButton(
                    label: 'Contact Support',
                    onPressed: () => _mailto(),
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionBar(String label) {
    return Container(
      width: double.infinity,
      color: CgColors.gray100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: CgColors.blue700,
        ),
      ),
    );
  }

  static Widget _contactTile({
    required Color circleColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: CgColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CgColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CgColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
