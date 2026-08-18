import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/design_tokens.dart';
import '../../app/session/auth_session.dart';
import '../../core/network/api_user_message.dart';
import '../profiles/data/profiles_api.dart';

/// GHINder-style grid: reorder, primary, delete, add slot, tips.
class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({super.key});

  static const maxPhotos = 6;
  static const minPhotos = 2;

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploadingFile = false;
  String? _busyPhotoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    try {
      final me = await ProfilesApi(session.apiClient).getMe(t);
      final user = me['user'] as Map<String, dynamic>?;
      final photos = user?['profilePhotos'] as List<dynamic>? ?? [];
      final list = photos.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      list.sort((a, b) {
        final sa = a['sortOrder'];
        final sb = b['sortOrder'];
        final ia = sa is int ? sa : int.tryParse('$sa') ?? 0;
        final ib = sb is int ? sb : int.tryParse('$sb') ?? 0;
        return ia.compareTo(ib);
      });
      if (!mounted) return;
      setState(() {
        _photos = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_photos.length >= ManagePhotosScreen.maxPhotos) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final img = await pickProfilePhoto(_picker);
    if (img == null) return;
    setState(() => _uploadingFile = true);
    try {
      await ProfilesApi(session.apiClient).uploadPhotoFile(accessToken: t, filePath: img.path);
      if (!mounted) return;
      await _load();
      session.bumpProfileRefresh();
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _uploadingFile = false);
    }
  }

  Future<void> _delete(String photoId) async {
    if (_photos.length <= ManagePhotosScreen.minPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need at least ${ManagePhotosScreen.minPhotos} photos on your profile.')),
        );
      }
      return;
    }
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _busyPhotoId = photoId);
    try {
      await ProfilesApi(session.apiClient).deletePhoto(accessToken: t, photoId: photoId);
      if (!mounted) return;
      await _load();
      session.bumpProfileRefresh();
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _busyPhotoId = null);
    }
  }

  Future<void> _confirmDelete(String photoId) async {
    if (_photos.length <= ManagePhotosScreen.minPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum ${ManagePhotosScreen.minPhotos} photos required.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text('This photo will be removed from your profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: CgColors.destructive)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _delete(photoId);
  }

  Future<void> _setPrimary(String photoId) async {
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    setState(() => _busyPhotoId = photoId);
    try {
      await ProfilesApi(session.apiClient).setPrimaryPhoto(accessToken: t, photoId: photoId);
      if (!mounted) return;
      await _load();
      session.bumpProfileRefresh();
    } catch (e) {
      if (mounted) {
        showApiErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _busyPhotoId = null);
    }
  }

  Future<void> _moveTo(int fromIndex, int toIndex) async {
    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= _photos.length || toIndex >= _photos.length) return;
    final session = context.read<AuthSession>();
    final t = session.accessToken;
    if (t == null) return;
    final next = [..._photos];
    final item = next.removeAt(fromIndex);
    next.insert(toIndex, item);
    setState(() => _photos = next);
    final ids = next.map((e) => e['id'] as String).toList();
    try {
      await ProfilesApi(session.apiClient).reorderPhotos(accessToken: t, orderedPhotoIds: ids);
      session.bumpProfileRefresh();
    } catch (e) {
      if (mounted) {
        await _load();
        if (!mounted) return;
        showApiErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _photos.length;
    final subtitle = '$n of ${ManagePhotosScreen.maxPhotos} photos • Minimum ${ManagePhotosScreen.minPhotos} required';

    return Scaffold(
      backgroundColor: CgColors.white,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CgColors.green700))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    const Text(
                      'Manage Photos',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: CgColors.gray900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 15, color: CgColors.gray600),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: n + (n < ManagePhotosScreen.maxPhotos ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < n) {
                          return _PhotoTile(
                            photo: _photos[index],
                            index: index,
                            busy: _busyPhotoId == (_photos[index]['id'] as String),
                            onMoveUp: index > 0 ? () => _moveTo(index, index - 1) : null,
                            onMoveDown: index < n - 1 ? () => _moveTo(index, index + 1) : null,
                            onSetPrimary: () => _setPrimary(_photos[index]['id'] as String),
                            onDelete: () => _confirmDelete(_photos[index]['id'] as String),
                          );
                        }
                        return _AddPhotoTile(
                          loading: _uploadingFile,
                          onTap: _uploadingFile ? null : _pickAndUpload,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _TipsCard(),
                  ],
                ),
                if (_uploadingFile)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black26,
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: CgColors.green700),
                                SizedBox(height: 12),
                                Text('Uploading…', style: TextStyle(color: CgColors.gray700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.busy,
    required this.onSetPrimary,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final Map<String, dynamic> photo;
  final int index;
  final bool busy;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final url = photo['imageUrl'] as String? ?? '';
    final isPrimary = photo['isPrimary'] == true;
    final showNumber = index + 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: CgColors.gray100,
            child: url.isEmpty
                ? const Icon(Icons.image_not_supported_outlined, size: 40, color: CgColors.gray400)
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 40),
                  ),
          ),
          if (isPrimary)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CgColors.green700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: CgColors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Primary',
                      style: TextStyle(color: CgColors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: Text(
                '$showNumber',
                style: const TextStyle(color: CgColors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMoveUp != null)
                    _RoundIconBtn(icon: Icons.keyboard_arrow_up_rounded, onPressed: busy ? null : onMoveUp),
                  if (onMoveUp != null && onMoveDown != null) const SizedBox(height: 4),
                  if (onMoveDown != null)
                    _RoundIconBtn(icon: Icons.keyboard_arrow_down_rounded, onPressed: busy ? null : onMoveDown),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: isPrimary
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: CgColors.destructive,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: busy ? null : onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.delete_outline_rounded, color: CgColors.white, size: 20),
                        ),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: busy ? null : onSetPrimary,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_outline_rounded, color: CgColors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Set Primary',
                                    style: TextStyle(color: CgColors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: CgColors.destructive,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: busy ? null : onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.delete_outline_rounded, color: CgColors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (busy)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2, color: CgColors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, color: CgColors.white, size: 22),
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.loading, this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CgColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: CgColors.gray300),
          child: Center(
            child: loading
                ? const CircularProgressIndicator(color: CgColors.green700)
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_rounded, size: 36, color: CgColors.gray500),
                      SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CgColors.gray600),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final e = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, e), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Use the arrows to reorder your photos',
      'Your primary photo appears first on your profile',
      'Clear, recent photos get more matches',
      'Show yourself on the course or with your clubs',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CgColors.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: CgColors.blue700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CgColors.blue700,
                  ),
                ),
                const SizedBox(height: 8),
                ...bullets.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: CgColors.blue700, height: 1.4)),
                        Expanded(
                          child: Text(
                            t,
                            style: const TextStyle(fontSize: 14, height: 1.45, color: CgColors.blue700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
