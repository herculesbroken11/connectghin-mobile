import 'dart:convert';
import 'dart:typed_data';

import 'package:connectghin_flutter/core/network/api_client.dart';
import 'package:connectghin_flutter/features/profile/data/profile_posts_api.dart';
import 'package:connectghin_flutter/features/profile/profile_post_image.dart';
import 'package:connectghin_flutter/features/profile/profile_post_submit.dart';
import 'package:connectghin_flutter/features/profile/share_moment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Uint8List get _pngBytes => base64Decode(_png);

/// iPhone HEIC: `ftyp` box, major brand `mif1`, compatible brand `heic`, then payload.
Uint8List get _heicBytes => Uint8List.fromList(<int>[
      0x00, 0x00, 0x00, 0x18, // box size
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x6d, 0x69, 0x66, 0x31, // mif1
      0x00, 0x00, 0x00, 0x00,
      0x6d, 0x69, 0x66, 0x31, // mif1
      0x68, 0x65, 0x69, 0x63, // heic
      0x00, 0x11, 0x22, 0x33,
    ]);

img.Image _onePixel() {
  final bitmap = img.Image(width: 1, height: 1);
  bitmap.setPixelRgb(0, 0, 12, 34, 56);
  return bitmap;
}

Future<List<int>> _uploadedBytes(http.MultipartFile part) {
  return part.finalize().fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
}

