import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../ghinder/data/foursome_feed_api.dart';

const kFeedReportReasons = <(String code, String label)>[
  ('HARASSMENT', 'Harassment or bullying'),
  ('HATE', 'Hate or abusive content'),
  ('SEXUAL', 'Sexual/inappropriate content'),
  ('SPAM', 'Spam or scam'),
  ('DANGEROUS', 'Dangerous or illegal activity'),
  ('OTHER', 'Other'),
];

Future<void> showReportFeedPostSheet(
  BuildContext context, {
  required String postId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CgColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ReportFeedPostSheet(postId: postId),
  );
}

class _ReportFeedPostSheet extends StatefulWidget {
  const _ReportFeedPostSheet({required this.postId});

  final String postId;

  @override
  State<_ReportFeedPostSheet> createState() => _ReportFeedPostSheetState();
}

class _ReportFeedPostSheetState extends State<_ReportFeedPostSheet> {
  String? _reasonCode;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _reasonCode;
    if (code == null || _busy) return;
    setState(() => _busy = true);
    try {
      final session = context.read<AuthSession>();
      final t = session.accessToken;
      if (t == null) return;
      await FoursomeFeedApi(session.apiClient).reportPost(
        accessToken: t,
        postId: widget.postId,
        reason: code,
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks. Your report has been submitted for review.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Report Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: CgColors.gray900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reports are reviewed by our team. The post author will not see who reported.',
              style: TextStyle(fontSize: 13, height: 1.4, color: CgColors.gray600),
            ),
            const SizedBox(height: 14),
            ...kFeedReportReasons.map((r) {
              final selected = _reasonCode == r.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _busy ? null : () => setState(() => _reasonCode = r.$1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? CgColors.green700 : CgColors.gray200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected ? CgColors.green700 : CgColors.gray400,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.$2,
                            style: const TextStyle(
                              fontSize: 15,
                              color: CgColors.gray900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 2000,
              enabled: !_busy,
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _reasonCode != null && !_busy ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: CgColors.destructive,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
