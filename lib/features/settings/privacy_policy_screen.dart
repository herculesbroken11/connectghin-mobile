import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import 'legal_rich_text.dart';

/// In-app Privacy Policy. Wording matches https://connectghin.com/privacy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _headingBlue = Color(0xFF001F3F);

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
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _headingBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            'Last updated: September 30, 2026',
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  '1. Introduction',
                  'This policy describes how Connectghin handles information when you use its mobile applications, website and related services. Availability of features and the information involved may vary by platform.',
                ),
                _Section(
                  '2. Information Collected',
                  null,
                  bullets: [
                    'Accounts and profiles: Name, email, account and authentication identifiers, profile details, golf preferences, city/state or other location information you submit, handicap number and handicap index, and profile or gallery photos.',
                    'Social activity: Where available in the mobile app, Connect and Match activity, matched-user messages, Feed or open-spot posts, ratings or reviews, reports, blocks and related moderation information.',
                    'Subscriptions: Where mobile subscriptions are used, subscription status, product and transaction or receipt identifiers, entitlements and the applicable store. Apple and Google process mobile payments; Connectghin does not receive full card details for App Store or Google Play purchases.',
                    'Technical and support information: Session and security information, request logs, and information sent to support. Where applicable, mobile device or push-notification tokens and device location if you grant permission for location features.',
                  ],
                ),
                _Section(
                  '3. How Information Is Used',
                  'We use information to create and authenticate accounts; provide profiles, nearby-golfer features, Connect, Matches, messaging and The Feed where available; verify subscription entitlements; send service notifications; respond to support requests; review safety reports; prevent fraud and abuse; comply with law; and maintain and improve service reliability. We do not describe advertising uses here.',
                ),
                _Section(
                  '4. Information Visible to Other Users',
                  'Depending on features and settings, other users may see your name or display name, profile photo, golf profile, handicap information, preferences, approximate or submitted profile location, Feed posts and other social contributions such as ratings or reviews. Private email addresses and matched-user messages are not described as public profile information.',
                ),
                _Section(
                  '5. Service Providers and Disclosure',
                  'Information may be processed by providers needed for hosting, authentication, email, notifications and, where applicable, Apple App Store and Google Play subscriptions. Information may also be disclosed to appropriate authorities when required by law or for safety.',
                ),
                _Section(
                  '6. Tracking and Cookies',
                  'The website uses an essential session cookie to keep signed-in users authenticated. Some features may not work without it. The website does not use personal information to track users across unrelated third-party apps or websites for targeted advertising.',
                ),
                _Section(
                  '7. Data Retention',
                  'Information is kept as needed to provide the service. Following account deletion, personal account information may be removed or anonymized. Limited records may remain where necessary for legal compliance, security, moderation, disputes or transaction and accounting purposes. We do not promise a fixed retention period.',
                ),
                _Section(
                  '8. Account Deletion',
                  'Request deletion in the Connectghin app under Settings → Delete Account or online at https://connectghin.com/delete-account. The process removes or anonymizes personal account data as described above. Deleting a Connectghin account does not automatically cancel an Apple App Store or Google Play subscription; manage active subscriptions with the applicable store.',
                ),
                _Section(
                  '9. Your Privacy Rights',
                  'Depending on applicable law, you may request access to, correction of or deletion of your personal information. Contact privacy@connectghin.com for privacy requests.',
                ),
                _Section(
                  '10. Data Security',
                  'We use reasonable administrative, technical and organizational safeguards to protect personal information. No system can guarantee absolute security.',
                ),
                _Section(
                  '11. Children and Age',
                  'Connectghin is intended for users 18 years of age or older. We do not knowingly permit individuals under 18 to create or maintain Connectghin accounts.',
                ),
                _Section(
                  '12. Policy Changes',
                  'We may update this policy by posting the revised version here and changing the “Last updated” date.',
                ),
                _Section(
                  '13. Contact',
                  'Contact support@connectghin.com.\n\nSee also:\nTerms of Service: https://connectghin.com/terms\nChild Safety Standards: https://connectghin.com/child-safety\nDelete Account: https://connectghin.com/delete-account',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body, {this.bullets = const []});

  final String title;
  final String? body;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PrivacyPolicyScreen._headingBlue,
              height: 1.3,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            LegalRichText(body!),
          ],
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: legalBodyStyle),
                    Expanded(child: LegalRichText(line)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
