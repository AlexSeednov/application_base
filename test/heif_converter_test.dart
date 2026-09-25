import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:application_base/presentation/utility/heif_converter.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

/// A 64 × 48 HEIC made by `sips -s format heic`: the left half red, the
/// right half blue, so the size, the colours and the side they stand on all
/// survive a check of the converted JPEG. Not smaller: heic-to rejects frames
/// narrower than 64 px, and the sample should suit every decoder.
const String _sampleHeic =
    'AAAAJGZ0eXBoZWljAAAAAG1pZjFNaVBybWlhZk1pSEJoZWljAAABw21ldGEAAAAAAAAAIWhk'
    'bHIAAAAAAAAAAHBpY3QAAAAAAAAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAA'
    'DHVybCAAAAABAAAADnBpdG0AAAAAAAEAAAA4aWluZgAAAAAAAgAAABVpbmZlAgAAAAABAABo'
    'dmMxAAAAABVpbmZlAgAAAQACAABFeGlmAAAAABppcmVmAAAAAAAAAA5jZHNjAAIAAQABAAAA'
    '5mlwcnAAAADFaXBjbwAAABNjb2xybmNseAACAAIABoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAA'
    'AAAAAABAAAAAMAAAAAlpcm90AAAAABBwaXhpAAAAAAMICAgAAABxaHZjQwEDcAAAALAAAAAA'
    'AB7wAPz9+PgAAAsDoAABABdAAQwB//8DcAAAAwCwAAADAAADAB5wJKEAAQAjQgEBA3AAAAMA'
    'sAAAAwAAAwAeoBQgQcGMTiHuRZVNwICBgCCiAAEACUQBwGFyyEBTJAAAABlpcG1hAAAAAAAA'
    'AAEAAQaBAgMFhoQAAAAsaWxvYwAAAABEAAACAAEAAAABAAACRQAAAF0AAgAAAAEAAAH3AAAA'
    'TgAAAAFtZGF0AAAAAAAAALsAAAAGRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAA'
    'A6ABAAMAAAABAAEAAKACAAQAAAABAAAAQKADAAQAAAABAAAAMAAAAAAAAABZKAGvo8uAKpDm'
    'f/dcv/9tH2Xz7UYA4PwC0b3CQOu+KKfFBoQBbLf/+YigAJ2KXK/2t6Gl/tqbs5QNqHYDw5X2'
    '6L/fKzr/f/126N/2gs3doIMP8j1h0Idw8oA=';

/// The conversion runs where the host decodes HEIF: ImageIO on macOS. A Linux
/// host has no decoder. In `flutter test --platform chrome` Chrome rejects
/// HEIF, and heic-to cannot load: the test server serves the `lib/` of a
/// package, not its assets. The web branch is checked in a built application.
final Object _conversionSkip = kIsWeb
    ? 'the web test server does not serve package assets'
    : Platform.isMacOS
    ? false
    : 'no HEIF decoder on this host';

/// An `ftyp` box of [brandList]: the major brand, a zero minor version and
/// the compatible brands.
Uint8List _ftyp(List<String> brandList) {
  final List<int> brandBytes = [
    ...ascii.encode(brandList.first),
    0,
    0,
    0,
    0,
    for (final String brand in brandList.skip(1)) ...ascii.encode(brand),
  ];
  final int size = 8 + brandBytes.length;

  return Uint8List.fromList([
    ...(ByteData(4)..setUint32(0, size)).buffer.asUint8List(),
    ...ascii.encode('ftyp'),
    ...brandBytes,
  ]);
}

/// Width, height and the colour of a pixel in each half.
Future<({int width, int height, List<int> left, List<int> right})> _read(
  Uint8List bytes,
) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData pixels = (await image.toByteData())!;

  List<int> pixel(int x) {
    final int offset = ((image.height ~/ 2) * image.width + x) * 4;
    return [for (int i = 0; i < 3; i++) pixels.getUint8(offset + i)];
  }

  final result = (
    width: image.width,
    height: image.height,
    left: pixel(image.width ~/ 8),
    right: pixel(image.width - 1 - image.width ~/ 8),
  );
  image.dispose();
  codec.dispose();

  return result;
}

