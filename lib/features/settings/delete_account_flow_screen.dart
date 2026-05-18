import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_outline_button.dart';
import '../../core/widgets/cg_text_field.dart';
import '../misc/data/account_api.dart';

/// Multi-step delete flow: intro → feedback → type DELETE → API.
class DeleteAccountFlowScreen extends StatefulWidget {
  const DeleteAccountFlowScreen({super.key});

  @override
  State<DeleteAccountFlowScreen> createState() => _DeleteAccountFlowScreenState();
}

class _DeleteAccountFlowScreenState extends State<DeleteAccountFlowScreen> {
  int _step = 0;
  String? _reasonCode;
  final _extraFeedback = TextEditingController();
  final _confirmDelete = TextEditingController();
  bool _saving = false;

  static const _reasons = <String>[
    'Found someone to play with',
    'Not using the app anymore',
    'Privacy concerns',
    'Too expensive',
    'Technical issues',
    'Other',
  ];

  @override
  void dispose() {
    _extraFeedback.dispose();
    _confirmDelete.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  bool get _canFinalDelete =>
      !_saving && _confirmDelete.text.trim().toUpperCase() == 'DELETE';

  Future<void> _submitDeletion() async {
    if (!_canFinalDelete) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final code = _reasonCode ?? 'unspecified';
    final extra = _extraFeedback.text.trim();
    final reason = extra.isEmpty ? code : '$code — $extra';
    setState(() => _saving = true);
    try {
      await AccountApi(session.apiClient).requestAccountDeletion(accessToken: t, reason: reason);
      if (!mounted) return;
      await session.clear();
      if (!mounted) return;
      context.go(AppPaths.welcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showApiErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _step == 1 ? CgColors.gray50 : CgColors.white,
      appBar: AppBar(
        backgroundColor: _step == 1 ? CgColors.gray50 : CgColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: CgColors.gray900),
          onPressed: _saving ? null : _back,
        ),
        title: const SizedBox.shrink(),
      ),
      body: switch (_step) {
        0 => _buildIntro(context),
        1 => _buildFeedback(context),
        _ => _buildFinal(context),
      },
    );
  }

  Widget _buildIntro(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const Text(
          'Delete Account',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CgColors.gray900),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CgColors.red50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CgColors.red50),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: CgColors.red700, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CgColors.red700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Deleting your account will permanently remove:',
                      style: TextStyle(fontSize: 14, height: 1.4, color: CgColors.red700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _infoCard(
          icon: Icons.person_outline_rounded,
          title: 'Your Profile',
          body: 'All profile information, photos, and preferences',
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Messages & Matches',
          body: 'All conversations and connections will be lost',
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.verified_user_outlined,
          title: 'GHIN Verification',
          body: 'Verification status will be removed',
        ),
        const SizedBox(height: 12),
        _infoCard(
          icon: Icons.credit_card_outlined,
          title: 'Subscription',
          body: 'Active subscriptions will be cancelled',
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => setState(() => _step = 1),
            style: FilledButton.styleFrom(
              backgroundColor: CgColors.destructive,
              foregroundColor: CgColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Continue to Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _saving ? null : () => context.pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: CgColors.gray900,
              side: const BorderSide(color: CgColors.gray300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Keep My Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const Text(
          'Help Us Improve',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CgColors.gray900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Why are you deleting your account? (Optional)',
          style: TextStyle(fontSize: 15, color: CgColors.gray600),
        ),
        const SizedBox(height: 20),
        ..._reasons.map((label) {
          final selected = _reasonCode == label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: CgColors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              child: InkWell(
                onTap: () => setState(() => _reasonCode = label),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? CgColors.green700 : CgColors.gray200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: selected ? CgColors.green700 : CgColors.gray400,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 16, color: CgColors.gray900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'Additional Feedback (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CgColors.gray900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _extraFeedback,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Tell us more about your experience...',
            hintStyle: const TextStyle(color: CgColors.gray400),
            filled: true,
            fillColor: CgColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CgColors.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CgColors.gray300),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : () => setState(() => _step = 2),
            style: FilledButton.styleFrom(
              backgroundColor: CgColors.destructive,
              foregroundColor: CgColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _saving ? null : () => context.pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: CgColors.gray900,
              side: const BorderSide(color: CgColors.gray300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildFinal(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const Text(
          'Final Confirmation',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: CgColors.gray900),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CgColors.red50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: CgColors.red700, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you absolutely sure?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CgColors.red700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'This action is permanent and cannot be reversed. All your data will be permanently deleted.',
                      style: TextStyle(fontSize: 14, height: 1.4, color: CgColors.red700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 15, color: CgColors.gray900, height: 1.4),
            children: [
              TextSpan(text: 'Type '),
              TextSpan(text: 'DELETE', style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' to confirm'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CgTextField(
          controller: _confirmDelete,
          hint: 'DELETE',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _canFinalDelete ? _submitDeletion : null,
            style: FilledButton.styleFrom(
              backgroundColor: CgColors.destructive,
              foregroundColor: CgColors.white,
              disabledBackgroundColor: CgColors.gray300,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.white),
                  )
                : const Text(
                    'Delete My Account Permanently',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        CgOutlineButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => context.pop(),
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Need help? ', style: TextStyle(fontSize: 14, color: CgColors.gray600)),
              GestureDetector(
                onTap: () => context.push(AppPaths.support),
                child: const Text(
                  'Contact Support',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CgColors.green700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Material(
      color: CgColors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: CgColors.gray100,
              child: Icon(icon, color: CgColors.blue700, size: 22),
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
                      color: CgColors.blue700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.35, color: CgColors.gray600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
