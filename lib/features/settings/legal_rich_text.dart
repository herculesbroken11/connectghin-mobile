import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design_tokens.dart';

const legalBodyStyle = TextStyle(fontSize: 15, height: 1.5, color: CgColors.gray700);

final RegExp _legalToken = RegExp(
  r'https://connectghin\.com/(?:terms|privacy|child-safety|delete-account)|support@connectghin\.com|privacy@connectghin\.com',
);

/// Renders legal copy with the canonical website and email addresses tappable.
class LegalRichText extends StatefulWidget {
  const LegalRichText(this.text, {super.key, this.style = legalBodyStyle});

  final String text;
  final TextStyle style;

  @override
  State<LegalRichText> createState() => _LegalRichTextState();
}

class _LegalRichTextState extends State<LegalRichText> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _linkSpans(widget.text);
  }

  @override
  void didUpdateWidget(LegalRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _spans = _linkSpans(widget.text);
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _linkSpans(String text) {
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _legalToken.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final token = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _open(token);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: token,
          style: const TextStyle(
            color: CgColors.blue700,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _spans, style: widget.style));
  }

  Future<void> _open(String token) async {
    final uri = token.contains('@') ? Uri(scheme: 'mailto', path: token) : Uri.parse(token);
    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: token.contains('@') ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $token')),
      );
    }
  }
}
