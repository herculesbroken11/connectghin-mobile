import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/design_tokens.dart';
import '../../core/widgets/cg_primary_button.dart';
import 'profile_post_submit.dart';

class ShareMomentDraft {
  const ShareMomentDraft({
    required this.caption,
    this.imageBytes,
    this.imageFilename,
  });

  final String caption;
  final Uint8List? imageBytes;
  final String? imageFilename;

  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
}

typedef PickShareMomentImage = Future<XFile?> Function();

/// Existing "Share a moment" composer. Photo library only.
class ShareMomentSheet extends StatefulWidget {
  const ShareMomentSheet({
    super.key,
    required this.onPost,
    this.pickImage,
  });

  final Future<void> Function(ShareMomentDraft draft) onPost;
  final PickShareMomentImage? pickImage;

  @override
  State<ShareMomentSheet> createState() => _ShareMomentSheetState();
}

class _ShareMomentSheetState extends State<ShareMomentSheet> {
  final _captionCtrl = TextEditingController();
  final _gate = ProfilePostSubmitGate();
  Uint8List? _imageBytes;
  String? _imageFilename;
  String? _error;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<XFile?> _pickImage() {
    final custom = widget.pickImage;
    if (custom != null) return custom();
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
  }

  Future<void> _choosePhoto() async {
    if (_gate.isBusy) return;
    try {
      final file = await _pickImage();
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() {
          _error = 'That photo could not be read. Please try another image.';
        });
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageFilename = file.name;
        _error = null;
      });
    } catch (e) {
      logProfilePostFailure(e);
      if (!mounted) return;
      setState(() {
        _error = 'That photo could not be read. Please try another image.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_gate.tryBegin()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final caption = _captionCtrl.text.trim();
    final bytes = _imageBytes;
    if (caption.isEmpty && (bytes == null || bytes.isEmpty)) {
      _gate.finish();
      setState(() => _error = 'Add a caption or a photo');
      return;
    }
    setState(() => _error = null);
    try {
      await widget.onPost(
        ShareMomentDraft(
          caption: caption,
          imageBytes: bytes,
          imageFilename: _imageFilename,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      logProfilePostFailure(e);
      _gate.finish();
      if (!mounted) return;
      setState(() => _error = profilePostFailureMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _gate.isBusy;
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
              'Share a moment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Course, group pic, landscape — or just a caption.',
              style: TextStyle(fontSize: 13, color: CgColors.gray500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionCtrl,
              enabled: !busy,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Great pace today at Harding Park…',
                filled: true,
                fillColor: CgColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _choosePhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_imageBytes == null ? 'Add photo' : 'Photo selected'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: CgColors.green700),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: CgColors.red700,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            CgPrimaryButton(
              label: busy ? 'Posting…' : 'Post to profile',
              onPressed: busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
