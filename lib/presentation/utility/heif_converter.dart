import 'dart:typed_data';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/presentation/utility/heif_to_jpeg.dart'
    if (dart.library.js_interop) 'package:application_base/presentation/utility/heif_to_jpeg_web.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Turns a HEIC / HEIF photo into a JPEG before it is shown or uploaded.
///
/// HEIC is what an iPhone camera shoots by default. Browsers other than
/// Safari cannot draw it, so a picked photo stays blank in a preview, and
/// many backends accept JPEG and PNG only. Convert right after picking: the
/// preview and the upload then get the same JPEG.
///
/// The format is told by the content, not by the name: a picker names a file
/// as it likes, and an extension proves nothing.
abstract final class HeifConverter {
  /// Longest side of a converted photo.
  ///
  /// A 12-megapixel iPhone photo (4032 px) keeps its size, a 48-megapixel one
  /// is scaled down. The bound comes from iOS Safari: a canvas there holds
  /// 16,777,216 pixels at most, and 4096 × 4096 is exactly that.
  static const int defaultMaxDimension = 4096;

  /// JPEG quality, 1–100.
  static const int defaultQuality = 90;

  /// Bytes enough to hold the `ftyp` box with the brands of any HEIF file.
  static const int _headerLength = 64;

  /// HEIF brands: still images (`heic`, `heix`, `mif1` and the multiview
  /// ones) and image sequences (`hevc`, `hevx`, `msf1` …). Burst and Live
  /// Photo stills come as sequences.
  static const Set<String> _heifBrandSet = {
    'heic',
    'heix',
    'heim',
    'heis',
    'hevc',
    'hevx',
    'hevm',
    'hevs',
    'mif1',
    'msf1',
  };

  /// AVIF lives in the same container and lists `mif1` among its brands.
  static const Set<String> _avifBrandSet = {'avif', 'avis'};

  /// [file] itself when it is not HEIF, a JPEG when it is, `null` when a
  /// HEIF photo cannot be converted: the platform has no HEIF decoder
  /// (Android 8, Linux), the file is broken, or the web decoder did not load.
  /// Every failure is logged. Never throws.
  static Future<XFile?> convertIfHeif(
    XFile file, {
    int maxDimension = defaultMaxDimension,
    int quality = defaultQuality,
  }) async {
    try {
      if (!await isHeif(file)) return file;

      final Uint8List bytes = await file.readAsBytes();
      final XFile? jpeg = await heifToJpeg(
        bytes,
        name: jpegName(file.name),
        quality: quality,
        targetSize: (width, height) => targetSize(
          width: width,
          height: height,
          maxDimension: maxDimension,
        ),
      );

      if (jpeg == null) {
        logError(error: 'HEIF: ${file.name} was not converted');
        return null;
      }

      logInfo(
        info:
            'HEIF: ${file.name} (${bytes.length} B) converted to '
            '${jpeg.name} (${await jpeg.length()} B)',
      );
      return jpeg;
    } catch (error) {
      logError(error: 'HEIF: ${file.name} was not converted: $error');
      return null;
    }
  }

  /// Whether [file] is a HEIF image, by its first bytes.
  static Future<bool> isHeif(XFile file) async {
    /// An `XFile` made from bytes throws on a range past its end
    final int length = await file.length();
    final int headerLength = length < _headerLength ? length : _headerLength;

    final builder = BytesBuilder(copy: false);
    await file.openRead(0, headerLength).forEach(builder.add);

    return isHeifHeader(builder.takeBytes());
  }

  /// Reads the brands of an ISO media file: the size of the `ftyp` box, its
  /// type, the major brand, a minor version and the compatible brands.
  /// MP4 and MOV videos share the container and differ by brands.
  @visibleForTesting
  static bool isHeifHeader(Uint8List header) {
    if (header.length < 12) return false;
    if (String.fromCharCodes(header, 4, 8) != 'ftyp') return false;

    final int boxSize = ByteData.sublistView(header).getUint32(0);
    final int end = boxSize < header.length ? boxSize : header.length;

    final List<String> brandList = [
      String.fromCharCodes(header, 8, 12),
      for (int offset = 16; offset + 4 <= end; offset += 4)
        String.fromCharCodes(header, offset, offset + 4),
    ];

    if (brandList.any(_avifBrandSet.contains)) return false;

    return brandList.any(_heifBrandSet.contains);
  }

  /// The name of the converted file: the extension becomes `.jpg`, the rest
  /// stays, so a recipient sees the name of the photo they picked.
  @visibleForTesting
  static String jpegName(String name) {
    final int dotIndex = name.lastIndexOf('.');
    final String baseName = dotIndex >= 0 ? name.substring(0, dotIndex) : name;

    return '${baseName.isEmpty ? 'image' : baseName}.jpg';
  }

  /// A frame of [width] × [height] fitted into [maxDimension] with its
  /// proportions kept. A smaller frame is never scaled up.
  @visibleForTesting
  static ({int width, int height}) targetSize({
    required int width,
    required int height,
    required int maxDimension,
  }) {
    final int longSide = width > height ? width : height;
    if (longSide <= maxDimension) return (width: width, height: height);

    final double scale = maxDimension / longSide;

    return (
      width: (width * scale).round().clamp(1, maxDimension),
      height: (height * scale).round().clamp(1, maxDimension),
    );
  }
}
