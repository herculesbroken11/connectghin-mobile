import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import 'data/player_ratings_api.dart';

class PlayerRatingsScreen extends StatefulWidget {
  const PlayerRatingsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<PlayerRatingsScreen> createState() => _PlayerRatingsScreenState();
}

class _PlayerRatingsScreenState extends State<PlayerRatingsScreen> {
  bool _loading = true;
  String? _error;
  String _status = 'all';
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _summary;
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final token = session.accessToken;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = PlayerRatingsApi(session.apiClient);
      final data = await api.listForUser(
        token,
        widget.userId,
        status: _status,
        page: 0,
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List<dynamic>? ?? const []);
        _summary = data['profileSummary'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageFromApiError(e);
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((raw) {
      final m = raw as Map<String, dynamic>;
      final n = '${m['reviewerName'] ?? ''}'.toLowerCase();
      final c = '${m['comment'] ?? ''}'.toLowerCase();
      return n.contains(q) || c.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final avg = (_summary?['averageRating'] as num?)?.toDouble() ?? 0;
    final total = (_summary?['totalRatings'] as num?)?.toInt() ?? _items.length;
    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        title: const Text('Player Ratings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      const Text(
                        'Player Ratings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: CgColors.gray900,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Read golfer feedback and round evaluations.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: CgColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: CgColors.white,
                          borderRadius: BorderRadius.circular(CgRadii.xxl),
                          border: Border.all(color: CgColors.gray200),
                        ),
                        child: Row(
                          children: [
                            _stars(avg),
                            const SizedBox(width: 8),
                            Text(
                              avg.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$total total ratings',
                              style: const TextStyle(color: CgColors.gray600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            _statusChip('all', 'All'),
                            _statusChip('approved', 'Approved'),
                            _statusChip('flagged', 'Flagged'),
                            _statusChip('pending', 'Pending'),
                            _statusChip('removed', 'Removed'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 15, height: 1.2),
                              decoration: InputDecoration(
                                hintText: 'Search by reviewer...',
                                hintStyle: const TextStyle(color: CgColors.gray400, fontSize: 15),
                                isDense: true,
                                filled: true,
                                fillColor: CgColors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                                prefixIcon: const Icon(Icons.search, size: 22, color: CgColors.gray500),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(CgRadii.xxl),
                                  borderSide: const BorderSide(color: CgColors.gray200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(CgRadii.xxl),
                                  borderSide: const BorderSide(color: CgColors.gray200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(CgRadii.xxl),
                                  borderSide: const BorderSide(color: CgColors.green700, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No ratings found.', style: TextStyle(color: CgColors.gray600))),
                        ),
                      for (final raw in _filtered) _ratingCard(raw as Map<String, dynamic>),
                    ],
                  ),
                ),
    );
  }

  Widget _ratingCard(Map<String, dynamic> r) {
    final wouldPlayAgain = r['wouldPlayAgain'] == true;
    final status = '${r['status'] ?? 'pending'}';
    final flagged = status == 'flagged';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(CgRadii.xxl),
        border: Border.all(color: flagged ? CgColors.red400.withValues(alpha: 0.35) : CgColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r['reviewerName'] ?? 'Reviewer'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              _stars((r['overallRating'] as num?)?.toDouble() ?? 0),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Played ${r['roundDate'] ?? '-'} · Submitted ${r['submittedDate'] ?? '-'}',
            style: const TextStyle(fontSize: 12, height: 1.25, color: CgColors.gray500),
          ),
          const SizedBox(height: 12),
          Text(
            '${r['comment'] ?? ''}',
            style: const TextStyle(fontSize: 15, color: CgColors.gray700, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: wouldPlayAgain ? CgColors.green50 : CgColors.red50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              wouldPlayAgain ? 'Would play again' : 'Would not play again',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: wouldPlayAgain ? CgColors.green700 : CgColors.red700,
              ),
            ),
          ),
          if ((r['reportedReason'] as String?) != null && (r['reportedReason'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CgColors.red50,
                borderRadius: BorderRadius.circular(CgRadii.lg),
                border: Border.all(color: CgColors.red400.withValues(alpha: 0.4)),
              ),
              child: Text('Flag reason: ${r['reportedReason']}', style: const TextStyle(fontSize: 12, color: CgColors.red700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (_status == value) return;
          setState(() => _status = value);
          _load();
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? CgColors.green100 : CgColors.white,
            border: Border.all(
              color: selected ? CgColors.green700 : CgColors.gray300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: selected ? CgColors.green800 : CgColors.gray700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stars(double rating) {
    final rounded = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < rounded ? Icons.star_rounded : Icons.star_border_rounded,
            color: CgColors.yellow500,
            size: 18,
          ),
      ],
    );
  }
}

class SubmitPlayerRatingScreen extends StatefulWidget {
  const SubmitPlayerRatingScreen({super.key, required this.userId});

  final String userId;

  @override
  State<SubmitPlayerRatingScreen> createState() => _SubmitPlayerRatingScreenState();
}

class _SubmitPlayerRatingScreenState extends State<SubmitPlayerRatingScreen> {
  final _courseCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  DateTime _roundDate = DateTime.now();
  int _overall = 5;
  int _handicap = 5;
  int _sportsmanship = 5;
  int _pace = 5;
  bool _wouldPlayAgain = true;
  bool _saving = false;

  @override
  void dispose() {
    _courseCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = context.read<AuthSession>();
    final token = session.accessToken;
    if (token == null) return;
    final revieweeId = widget.userId.trim();
    if (revieweeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing player. Go back and open Rate Player from their profile.')));
      return;
    }
    final myId = session.userId;
    if (myId != null && myId == revieweeId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only rate other golfers.')));
      return;
    }
    if (_courseCtrl.text.trim().isEmpty || _commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill course and comment')));
      return;
    }
    setState(() => _saving = true);
    try {
      await PlayerRatingsApi(session.apiClient).create(
        accessToken: token,
        revieweeUserId: widget.userId,
        roundDateIso: _roundDate.toIso8601String(),
        course: _courseCtrl.text.trim(),
        overallRating: _overall,
        handicapAccuracy: _handicap,
        sportsmanship: _sportsmanship,
        paceOfPlay: _pace,
        wouldPlayAgain: _wouldPlayAgain,
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating submitted')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final myId = session.userId;
    final revieweeId = widget.userId.trim();
    final cannotRateHere = revieweeId.isEmpty || (myId != null && myId == revieweeId);

    if (cannotRateHere) {
      return Scaffold(
        backgroundColor: CgColors.gray50,
        appBar: AppBar(
          title: const Text('Rate Player'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              revieweeId.isEmpty
                  ? 'This screen needs a player to rate. Open someone’s profile and tap Rate Player.'
                  : 'Player ratings are for other golfers. Open their profile and tap Rate Player.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4, color: CgColors.gray700),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CgColors.gray50,
      appBar: AppBar(
        title: const Text('Rate Player'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Share fair, constructive feedback about the round.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: CgColors.gray600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _courseCtrl,
            style: const TextStyle(fontSize: 15, height: 1.2),
            decoration: _input('Course'),
          ),
          const SizedBox(height: 12),
          Material(
            color: CgColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CgRadii.xxl),
              side: const BorderSide(color: CgColors.gray200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(CgRadii.xxl),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDate: _roundDate,
                );
                if (d != null) setState(() => _roundDate = d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Round date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CgColors.gray500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_roundDate.toLocal()}'.split(' ')[0],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CgColors.gray900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 22, color: CgColors.gray500),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ratingSelector('Overall', _overall, (v) => setState(() => _overall = v)),
          _ratingSelector('Handicap Accuracy', _handicap, (v) => setState(() => _handicap = v)),
          _ratingSelector('Sportsmanship', _sportsmanship, (v) => setState(() => _sportsmanship = v)),
          _ratingSelector('Pace of Play', _pace, (v) => setState(() => _pace = v)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _wouldPlayAgain,
            onChanged: (v) => setState(() => _wouldPlayAgain = v),
            title: const Text('Would play again'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 15, height: 1.35),
            decoration: _input('Write feedback'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: CgColors.green700,
                foregroundColor: CgColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CgRadii.xxl),
                ),
              ),
              child: Text(_saving ? 'Submitting...' : 'Submit Rating', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: CgColors.gray400, fontSize: 15),
        filled: true,
        fillColor: CgColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CgRadii.xxl),
          borderSide: const BorderSide(color: CgColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CgRadii.xxl),
          borderSide: const BorderSide(color: CgColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CgRadii.xxl),
          borderSide: const BorderSide(color: CgColors.green700, width: 1.5),
        ),
      );

  Widget _ratingSelector(String title, int value, ValueChanged<int> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(CgRadii.xxl),
        border: Border.all(color: CgColors.gray200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CgColors.gray700,
                height: 1.2,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: Icon(
                        i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                        color: CgColors.yellow500,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
