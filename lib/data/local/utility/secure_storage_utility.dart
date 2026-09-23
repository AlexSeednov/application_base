import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Keeps the Hive AES key in the platform secure storage.
abstract final class SecureStorageUtility {
  /// The cipher for the key stored under [key], generated on first use.
  static Future<HiveAesCipher> getCipher({required String key}) async {
    final Uint8List cipherKey = await _readCipherKey(key: key);

    return HiveAesCipher(cipherKey);
  }

  /// Generates and stores a new key when none is stored under [key].
  static Future<Uint8List> _readCipherKey({required String key}) async {
    const secureStorage = FlutterSecureStorage();

    final String? storedKey = await secureStorage.read(key: key);
    if (storedKey != null) return base64Url.decode(storedKey);

    /// The new key is returned directly, not read back: a locked keychain or
    /// an unavailable Android Keystore makes the write silently store nothing,
    /// and a re-read would force-unwrap `null` and crash the app on launch.
    final List<int> newKey = Hive.generateSecureKey();
    await secureStorage.write(key: key, value: base64UrlEncode(newKey));

    return Uint8List.fromList(newKey);
  }
}
