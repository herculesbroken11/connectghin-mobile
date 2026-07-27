import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/router/app_paths.dart';
import '../../app/session/auth_session.dart';
import '../../core/constants/us_states.dart';
import '../../core/formatting/relative_time.dart';
import '../../core/network/api_user_message.dart';
import '../../core/widgets/cg_handicap_verified_badge.dart';
import '../../core/widgets/cg_premium_badge.dart';
import '../../core/widgets/cg_premium_locked_cta.dart';
import '../../core/widgets/cg_primary_button.dart';
import '../../core/widgets/cg_rating_chip.dart';
import '../../data/api_profile.dart';
import 'data/foursome_feed_api.dart';

const _gameStyleFilters = <String, String>{
  'CASUAL': 'Casual',
  'SERIOUS': 'Serious',
  'TOURNAMENT': 'Tournament',
};

class FoursomeFeedTab extends StatefulWidget {
  const FoursomeFeedTab({super.key});

  @override
  State<FoursomeFeedTab> createState() => _FoursomeFeedTabState();
}

class _FoursomeFeedTabState extends State<FoursomeFeedTab> {
  bool _loading = true;
  String? _error;
  List<FoursomeFeedPost> _posts = [];
  String _gameStyle = 'CASUAL';
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await FoursomeFeedApi(session.apiClient).list(
        t,
        gameStyle: _gameStyle,
      );
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => FoursomeFeedPost.fromJson(e as Map<String, dynamic>))
          .whereType<FoursomeFeedPost>()
          .toList();
      final premium = data['isPremiumViewer'] == true ||
          data['canContact'] == true ||
          data['canPost'] == true;
      if (mounted) {
        setState(() {
          _posts = items;
          _isPremium = premium;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageFromApiError(e);
          _loading = false;
        });
      }
    }
  }

  void _showPremiumGate() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: const SizedBox.expand(),
          ),
          CgPremiumGateModal(
            subtitle: 'Unlock Find Your 4th features',
            onUpgrade: () {
              Navigator.pop(ctx);
              context.push(AppPaths.appMembership);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _contact(FoursomeFeedPost post) async {
    if (!_isPremium) {
      _showPremiumGate();
      return;
    }
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final res = await FoursomeFeedApi(session.apiClient).contact(
        accessToken: t,
        postId: post.id,
      );
      final conv = res['conversation'] as Map<String, dynamic>?;
      final convId = conv?['id'] as String?;
      if (convId != null && mounted) {
        context.push(
          '${AppPaths.appMessages}/$convId'
          '?peer=${Uri.encodeComponent(post.posterId)}'
          '&name=${Uri.encodeComponent(post.posterName)}',
        );
      }
    } catch (e) {
      if (mounted) showApiErrorSnackBar(context, e);
    }
  }

  void _openCreatePost() {
    if (!_isPremium) {
      _showPremiumGate();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CgColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _CreatePostSheet(
          onSubmit: (fields) async {
            final session = context.read<AuthSession>();
            final t = session.accessToken;
            if (t == null) return;
            await FoursomeFeedApi(session.apiClient).create(
              accessToken: t,
              courseName: fields.courseName,
              city: fields.city,
              state: fields.state,
              roundDateIso: fields.roundDateIso,
              teeTime: fields.teeTime,
              spotsNeeded: fields.spotsNeeded,
              gameStyle: fields.gameStyle,
              handicapPreference: fields.handicapPreference,
              feeLabel: fields.feeLabel,
              notes: fields.notes,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            await _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CgColors.green700));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CgPrimaryButton(label: 'Retry', onPressed: _load),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: CgColors.green700,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              if (!_isPremium) ...[
                _PremiumUpgradeBanner(onUnlock: _showPremiumGate),
                const SizedBox(height: 12),
              ],
              _GameStyleFilterBar(
                selectedKey: _gameStyle,
                onSelected: (key) {
                  if (_gameStyle == key) return;
                  setState(() => _gameStyle = key);
                  _load();
                },
              ),
              const SizedBox(height: 16),
              if (_posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No open spots nearby yet.\nCheck back soon or post your own round.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CgColors.gray600),
                    ),
                  ),
                )
              else
                ..._posts.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _FoursomePostCard(
                      post: p,
                      isPremium: _isPremium,
                      onContact: () => _contact(p),
                      onLockedTap: _showPremiumGate,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isPremium)
          Positioned(
            right: 20,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _openCreatePost,
              backgroundColor: CgColors.green700,
              icon: const Icon(Icons.add_rounded, color: CgColors.white),
              label: const Text('Post spot', style: TextStyle(color: CgColors.white, fontWeight: FontWeight.w600)),
            ),
          )
        else
          Positioned(
            right: 20,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _showPremiumGate,
              backgroundColor: CgColors.premiumGold,
              icon: const Icon(Icons.lock_rounded, color: CgColors.white),
              label: const Text('Post spot', style: TextStyle(color: CgColors.white, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _GameStyleFilterBar extends StatelessWidget {
  const _GameStyleFilterBar({
    required this.selectedKey,
    required this.onSelected,
  });

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CgColors.gray200),
        boxShadow: CgShadows.soft,
      ),
      child: Row(
        children: _gameStyleFilters.entries.map((entry) {
          final selected = selectedKey == entry.key;
          return Expanded(
            child: Material(
              color: selected ? CgColors.green700 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? CgColors.white : CgColors.gray600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PremiumUpgradeBanner extends StatelessWidget {
  const _PremiumUpgradeBanner({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CgColors.premiumGold.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: CgColors.premiumGold, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Upgrade to post & reply. Premium members can post open spots and contact golfers directly.',
              style: TextStyle(fontSize: 13, color: CgColors.gray700, height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onUnlock,
            style: TextButton.styleFrom(
              backgroundColor: CgColors.premiumGold,
              foregroundColor: CgColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FoursomePostCard extends StatelessWidget {
  const _FoursomePostCard({
    required this.post,
    required this.isPremium,
    required this.onContact,
    required this.onLockedTap,
  });

  final FoursomeFeedPost post;
  final bool isPremium;
  final VoidCallback onContact;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final p = post;
    final dateLabel = _formatDate(p.roundDate);
    final timeAgo = formatRelativeTime(p.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CgColors.gray200.withValues(alpha: 0.9)),
        boxShadow: CgShadows.soft,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: CgColors.gray200,
                    backgroundImage: p.posterImageUrl != null && p.posterImageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(p.posterImageUrl!)
                        : null,
                    child: p.posterImageUrl == null || p.posterImageUrl!.isEmpty
                        ? const Icon(Icons.person, color: CgColors.gray500)
                        : null,
                  ),
                  if (p.posterPremium)
                    const Positioned(right: -2, bottom: -2, child: CgPremiumAvatarBadge(size: 16)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.posterName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        Text(timeAgo, style: const TextStyle(fontSize: 12, color: CgColors.gray500)),
                      ],
                    ),
                    if (p.posterHandicap != null)
                      Text(
                        '${p.posterHandicap} HCP',
                        style: const TextStyle(fontSize: 13, color: CgColors.gray600),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (p.posterPremium) const CgPremiumBadge(compact: true),
                        if (p.posterVerified)
                          const CgHandicapVerifiedBadge(compact: true, useShortLabel: true),
                        CgRatingChip(
                          averageRating: p.posterRating.averageRating,
                          reviewCount: p.posterRating.reviewCount,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 18, color: CgColors.green700),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.courseName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(p.locationLine, style: const TextStyle(fontSize: 13, color: CgColors.gray600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: CgColors.gray600),
              const SizedBox(width: 6),
              Text(dateLabel, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 16),
              const Icon(Icons.schedule_rounded, size: 16, color: CgColors.gray600),
              const SizedBox(width: 6),
              Text(p.teeTime, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _styleChip(p.gameStyleLabel, _styleColor(p.gameStyle)),
              if (p.handicapPreference != null && p.handicapPreference!.isNotEmpty)
                _neutralChip(p.handicapPreference!),
              if (p.feeLabel != null && p.feeLabel!.isNotEmpty) _feeChip(p.feeLabel!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 18, color: CgColors.green700),
              const SizedBox(width: 6),
              _spotsDots(p.spotsNeeded),
              const SizedBox(width: 8),
              Text(
                '${p.spotsNeeded} spot${p.spotsNeeded == 1 ? '' : 's'} open',
                style: const TextStyle(color: CgColors.green700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (p.notes != null && p.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.notes!, style: const TextStyle(fontSize: 14, color: CgColors.gray700, height: 1.4)),
          ],
          const SizedBox(height: 14),
          if (isPremium)
            CgPrimaryButton(
              label: 'Join / Contact',
              onPressed: onContact,
            )
          else
            CgPremiumLockedCta(
              message: 'Contact this golfer — Upgrade to Premium',
              helpText: 'Premium members can reply and contact golfers',
              onUpgrade: onLockedTap,
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  static Color _styleColor(String style) {
    switch (style.toUpperCase()) {
      case 'COMPETITIVE':
        return CgColors.purple700;
      case 'TOURNAMENT':
        return CgColors.orange700;
      case 'SERIOUS':
        return CgColors.gray700;
      default:
        return CgColors.green700;
    }
  }

  Widget _styleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _neutralChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CgColors.gray100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CgColors.gray700)),
    );
  }

  Widget _feeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CgColors.green50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CgColors.green700)),
    );
  }

  Widget _spotsDots(int spotsOpen) {
    final filled = (4 - spotsOpen).clamp(0, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final occupied = i < filled;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: occupied ? CgColors.green600 : CgColors.gray200,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _CreatePostFields {
  _CreatePostFields({
    required this.courseName,
    this.city,
    this.state,
    required this.roundDateIso,
    required this.teeTime,
    required this.spotsNeeded,
    required this.gameStyle,
    this.handicapPreference,
    this.feeLabel,
    this.notes,
  });

  final String courseName;
  final String? city;
  final String? state;
  final String roundDateIso;
  final String teeTime;
  final int spotsNeeded;
  final String gameStyle;
  final String? handicapPreference;
  final String? feeLabel;
  final String? notes;
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.onSubmit});

  final Future<void> Function(_CreatePostFields fields) onSubmit;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _course = TextEditingController();
  final _city = TextEditingController();
  final _teeTime = TextEditingController(text: '7:30 AM');
  final _hcpPref = TextEditingController();
  final _fee = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _spots = 1;
  String _style = 'CASUAL';
  String? _stateCode;
  bool _saving = false;

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: CgColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CgColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: CgColors.green700, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _course.dispose();
    _city.dispose();
    _teeTime.dispose();
    _hcpPref.dispose();
    _fee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_course.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_CreatePostFields(
        courseName: _course.text.trim(),
        city: _city.text.trim(),
        state: _stateCode,
        roundDateIso: DateTime(_date.year, _date.month, _date.day).toIso8601String(),
        teeTime: _teeTime.text.trim(),
        spotsNeeded: _spots,
        gameStyle: _style,
        handicapPreference: _hcpPref.text.trim(),
        feeLabel: _fee.text.trim(),
        notes: _notes.text.trim(),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dateLabel =
        '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_date.weekday - 1]}, '
        '${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_date.month - 1]} ${_date.day}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CgColors.gray300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Post open spot',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CgColors.gray900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Invite golfers to fill your foursome.',
              style: TextStyle(fontSize: 13, color: CgColors.gray500),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _course,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Course name *', hint: 'e.g. Harding Park'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('City', hint: 'San Francisco'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _stateCode,
                    isExpanded: true,
                    decoration: _fieldDecoration('State'),
                    hint: const Text('Select', style: TextStyle(fontSize: 14)),
                    items: kUsStates
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.code,
                            child: Text(s.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _stateCode = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_stateCode != null)
              Text(
                kUsStates.firstWhere((s) => s.code == _stateCode).name,
                style: const TextStyle(fontSize: 12, color: CgColors.gray500),
              ),
            const SizedBox(height: 12),
            Material(
              color: CgColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: CgColors.green700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Round date', style: TextStyle(fontSize: 12, color: CgColors.gray500)),
                            const SizedBox(height: 2),
                            Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: CgColors.gray400),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teeTime,
              decoration: _fieldDecoration('Tee time', hint: '7:30 AM'),
            ),
            const SizedBox(height: 12),
            const Text(
              'SPOTS NEEDED',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: CgColors.gray500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3].map((n) {
                final selected = _spots == n;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: n == 3 ? 0 : 8),
                    child: Material(
                      color: selected ? CgColors.green700 : CgColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _spots = n),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '$n',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? CgColors.white : CgColors.gray700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'GAME STYLE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: CgColors.gray500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                ('CASUAL', 'Casual'),
                ('SERIOUS', 'Serious'),
                ('TOURNAMENT', 'Tournament'),
              ].map((entry) {
                final selected = _style == entry.$1;
                return Material(
                  color: selected ? CgColors.green700 : CgColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _style = entry.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        entry.$2,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? CgColors.white : CgColors.gray700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _hcpPref,
              decoration: _fieldDecoration('Handicap preference', hint: 'e.g. HCP 10–18'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fee,
              decoration: _fieldDecoration('Green fee / entry (optional)', hint: '\$85 green fee'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration('Notes', hint: 'Pace of play, net scoring, etc.'),
            ),
            const SizedBox(height: 22),
            CgPrimaryButton(
              label: _saving ? 'Posting…' : 'Post to feed',
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
