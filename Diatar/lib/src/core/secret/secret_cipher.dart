import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM sealing for the short secrets Diatár keeps in shared
/// preferences — today the only one is the internet relay's MQTT password.
///
/// Only `1.<base64 nonce+ciphertext+tag>` is written to the preferences file,
/// which is useless without the key. The key is kept in the platform keystore
/// by `SecretStore`, never next to the ciphertext, so a copied settings file
/// reveals nothing even though the ciphertext lives in the same file as the
/// username.
class SecretCipher {
  const SecretCipher._();

  /// Bumped when the payload layout changes, so an older or foreign payload is
  /// recognised and discarded instead of looking like a decryption failure.
  static const String formatVersion = '1';

  /// AES-256.
  static const int keyLengthBytes = 32;

  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Draws a fresh key from the platform CSPRNG.
  static Future<SecretKey> generateKey() => _algorithm.newSecretKey();

  /// Base64 for storing a key in the keystore or the settings file.
  static String encodeKey(List<int> bytes) => base64.encode(bytes);

  /// Reads a key written by [encodeKey]. Throws if the text is not valid
  /// base64 or not a key of the expected length.
  static List<int> decodeKey(String encoded) {
    final List<int> bytes = base64.decode(encoded);
    if (bytes.length != keyLengthBytes) {
      throw const FormatException('Unexpected secret key length.');
    }
    return bytes;
  }

  /// Encrypts [plainText] under [key] into a storable payload.
  static Future<String> seal(String plainText, SecretKey key) async {
    final SecretBox box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
    );
    return '$formatVersion.${base64.encode(box.concatenation())}';
  }

  /// Returns the plaintext behind [payload], or `null` when it cannot be
  /// trusted: an unknown format version, corrupt base64, the wrong key, or a
  /// failed authentication tag. Callers must treat `null` as "nothing usable
  /// is stored" and drop the payload.
  static Future<String?> open(String payload, SecretKey key) async {
    final int separator = payload.indexOf('.');
    if (separator < 0 || payload.substring(0, separator) != formatVersion) {
      return null;
    }
    try {
      final SecretBox box = SecretBox.fromConcatenation(
        base64.decode(payload.substring(separator + 1)),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
        copy: false,
      );
      return utf8.decode(await _algorithm.decrypt(box, secretKey: key));
    } catch (_) {
      return null;
    }
  }
}
