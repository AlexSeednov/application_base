import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

///
abstract final class SecureStorageUtility {
  /// Here options fix
  /// https://github.com/mogol/flutter_secure_storage/issues/380#issuecomment-1236577186
  /// https://github.com/mogol/flutter_secure_storage/issues/380#issuecomment-1250501286
  static const AndroidOptions _secureStorageOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
    keyCipherAlgorithm:
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
  );

  ///
  static Future<HiveAesCipher> getCipher({required String key}) async {
    /// Get cipher key from local secure storage
    final Uint8List cipherKey = await _readCipherKey(key: key);

    /// Prepare cipher from cipher key
    return HiveAesCipher(cipherKey);
  }

  /// Get cipher key
  ///
  /// If cipher key is not exists it will be generated
  static Future<Uint8List> _readCipherKey({required String key}) async {
    const secureStorage = FlutterSecureStorage(aOptions: _secureStorageOptions);

    String? encryptedKey = await secureStorage.read(key: key);
    if (encryptedKey == null) {
      /// Generate a new one
      final List<int> newEncryptedKey = Hive.generateSecureKey();
      await secureStorage.write(
        key: key,
        value: base64UrlEncode(newEncryptedKey),
      );
      encryptedKey = await secureStorage.read(key: key);
    }

    return base64Url.decode(encryptedKey!);
  }
}
