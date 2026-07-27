import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design_tokens.dart';

/// In-app Privacy Policy (GHINder / Connectghin design).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);
  static const _privacyEmail = 'privacy@Connectghin.com';

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Privacy Policy',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _headingBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Last updated: April 8, 2026',
            style: TextStyle(fontSize: 15, color: CgColors.gray600, height: 1.35),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(CgRadii.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _numberedSection(
                  '1',
                  'Information We Collect',
                  const Text(
                    'We collect information you provide directly to us when you create an account, '
                    'including your name, email address, photos, golf handicap, and GHIN number for verification purposes.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '2',
                  'How We Use Your Information',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'We use the information we collect to:',
                        style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                      ),
                      const SizedBox(height: 10),
                      _bullets(const [
                        'Provide, maintain, and improve our services',
                        'Connect you with other golfers',
                        'Verify your GHIN handicap index',
                        'Send you updates and promotional communications',
                        'Monitor and analyze trends and usage',
                      ]),
                    ],
                  ),
                ),
                _numberedSection(
                  '3',
                  'Information Sharing',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'We do not sell your personal information. We may share your information with:',
                        style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                      ),
                      const SizedBox(height: 10),
                      _bullets(const [
                        'Other Connectghin users (profile information only)',
                        'Service providers who assist in our operations',
                        'Law enforcement when required by law',
                      ]),
                    ],
                  ),
                ),
                _numberedSection(
                  '4',
                  'Handicap Verification',
                  const Text(
                    'When you submit a GHIN number for handicap verification, we verify it against the official GHIN database. '
                    'Your handicap index may be displayed on your profile as part of your public profile information.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '5',
                  'Data Security',
                  const Text(
                    'We use industry-standard security measures to protect your information. '
                    'However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '6',
                  'Your Rights',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Depending on where you live, you may have the right to:',
                        style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                      ),
                      const SizedBox(height: 10),
                      _bullets(const [
                        'Access your personal information',
                        'Update or correct your information',
                        'Delete your account and data',
                        'Opt-out of marketing communications',
                      ]),
                    ],
                  ),
                ),
                _numberedSection(
                  '7',
                  "Children's Privacy",
                  const Text(
                    'Connectghin is not intended for users under 18. We do not knowingly collect personal information from children under 18.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '8',
                  'Location Data',
                  const Text(
                    'We collect location data to show you golfers near you and improve discovery features. '
                    'You can control location permissions in your device settings at any time.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '9',
                  'Cookies and Tracking',
                  const Text(
                    'We may use cookies and similar technologies to improve your experience, analyze usage, '
                    'and deliver personalized content where appropriate.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '10',
                  'Changes to This Policy',
                  const Text(
                    'We may update this policy from time to time. We will notify you by posting the new policy on this page '
                    'and updating the "Last updated" date.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                  ),
                ),
                _numberedSection(
                  '11',
                  'Contact Us',
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'If you have questions about this Privacy Policy, please contact us:',
                        style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                      ),
                      SizedBox(height: 12),
                      SelectableText(
                        _privacyEmail,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CgColors.blue700,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '123 Golf Lane\nSan Francisco, CA 94102',
                        style: TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: CgColors.blue50,
            borderRadius: BorderRadius.circular(CgRadii.xl),
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse('mailto:$_privacyEmail');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              borderRadius: BorderRadius.circular(CgRadii.xl),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  children: [
                    Text(
                      'Questions about your privacy?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CgColors.gray900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Contact our privacy team at privacy@Connectghin.com',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4, color: CgColors.gray600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _numberedSection(String num, String title, Widget body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$num. $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _headingBlue,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }

  static Widget _bullets(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 15, color: CgColors.gray700, height: 1.5)),
              Expanded(
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
