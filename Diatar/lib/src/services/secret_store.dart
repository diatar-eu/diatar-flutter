import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/secret/secret_cipher.dart';

/// Where the AES key behind [SecretStore]'s ciphertexts lives.
enum SecretKeyProtection {
  /// The platform keystore: Android Keystore, iOS/macOS Keychain, Windows
  /// DPAPI, Linux libsecret, or the browser's WebCrypto-backed store.
  platformKeystore,

  /// The keystore was unreachable, so the key sits in the settings file next
  /// to the ciphertext. Readable by anyone who can read that file — the UI
  /// warns about this, see [SecretStore.keyProtection].
  settingsFile,
}

/// Result of probing the platform keystore: [key] is what it holds, and
/// [available] tells a missing key apart from an unreachable keystore.
class _PlatformKey {
  const _PlatformKey(this.key, this.available);

  final SecretKey? key;
  final bool available;
}

/// Keeps the app's short secrets out of reach of anyone who can read the
/// settings — both through the settings UI and by copying the settings file
/// off the machine.
///
/// The AES-256-GCM ciphertext goes into `SharedPreferences`; the key goes into
/// the platform keystore. The two only meet inside the running app, which is
/// also where the plaintext is needed to open the MQTT connection anyway.
///
/// The keystore is not always reachable: a headless Linux box with no keyring
/// daemon, a browser outside a secure context, a machine whose keystore was
/// reset. Refusing to save settings in those cases would be worse than storing
/// the secret weakly, so the key falls back to the settings file and
/// [keyProtection] reports it so the UI can say so. A later run that finds the
/// keystore working again moves the key back into it.
class SecretStore {
  SecretStore({FlutterSecureStorage? keyStore})
    : _keyStore = keyStore ?? const FlutterSecureStorage();

  /// Keystore entry holding the app-wide AES key.
  static const String _keyStoreKey = 'diatar.secret.aes.v1';

  /// Settings-file copy of [_keyStoreKey], only used while the keystore is
  /// unreachable. Deliberately obvious: this is the degraded case, not a
  /// secret of its own.
  static const String _kSettingsFileKey = 'SecretKeyInSettingsFile';

  final FlutterSecureStorage _keyStore;
  SecretKey? _cachedKey;
  SecretKeyProtection _keyProtection = SecretKeyProtection.platformKeystore;

  /// Whether the key is currently in the platform keystore.
  SecretKeyProtection get keyProtection => _keyProtection;

  /// Decrypts the secret stored under [name], or `null` when there is none.
  ///
  /// A payload that cannot be decrypted — lost key, damaged file, unknown
  /// format — is dropped, so the caller can offer to set a new secret instead
  /// of silently keeping a value it cannot use.
  Future<String?> read(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? payload = prefs.getString(name);
    if (payload == null || payload.isEmpty) {
      return null;
    }
    final String? plainText = await SecretCipher.open(
      payload,
      await _resolveKey(prefs),
    );
    if (plainText == null) {
      debugPrint('SecretStore: unusable payload for "$name", discarding it.');
      await prefs.remove(name);
      return null;
    }
    return plainText;
  }

  /// Encrypts [value] under [name], replacing whatever was there.
  Future<void> write(String name, String value) async {
    if (value.isEmpty) {
      await delete(name);
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String payload = await SecretCipher.seal(
      value,
      await _resolveKey(prefs),
    );
    await prefs.setString(name, payload);
  }

  /// Removes the secret stored under [name].
  Future<void> delete(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(name);
  }

  /// Returns the app-wide key, creating it on first use and making sure it
  /// lives wherever [keyProtection] says it should.
  Future<SecretKey> _resolveKey(SharedPreferences prefs) async {
    final SecretKey? cached = _cachedKey;
    if (cached != null) {
      return cached;
    }

    final _PlatformKey platform = await _readPlatformKey();
    if (platform.key != null) {
      // The keystore is authoritative. A settings-file copy is left over from
      // a run when the keystore was unreachable and would be a stale key.
      await prefs.remove(_kSettingsFileKey);
      return _adopt(platform.key!, SecretKeyProtection.platformKeystore);
    }

    // Either there is no key yet, or the keystore is unreachable and a
    // previous run had to leave one in the settings file. Reuse that key, so
    // the ciphertext it protected stays readable, and try to move it into the
    // keystore.
    final SecretKey? existing = _readSettingsFileKey(prefs);
    final SecretKey key = existing ?? await SecretCipher.generateKey();
    if (platform.available && await _writePlatformKey(key)) {
      await prefs.remove(_kSettingsFileKey);
      return _adopt(key, SecretKeyProtection.platformKeystore);
    }

    // The keystore will not take the key, so keep it where the app can find it
    // after a restart rather than losing the secret. [keyProtection] tells the
    // UI that this is the degraded case.
    if (platform.available) {
      debugPrint(
        'SecretStore: platform keystore rejected the key, the secret key '
        'falls back to the settings file.',
      );
    }
    if (existing == null) {
      await prefs.setString(
        _kSettingsFileKey,
        SecretCipher.encodeKey(await key.extractBytes()),
      );
    }
    return _adopt(key, SecretKeyProtection.settingsFile);
  }

  SecretKey _adopt(SecretKey key, SecretKeyProtection protection) {
    _cachedKey = key;
    _keyProtection = protection;
    return key;
  }

  Future<_PlatformKey> _readPlatformKey() async {
    try {
      final String? encoded = await _keyStore.read(key: _keyStoreKey);
      if (encoded == null || encoded.isEmpty) {
        return const _PlatformKey(null, true);
      }
      return _PlatformKey(SecretKey(SecretCipher.decodeKey(encoded)), true);
    } catch (error) {
      debugPrint('SecretStore: keystore read failed: $error');
      return const _PlatformKey(null, false);
    }
  }

  Future<bool> _writePlatformKey(SecretKey key) async {
    try {
      await _keyStore.write(
        key: _keyStoreKey,
        value: SecretCipher.encodeKey(await key.extractBytes()),
      );
      return true;
    } catch (error) {
      debugPrint('SecretStore: keystore write failed: $error');
      return false;
    }
  }

  SecretKey? _readSettingsFileKey(SharedPreferences prefs) {
    final String? encoded = prefs.getString(_kSettingsFileKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return SecretKey(SecretCipher.decodeKey(encoded));
    } catch (error) {
      debugPrint('SecretStore: settings-file key is unusable: $error');
      return null;
    }
  }
}
