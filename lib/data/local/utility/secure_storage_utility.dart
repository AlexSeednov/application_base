import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

///
abstract final class SecureStorageUtility {
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
    const secureStorage = FlutterSecureStorage();

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
