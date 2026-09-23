import 'dart:async';

import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/data/local/utility/secure_storage_utility.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

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

  ///
  late HiveAesCipher _cipher;

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

    logNamedInfo(info: 'prepared');
    _isReady = true;
  }

  /// Opens the encrypted box [name]; needs [prepare] to have run.
  Future<Box<E>> open<E>(String name) =>
      Hive.openBox(name, encryptionCipher: _cipher);

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
