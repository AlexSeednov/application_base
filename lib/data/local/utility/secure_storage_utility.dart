import 'dart:convert';
import 'dart:typed_data';

import 'package:application_base/core/service/logger_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Keeps the Hive AES key in the platform secure storage.
abstract final class SecureStorageUtility {
  /// The cipher for the key stored under [key], generated on first use;
  /// `null` when a new key could not be stored.
  ///
  /// A key that is not stored dies with the session, and whatever it
  /// encrypted is unreadable on the next launch — so the caller keeps such a
  /// session off the disk.
  static Future<HiveAesCipher?> getCipher({required String key}) async {
    final Uint8List? cipherKey = await _readCipherKey(key: key);

    return cipherKey == null ? null : HiveAesCipher(cipherKey);
  }

  /// Generates and stores a new key when none is stored under [key].
  static Future<Uint8List?> _readCipherKey({required String key}) async {
    const secureStorage = FlutterSecureStorage();

    final String? storedKey = await secureStorage.read(key: key);
    if (storedKey != null) return base64Url.decode(storedKey);

    final String newKey = base64UrlEncode(Hive.generateSecureKey());
    await secureStorage.write(key: key, value: newKey);

    /// Read back rather than trusted: a locked keychain or an unavailable
    /// Android Keystore lets the write silently store nothing.
    if (await secureStorage.read(key: key) != newKey) {
      logError(error: 'Cipher key "$key" could not be stored');
      return null;
    }

    return base64Url.decode(newKey);
  }
}
