import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'profile_post_submit.dart';

const int profilePostJpegQuality = 85;

const _unreadablePhoto = ProfilePostFailure(
  'That photo could not be read. Please try another image.',
);

/// Decodes a HEIC/HEIF still into pixels. Production uses the Flutter engine,
/// which on iOS is ImageIO (`instantiateImageCodec`).
typedef ProfilePostBitmapDecoder = Future<img.Image> Function(Uint8List bytes);

bool profilePostBytesAreJpeg(List<int> bytes) {
  return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

bool profilePostBytesArePng(List<int> bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

bool profilePostBytesAreGif(List<int> bytes) {
  return bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38;
}

bool profilePostBytesAreWebp(List<int> bytes) {
  return bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

/// ISO-BMFF stills from the iOS photo library (HEIC/HEIF). Major brand is often `mif1`.
bool profilePostBytesAreHeic(List<int> bytes) {
  if (bytes.length < 12) return false;
  if (bytes[4] != 0x66 || bytes[5] != 0x74 || bytes[6] != 0x79 || bytes[7] != 0x70) {
    return false;
  }
  final boxEnd = bytes.length < 32 ? bytes.length : 32;
  final brands = String.fromCharCodes(bytes.sublist(8, boxEnd));
  const markers = ['heic', 'heix', 'hevc', 'heif', 'mif1', 'msf1', 'heim', 'heis'];
  for (final marker in markers) {
    if (brands.contains(marker)) return true;
  }
  return false;
}

/// JPEG bytes from a decoded bitmap. This is the encode step after HEIC decode.
Uint8List encodeProfilePostJpeg(img.Image bitmap) {
  final encoded = img.encodeJpg(bitmap, quality: profilePostJpegQuality);
  final hasEoi = encoded.length >= 4 &&
      encoded[encoded.length - 2] == 0xFF &&
      encoded[encoded.length - 1] == 0xD9;
  if (!profilePostBytesAreJpeg(encoded) || !hasEoi) {
    throw _unreadablePhoto;
  }
  return encoded;
}

/// Flutter engine decode. On iOS, ImageIO decodes HEIC into a bitmap.
Future<img.Image> decodeProfilePostBitmapWithEngine(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw _unreadablePhoto,
    );
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = uiImage.width;
    final height = uiImage.height;
    uiImage.dispose();
    codec.dispose();
    if (byteData == null || width <= 0 || height <= 0) {
      throw _unreadablePhoto;
    }
    final raw = Uint8List.fromList(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: raw.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } on ProfilePostFailure {
    rethrow;
  } catch (_) {
    throw _unreadablePhoto;
  }
}

/// Decode HEIC/HEIF, then re-encode with [encodeProfilePostJpeg]. Never returns the source bytes.
Future<Uint8List> transcodeProfilePostHeicToJpeg(
  Uint8List bytes, {
  ProfilePostBitmapDecoder? decodeHeic,
}) async {
  final img.Image bitmap;
  try {
    bitmap = await (decodeHeic ?? decodeProfilePostBitmapWithEngine)(bytes);
  } on ProfilePostFailure {
    rethrow;
  } catch (_) {
    throw _unreadablePhoto;
  }
  final jpeg = encodeProfilePostJpeg(bitmap);
  if (_sameBytes(jpeg, bytes)) {
    throw _unreadablePhoto;
  }
  return jpeg;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
