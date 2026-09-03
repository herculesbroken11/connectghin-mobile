import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../features/auth/data/auth_api.dart';

/// Shows Terms acceptance when [needsTermsAcceptance] is true.
/// Returns true if the user accepted (or already had accepted).
Future<bool> ensureTermsAcceptedForUgc(BuildContext context) async {
  final session = context.read<AuthSession>();
  final t = session.accessToken;
  if (t == null) return false;
  try {
    final me = await session.authApi.me(t);
    final needs = me['needsTermsAcceptance'] == true;
    if (!needs) return true;
  } catch (_) {
    // Fall through to prompt if status cannot be loaded.
  }
  if (!context.mounted) return false;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CgColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _TermsAcceptanceSheet(),
  );
  return accepted == true;
}

class _TermsAcceptanceSheet extends StatefulWidget {
  const _TermsAcceptanceSheet();

  @override
  State<_TermsAcceptanceSheet> createState() => _TermsAcceptanceSheetState();
}

class _TermsAcceptanceSheetState extends State<_TermsAcceptanceSheet> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _accept() async {
    if (!_agreed || _busy) return;
    setState(() => _busy = true);
    try {
      final session = context.read<AuthSession>();
      final t = session.accessToken;
      if (t == null) return;
      await AuthApi(session.apiClient).acceptTerms(t);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accept Terms to continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CgColors.gray900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Before posting content or uploading photos, please review and accept the Terms of Service. '
            'The Terms prohibit harassment, hate, sexual content, spam, and illegal activity.',
            style: TextStyle(fontSize: 14, height: 1.45, color: CgColors.gray600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push(AppPaths.legalTerms),
            child: const Text('View Terms of Service'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agreed,
            onChanged: _busy
                ? null
                : (v) => setState(() => _agreed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I agree to the Terms of Service',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _agreed && !_busy ? _accept : null,
              style: FilledButton.styleFrom(backgroundColor: CgColors.green700),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Accept & continue'),
            ),
          ),
        ],
      ),
    );
  }
}
