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

    final String? storedKey = await secureStorage.read(key: key);
    if (storedKey != null) return base64Url.decode(storedKey);

    /// Generate a new one
    ///
    /// The freshly generated key is returned directly instead of being read
    /// back: the round-trip only added a second point of failure. A locked
    /// keychain or an unavailable Android Keystore makes the write silently
    /// produce nothing, and re-reading it used to force-unwrap `null` and
    /// crash the app on launch.
    final List<int> newKey = Hive.generateSecureKey();
    await secureStorage.write(key: key, value: base64UrlEncode(newKey));

    return Uint8List.fromList(newKey);
  }
}