void main() {
  test('HEIC bytes are re-encoded as JPEG and are not the original container', () async {
    final bitmap = _onePixel();
    final part = await profilePostImageFile(
      bytes: _heicBytes,
      filename: 'IMG_0001.HEIC',
      decodeHeic: (input) async {
        expect(input, _heicBytes);
        return bitmap;
      },
    );
    final uploaded = await _uploadedBytes(part);
    final encoded = encodeProfilePostJpeg(bitmap);
    expect(part.field, 'file');
    expect(part.filename, 'photo.jpg');
    expect(part.contentType.mimeType, 'image/jpeg');
    expect(uploaded, encoded);
    expect(uploaded.sublist(0, 3), <int>[0xFF, 0xD8, 0xFF]);
    expect(uploaded.sublist(uploaded.length - 2), <int>[0xFF, 0xD9]);
    expect(uploaded, isNot(equals(_heicBytes)));
    expect(String.fromCharCodes(uploaded.sublist(4, 8)), isNot('ftyp'));
  });

  test('extension-less HEIC is converted the same way', () async {
    final bitmap = _onePixel();
    final part = await profilePostImageFile(
      bytes: _heicBytes,
      filename: 'tmp',
      decodeHeic: (_) async => bitmap,
    );
    final uploaded = await _uploadedBytes(part);
    expect(part.filename, 'photo.jpg');
    expect(uploaded, encodeProfilePostJpeg(bitmap));
    expect(uploaded, isNot(equals(_heicBytes)));
  });

  test('a failed HEIC decode is not uploaded as the original container', () async {
    await expectLater(
      profilePostImageFile(
        bytes: _heicBytes,
        filename: 'IMG.HEIC',
        decodeHeic: (_) async => throw StateError('ImageIO could not decode HEIC'),
      ),
      throwsA(isA<ProfilePostFailure>()),
    );
  });

  test('Flutter image decode plus JPEG encode is a JPEG, not the source bytes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bitmap = await decodeProfilePostBitmapWithEngine(_pngBytes);
    final jpeg = encodeProfilePostJpeg(bitmap);
    expect(jpeg.sublist(0, 3), <int>[0xFF, 0xD8, 0xFF]);
    expect(jpeg.sublist(jpeg.length - 2), <int>[0xFF, 0xD9]);
    expect(jpeg, isNot(equals(_pngBytes)));
  });

  test('PNG bytes keep their signature even when the picker name is HEIC', () async {
    final part = await profilePostImageFile(
      bytes: _pngBytes,
      filename: 'image_picker_ABC123.HEIC',
    );
    final uploaded = await _uploadedBytes(part);
    expect(part.filename, 'photo.png');
    expect(part.contentType.mimeType, 'image/png');
    expect(uploaded, _pngBytes);
  });

  test('extension-less JPEG bytes are uploaded unchanged', () async {
    final jpeg = encodeProfilePostJpeg(_onePixel());
    final part = await profilePostImageFile(bytes: jpeg, filename: 'tmp');
    final uploaded = await _uploadedBytes(part);
    expect(part.filename, 'photo.jpg');
    expect(part.contentType.mimeType, 'image/jpeg');
    expect(uploaded, jpeg);
  });

  test('bytes that are neither a photo nor HEIC are rejected', () async {
    await expectLater(
      profilePostImageFile(bytes: const [9, 8, 7], filename: 'tmp'),
      throwsA(isA<ProfilePostFailure>()),
    );
  });

  test('empty image bytes are rejected before upload', () async {
    await expectLater(
      profilePostImageFile(bytes: const [], filename: 'photo.jpg'),
      throwsA(
        isA<ProfilePostFailure>().having(
          (e) => e.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );
  });

  test('terms-required response is detected and can be retried', () async {
    final termsBody = jsonEncode({
      'statusCode': 403,
      'message': {
        'code': 'TERMS_ACCEPTANCE_REQUIRED',
        'message': 'Accept the Terms of Service before creating content.',
        'termsVersion': '2026-08-31',
      },
    });
    var termsChecks = 0;
    var sends = 0;
    await submitProfilePost(
      ensureTerms: () async {
        termsChecks++;
        return true;
      },
      send: () async {
        sends++;
        if (sends == 1) {
          throw ApiHttpException(403, termsBody);
        }
      },
    );
    expect(termsChecks, 2);
    expect(sends, 2);
    expect(isTermsAcceptanceRequired(ApiHttpException(403, termsBody)), isTrue);
    expect(
      profilePostFailureMessage(ApiHttpException(403, termsBody)),
      'Accept the Terms of Service to post.',
    );
    expect(
      profilePostFailureMessage(ApiHttpException(403, termsBody)).toLowerCase(),
      isNot(contains('/api/')),
    );
  });

  test('declining terms does not send the post', () async {
    var sends = 0;
    await expectLater(
      submitProfilePost(
        ensureTerms: () async => false,
        send: () async {
          sends++;
        },
      ),
      throwsA(isA<ProfilePostFailure>()),
    );
    expect(sends, 0);
  });

  test('backend failure message does not include the raw body', () {
    final error = ApiHttpException(
      500,
      '{"statusCode":500,"message":"prisma error at postgres://secret","path":"/api/v1/profile-posts/upload"}',
    );
    final message = profilePostFailureMessage(error);
    expect(message, 'Server error. Please try again later.');
    expect(message, isNot(contains('postgres')));
    expect(message, isNot(contains('profile-posts')));
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required Future<void> Function(ShareMomentDraft draft) onPost,
    PickShareMomentImage? pickImage,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ShareMomentSheet(
                    onPost: onPost,
                    pickImage: pickImage,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('caption and image post, then the sheet closes after success', (tester) async {
    ShareMomentDraft? sent;
    var refreshed = false;
    await openSheet(
      tester,
      pickImage: () async => XFile.fromData(
        _pngBytes,
        name: 'IMG_0001.HEIC',
        mimeType: 'image/heic',
      ),
      onPost: (draft) async {
        sent = draft;
        refreshed = true;
      },
    );
    await tester.enterText(find.byType(TextField), 'Had a great day on the course.');
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo selected'), findsOneWidget);
    await tester.tap(find.text('Post to profile'));
    await tester.pumpAndSettle();
    expect(sent?.caption, 'Had a great day on the course.');
    expect(sent?.hasImage, isTrue);
    expect(sent?.imageBytes, _pngBytes);
    expect(refreshed, isTrue);
    expect(find.text('Share a moment'), findsNothing);
  });

  testWidgets('posting shows a loading state and ignores a second tap', (tester) async {
    var calls = 0;
    await openSheet(
      tester,
      onPost: (_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
    );
    await tester.enterText(find.byType(TextField), 'Caption only');
    await tester.tap(find.text('Post to profile'));
    await tester.pump();
    expect(find.text('Posting…'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    await tester.tap(find.text('Posting…'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('a failed post shows an error and leaves the button usable', (tester) async {
    await openSheet(
      tester,
      onPost: (_) async {
        throw Exception('ClientException: Connection timed out');
      },
    );
    await tester.enterText(find.byType(TextField), 'Had a great day on the course.');
    await tester.tap(find.text('Post to profile'));
    await tester.pumpAndSettle();
    expect(find.text('Share a moment'), findsOneWidget);
    expect(find.textContaining('Cannot reach Connectghin'), findsOneWidget);
    expect(find.text('Post to profile'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
  });

  testWidgets('a terms failure stays on the sheet with a visible message', (tester) async {
    await openSheet(
      tester,
      onPost: (_) async {
        throw const ProfilePostFailure('Accept the Terms of Service to post.');
      },
    );
    await tester.enterText(find.byType(TextField), 'Had a great day on the course.');
    await tester.tap(find.text('Post to profile'));
    await tester.pumpAndSettle();
    expect(find.text('Accept the Terms of Service to post.'), findsOneWidget);
    expect(find.text('Post to profile'), findsOneWidget);
  });
}