/// The sample as a picked file. The name goes in both fields: outside the web
/// an `XFile` made from bytes takes its name from the path.
XFile _sample() => XFile.fromData(
  base64Decode(_sampleHeic),
  name: 'IMG_0042.HEIC',
  path: 'IMG_0042.HEIC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the format is told by the brands', () {
    test('an iPhone photo is HEIF', () {
      expect(
        HeifConverter.isHeifHeader(_ftyp(['heic', 'mif1', 'MiHB', 'heic'])),
        isTrue,
      );
    });

    test('a generic HEIF still and a sequence are HEIF', () {
      expect(HeifConverter.isHeifHeader(_ftyp(['mif1', 'heic'])), isTrue);
      expect(HeifConverter.isHeifHeader(_ftyp(['msf1', 'hevc'])), isTrue);
    });

    test('AVIF shares the container, but is not HEIF', () {
      expect(
        HeifConverter.isHeifHeader(_ftyp(['avif', 'mif1', 'miaf'])),
        isFalse,
      );
      expect(HeifConverter.isHeifHeader(_ftyp(['mif1', 'avif'])), isFalse);
    });

    test('MP4 and MOV videos are not HEIF', () {
      expect(
        HeifConverter.isHeifHeader(_ftyp(['isom', 'iso2', 'mp41'])),
        isFalse,
      );
      expect(HeifConverter.isHeifHeader(_ftyp(['qt  ', 'qt  '])), isFalse);
    });

    test('JPEG, PNG and a truncated file are not HEIF', () {
      expect(
        HeifConverter.isHeifHeader(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 74, 70, 73, 70]),
        ),
        isFalse,
      );
      expect(
        HeifConverter.isHeifHeader(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13]),
        ),
        isFalse,
      );
      expect(HeifConverter.isHeifHeader(Uint8List(6)), isFalse);
    });
  });

  test('the converted file keeps the name and takes .jpg', () {
    expect(HeifConverter.jpegName('IMG_0042.HEIC'), 'IMG_0042.jpg');
    expect(HeifConverter.jpegName('photo.2026.heif'), 'photo.2026.jpg');
    expect(HeifConverter.jpegName('photo'), 'photo.jpg');
    expect(HeifConverter.jpegName('.heic'), 'image.jpg');
    expect(HeifConverter.jpegName(''), 'image.jpg');
  });

  group('the frame fits the bound with its proportions', () {
    test('a frame within the bound keeps its size', () {
      expect(
        HeifConverter.targetSize(width: 4032, height: 3024, maxDimension: 4096),
        (width: 4032, height: 3024),
      );
    });

    test('a 48-megapixel frame is scaled down on its long side', () {
      expect(
        HeifConverter.targetSize(width: 8064, height: 6048, maxDimension: 4096),
        (width: 4096, height: 3072),
      );
      expect(
        HeifConverter.targetSize(width: 6048, height: 8064, maxDimension: 4096),
        (width: 3072, height: 4096),
      );
    });

    test('a thin frame keeps at least a pixel', () {
      expect(
        HeifConverter.targetSize(width: 10000, height: 1, maxDimension: 100),
        (width: 100, height: 1),
      );
    });
  });

  test('a file that is not HEIF comes back untouched', () async {
    final jpeg = XFile.fromData(
      Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 74, 70, 73, 70]),
      name: 'photo.jpg',
    );

    expect(await HeifConverter.convertIfHeif(jpeg), same(jpeg));
  });

  test('a HEIF photo becomes a JPEG', () async {
    final XFile? jpeg = await HeifConverter.convertIfHeif(_sample());

    expect(jpeg, isNotNull);
    expect(jpeg!.name, 'IMG_0042.jpg');
    expect(jpeg.mimeType, 'image/jpeg');

    final Uint8List bytes = await jpeg.readAsBytes();
    expect(bytes.take(3), [0xFF, 0xD8, 0xFF]);

    final picture = await _read(bytes);
    expect((picture.width, picture.height), (64, 48));
    expect(picture.left[0], greaterThan(200), reason: 'red on the left');
    expect(picture.left[2], lessThan(60), reason: 'red on the left');
    expect(picture.right[0], lessThan(60), reason: 'blue on the right');
    expect(picture.right[2], greaterThan(200), reason: 'blue on the right');
  }, skip: _conversionSkip);

  test('a converted photo is fitted into the bound', () async {
    final XFile? jpeg = await HeifConverter.convertIfHeif(
      _sample(),
      maxDimension: 20,
    );

    final picture = await _read(await jpeg!.readAsBytes());
    expect((picture.width, picture.height), (20, 15));
  }, skip: _conversionSkip);

  test('a broken HEIF photo answers null instead of throwing', () async {
    final Uint8List broken = base64Decode(_sampleHeic).sublist(0, 200);

    expect(
      await HeifConverter.convertIfHeif(
        XFile.fromData(broken, name: 'broken.heic', path: 'broken.heic'),
      ),
      isNull,
    );
  });
}
