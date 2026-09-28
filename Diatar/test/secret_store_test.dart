import 'package:diatar_app/src/services/secret_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingKeyStore extends FlutterSecureStorage {
  _FailingKeyStore();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keystore unavailable');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('keystore unavailable');
  }
}

/// A keystore that answers reads but refuses writes, the state a locked or
/// full keyring leaves the app in.
class _ReadOnlyKeyStore extends _FailingKeyStore {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return const FlutterSecureStorage().read(key: key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String payloadKey = 'MqttPasswordEnc';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('stores a secret unreadable in the settings file', () async {
    final SecretStore store = SecretStore();

    await store.write(payloadKey, 'hunter2');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? payload = prefs.getString(payloadKey);
    expect(payload, isNotNull);
    expect(payload, isNot(contains('hunter2')));
    expect(await store.read(payloadKey), 'hunter2');
    expect(store.keyProtection, SecretKeyProtection.platformKeystore);
  });

  test('a fresh store decrypts what an earlier one wrote', () async {
    await SecretStore().write(payloadKey, 'hunter2');

    // A new instance, as after an app restart. The key comes from the
    // keystore, not from anything the instance held in memory.
    expect(await SecretStore().read(payloadKey), 'hunter2');
  });

  test('writes a new secret over the old one', () async {
    final SecretStore store = SecretStore();

    await store.write(payloadKey, 'first');
    await store.write(payloadKey, 'second');

    expect(await store.read(payloadKey), 'second');
  });

  test('delete removes the secret', () async {
    final SecretStore store = SecretStore();
    await store.write(payloadKey, 'hunter2');

    await store.delete(payloadKey);

    expect(await store.read(payloadKey), isNull);
  });

  test('writing an empty secret deletes it', () async {
    final SecretStore store = SecretStore();
    await store.write(payloadKey, 'hunter2');

    await store.write(payloadKey, '');

    expect(await store.read(payloadKey), isNull);
  });

  test('an absent secret reads as null', () async {
    expect(await SecretStore().read(payloadKey), isNull);
  });

  test('a payload the key cannot open is discarded, not returned', () async {
    final SecretStore store = SecretStore();
    await store.write(payloadKey, 'hunter2');
    // Someone replaced the keystore contents, e.g. the keyring was reset.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    expect(await SecretStore().read(payloadKey), isNull);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(payloadKey), isNull);
  });

  test('an unreadable payload is discarded, not returned', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      payloadKey: r'1.not-base64-$$$',
    });

    expect(await SecretStore().read(payloadKey), isNull);
  });

  test(
    'falls back to the settings file when the keystore is unavailable',
    () async {
      final SecretStore store = SecretStore(keyStore: _FailingKeyStore());

      await store.write(payloadKey, 'hunter2');

      expect(store.keyProtection, SecretKeyProtection.settingsFile);
      expect(await store.read(payloadKey), 'hunter2');
    },
  );

  test('a secret written with a broken keystore survives a restart', () async {
    await SecretStore(
      keyStore: _FailingKeyStore(),
    ).write(payloadKey, 'hunter2');

    expect(
      await SecretStore(keyStore: _FailingKeyStore()).read(payloadKey),
      'hunter2',
    );
  });

  test('a keystore that refuses writes keeps the secret readable', () async {
    final SecretStore store = SecretStore(keyStore: _ReadOnlyKeyStore());

    await store.write(payloadKey, 'hunter2');

    expect(store.keyProtection, SecretKeyProtection.settingsFile);
    expect(await store.read(payloadKey), 'hunter2');
    // The key must not have been lost just because the keystore would not
    // accept it, otherwise the next run could not open the ciphertext.
    expect(
      await SecretStore(keyStore: _FailingKeyStore()).read(payloadKey),
      'hunter2',
    );
  });

  test(
    'a working keystore takes the key back from the settings file',
    () async {
      await SecretStore(
        keyStore: _FailingKeyStore(),
      ).write(payloadKey, 'hunter2');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('SecretKeyInSettingsFile'), isNotNull);

      final SecretStore recovered = SecretStore();

      expect(recovered.keyProtection, SecretKeyProtection.platformKeystore);
      expect(await recovered.read(payloadKey), 'hunter2');
      // And the next run no longer depends on the settings-file copy.
      expect(await SecretStore().read(payloadKey), 'hunter2');
    },
  );
}
