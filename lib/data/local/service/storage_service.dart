import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/data/local/utility/secure_storage_utility.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';

/// Singleton for working with secure local storage
@lazySingleton
final class StorageService with LoggingMixin {
  ///
  StorageService._();

  ///
  @factoryMethod
  factory StorageService.singleton() => _instance;

  ///
  static final _instance = StorageService._();

  /// Name for logger
  @override
  String logName = 'Storage Service';

  /// Service ready to work
  bool _isReady = false;

  ///
  late HiveAesCipher _cipher;

  /// Initialize storage and open data box
  /// [cipherKey] - secret key for local secure storage
  /// [registerAdapters] - function to register all Hive adapters
  Future<void> prepare({
    required String cipherKey,
    required void Function() registerAdapters,
  }) async {
    if (_isReady) {
      logNamedError(error: 'already prepared');
      return;
    }

    /// Initialize Hive
    await Hive.initFlutter(
      null,
      HiveStorageBackendPreference.native,
      9998, // colorAdapterTypeId - far-far from real project IDs
      9999, // timeOfDayAdapterTypeId - far-far from real project IDs
    );
    registerAdapters();

    /// Prepare storage cipher
    _cipher = await SecureStorageUtility.getCipher(key: cipherKey);

    logNamedInfo(info: 'prepared');
    _isReady = true;
  }

  /// Open secure box from local storage
  Future<Box<E>> open<E>(String name) =>
      Hive.openBox(name, encryptionCipher: _cipher);

  /// Safe get data or create if data does not exist
  E getData<E>(Box<E> box, E emptyData) {
    /// Check local data
    if (box.isEmpty) {
      /// Where is now local data, create a new one
      box.add(emptyData);
      logNamedInfo(info: '${box.name} - create new local data');
      return emptyData;
    }

    /// Has some data, check it correctness
    if (box.getAt(0) == null) {
      /// Something wrong, recreate data
      logNamedError(error: '${box.name} - null data in local storage');
      box.putAt(0, emptyData);
      logNamedInfo(info: '${box.name} - replaced new local data');
      return emptyData;
    }

    /// Data is ok, get it
    logNamedInfo(info: '${box.name} - get data from local storage');
    return box.getAt(0)!;
  }
}
