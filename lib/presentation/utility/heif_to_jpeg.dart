import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:image/image.dart' as img;

/// Non-web branch of `HeifConverter`.
///
/// The engine decodes HEIF with the platform codecs: ImageIO on iOS and
/// macOS, `ImageDecoder` on Android 9 and later. Both apply the orientation
/// stored in the photo, so the pixels come out upright. `dart:ui` encodes PNG
/// only, and a photo in PNG weighs several times more, so the JPEG is encoded
/// in Dart, on a background isolate.
///
/// The result is written to a temporary file: an `XFile` made from bytes has
/// no name outside the web, and whatever needs a path — `Image.file`, a
/// multipart upload — would fail on it. The system clears the temporary
/// directory by itself.
///
/// Throws when the platform cannot decode HEIF: Android 8 and earlier, Linux,
/// Windows without the HEIF extension.
Future<XFile?> heifToJpeg(
  Uint8List bytes, {
  required String name,
  required int quality,
  required ({int width, int height}) Function(int width, int height) targetSize,
}) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    bytes,
  );
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;

  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final ({int width, int height}) size = targetSize(
      descriptor.width,
      descriptor.height,
    );

    codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    image = (await codec.getNextFrame()).image;

    final ByteData? pixels = await image.toByteData();
    if (pixels == null) return null;

    final Uint8List jpeg = await _encode(
      pixels,
      width: image.width,
      height: image.height,
      quality: quality,
    );

    final Directory directory = await Directory.systemTemp.createTemp('heif_');
    final File file = await File(
      '${directory.path}${Platform.pathSeparator}$name',
    ).writeAsBytes(jpeg, flush: true);

    return XFile(file.path, mimeType: 'image/jpeg', length: jpeg.length);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// A function of its own, so the isolate closure captures the pixels and
/// nothing of the caller's scope.
Future<Uint8List> _encode(
  ByteData pixels, {
  required int width,
  required int height,
  required int quality,
}) => Isolate.run(
  () => img.encodeJpg(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    ),
    quality: quality,
    chroma: img.JpegChroma.yuv420,
  ),
);
