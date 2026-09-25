import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:application_base/core/service/logger_service.dart';
import 'package:cross_file/cross_file.dart';
import 'package:web/web.dart' as web;

/// heic-to 1.5.2 (libheif 1.22.2, LGPL-3.0), its build for pages under a
/// Content Security Policy: libheif is compiled to plain JavaScript there and
/// needs neither `unsafe-eval` nor `wasm-unsafe-eval`. It decodes in a worker
/// it starts from a `blob:` address, so the policy has to allow `blob:` in
/// `worker-src`.
///
/// The asset is declared for the web only and is not bundled into the
/// application on other platforms.
const String _libraryAsset =
    'packages/application_base/assets/heic_to/heic-to.js';

/// Loaded once, on the first photo the browser cannot decode itself.
Future<_HeicTo>? _library;

/// Web branch of `HeifConverter`.
///
/// Safari decodes HEIC itself — and on iOS every browser runs on its engine —
/// so the photo is first handed to the browser. Chrome and Firefox reject it,
/// and only then heic-to is loaded: three megabytes a page downloads when it
/// really needs them. Both decoders apply the orientation stored in the
/// photo. The canvas scales the frame and encodes the JPEG natively, off the
/// Dart code.
///
/// Throws when neither decoder can read the photo or heic-to does not load.
Future<XFile?> heifToJpeg(
  Uint8List bytes, {
  required String name,
  required int quality,
  required ({int width, int height}) Function(int width, int height) targetSize,
}) async {
  final source = web.Blob(<JSUint8Array>[bytes.toJS].toJS);
  final web.ImageBitmap bitmap =
      await _decodeNatively(source) ?? await _decodeWithLibrary(source);

  final ({int width, int height}) size = targetSize(
    bitmap.width,
    bitmap.height,
  );
  final canvas = web.HTMLCanvasElement()
    ..width = size.width
    ..height = size.height;

  try {
    (canvas.getContext('2d')! as web.CanvasRenderingContext2D)
      ..imageSmoothingQuality = 'high'
      ..drawImage(bitmap, 0, 0, size.width, size.height);
    bitmap.close();

    final web.Blob? jpeg = await _toJpeg(canvas, quality: quality);
    if (jpeg == null) return null;

    final Uint8List jpegBytes = (await jpeg.arrayBuffer().toDart).toDart
        .asUint8List();

    return XFile.fromData(
      jpegBytes,
      name: name,
      mimeType: 'image/jpeg',
      length: jpegBytes.length,
    );
  } finally {
    /// Safari holds the memory of a canvas until its size drops to zero
    canvas
      ..width = 0
      ..height = 0;
  }
}

/// `null` when the browser cannot decode HEIF.
Future<web.ImageBitmap?> _decodeNatively(web.Blob source) async {
  try {
    return await web.window.createImageBitmap(source).toDart;
  } catch (_) {
    logInfo(info: 'HEIF: the browser cannot decode it, heic-to takes over');
    return null;
  }
}

///
Future<web.ImageBitmap> _decodeWithLibrary(web.Blob source) async {
  final _HeicTo library = await (_library ??= _loadLibrary());
  final JSAny bitmap = await library
      .heicTo(_HeicToOptions(blob: source, type: 'bitmap'))
      .toDart;

  return bitmap as web.ImageBitmap;
}

/// A failed load is forgotten, so the next photo tries again: the usual cause
/// is a dropped connection.
Future<_HeicTo> _loadLibrary() async {
  /// A module is imported by an absolute address: a relative one would be
  /// resolved against the compiled application script, not the page
  final String url = Uri.parse(
    web.document.baseURI,
  ).resolve(ui_web.assetManager.getAssetUrl(_libraryAsset)).toString();

  try {
    final JSObject module = await importModule(url.toJS).toDart;
    logInfo(info: 'HEIF: heic-to loaded from $url');

    return module as _HeicTo;
  } catch (_) {
    _library = null;
    rethrow;
  }
}

/// JPEG from the canvas; `null` when the browser could not encode it.
Future<web.Blob?> _toJpeg(
  web.HTMLCanvasElement canvas, {
  required int quality,
}) {
  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    /// Not a tear-off: `toJS` takes JS types only, and `complete` has an
    /// optional `FutureOr` parameter
    // ignore: unnecessary_lambdas
    ((web.Blob? blob) => completer.complete(blob)).toJS,
    'image/jpeg',
    (quality / 100).toJS,
  );

  return completer.future;
}

/// The module namespace of heic-to.
extension type _HeicTo._(JSObject _) implements JSObject {
  /// Resolves to an `ImageBitmap` when [options] ask for a `bitmap`.
  external JSPromise<JSAny> heicTo(_HeicToOptions options);
}

///
extension type _HeicToOptions._(JSObject _) implements JSObject {
  ///
  external factory _HeicToOptions({web.Blob blob, String type});
}
