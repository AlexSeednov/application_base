import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/data/local/utility/secure_storage_utility.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

/// Hive storage whose boxes share one AES cipher, its key kept in the
/// platform secure storage.
@lazySingleton
final class StorageService with LoggingMixin {
  ///
  @visibleForTesting
  StorageService();

  ///
  @override
  String logName = 'Storage Service';

  ///
  bool _isReady = false;

  /// `null` when the key could not be stored: the boxes of this session then
  /// stay in memory.
  HiveAesCipher? _cipher;

  /// Initializes Hive and the cipher; call once before [open]. A second call
  /// is logged and ignored.
  ///
  /// [cipherKey] names the secure-storage entry that holds the AES key; it is
  /// not the key itself. [registerAdapters] runs after Hive is initialized
  /// and before any box opens.
  Future<void> prepare({
    required String cipherKey,
    required void Function() registerAdapters,
  }) async {
    if (_isReady) {
      logNamedError(error: 'already prepared');
      return;
    }

    await Hive.initFlutter(
      null,
      HiveStorageBackendPreference.native,
      9998, // colorAdapterTypeId - far-far from real project IDs
      9999, // timeOfDayAdapterTypeId - far-far from real project IDs
    );
    registerAdapters();

    _cipher = await SecureStorageUtility.getCipher(key: cipherKey);
    if (_cipher == null) {
      logNamedError(error: 'no stored cipher key, boxes stay in memory');
    }

    logNamedInfo(info: 'prepared');
    _isReady = true;
  }

  /// Opens the encrypted box [name]; needs [prepare] to have run.
  ///
  /// Without a stored key the box lives in memory for this session: written
  /// to disk under a key the next launch does not have, it would be
  /// unreadable there. The next launch tries to store a key again.
  ///
  /// A box the stored key cannot read is set aside, and an empty one opens in
  /// its place. The key that wrote it is gone — the keychain or the Keystore
  /// lost it, a backup was restored without it, and a new key was generated —
  /// so the box will not open again, and failing here would leave the
  /// application unable to start at all. The file is renamed rather than
  /// deleted: should the old key come back, the data is still there. Any
  /// other failure propagates — an adapter missing from the build is a bug,
  /// and it must not cost the user the box.
  Future<Box<E>> open<E>(String name) async {
    if (!_isReady) throw StateError('$logName: open() before prepare()');

    final HiveAesCipher? cipher = _cipher;
    if (cipher == null) return Hive.openBox(name, bytes: Uint8List(0));

    try {
      return await Hive.openBox(name, encryptionCipher: cipher);
      // Hive reports an unreadable box with an Error, not an Exception.
      // ignore: avoid_catching_errors
    } on HiveError catch (error) {
      if (!_isForeignCipher(error)) rethrow;

      logNamedError(error: '$name - unreadable with the stored key: $error');
      if (!await _setAside(name)) rethrow;

      return Hive.openBox(name, encryptionCipher: cipher);
    }
  }

  /// Hive's verdict on a box whose first record the cipher cannot read.
  ///
  /// Since hive_ce 2.20.1 a wrong cipher throws this; before, crash recovery
  /// truncated such a box to nothing.
  static bool _isForeignCipher(HiveError error) =>
      error.message.startsWith('Could not read the box');

  /// Renames the files of box [name] out of Hive's way; `false` when there is
  /// nothing to rename or the rename fails.
  ///
  /// The directory is the one `Hive.initFlutter` picks when given none, and
  /// Hive keeps box names in lower case. A leftover of an interrupted
  /// compaction goes too, or Hive would restore the box from it.
  Future<bool> _setAside(String name) async {
    // On the web the boxes live in IndexedDB, not in files.
    if (isWebBased) return false;

    final Directory directory = await getApplicationDocumentsDirectory();
    final String base = [
      directory.path,
      name.toLowerCase(),
    ].join(Platform.pathSeparator);
    final int stamp = DateTime.now().millisecondsSinceEpoch;

    bool isMoved = false;
    for (final String extension in const ['hive', 'hivec']) {
      final file = File('$base.$extension');
      if (!file.existsSync()) continue;

      final String target = '${file.path}.unreadable-$stamp';
      try {
        await file.rename(target);
      } on FileSystemException catch (error) {
        logNamedError(error: '$name - could not be set aside: $error');
        return false;
      }

      logNamedError(error: '$name - set aside as $target');
      isMoved = true;
    }

    return isMoved;
  }

  /// The single record a box keeps at index 0.
  ///
  /// An empty box or a `null` record is replaced with [emptyData], which is
  /// returned right away.
  E getData<E>(Box<E> box, E emptyData) {
    if (box.isEmpty) {
      /// Not awaited: Hive flushes the write on its own; the caller only needs
      /// the in-memory value back.
      unawaited(box.add(emptyData));
      logNamedInfo(info: '${box.name} - create new local data');
      return emptyData;
    }

    if (box.getAt(0) == null) {
      logNamedError(error: '${box.name} - null data in local storage');
      unawaited(box.putAt(0, emptyData));
      logNamedInfo(info: '${box.name} - replaced new local data');
      return emptyData;
    }

    logNamedInfo(info: '${box.name} - get data from local storage');
    return box.getAt(0)!;
  }
}
