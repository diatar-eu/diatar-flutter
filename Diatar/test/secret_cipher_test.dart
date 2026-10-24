import 'package:cryptography/cryptography.dart';
import 'package:diatar_app/src/core/secret/secret_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a secret under the same key', () async {
    final SecretKey key = await SecretCipher.generateKey();

    final String payload = await SecretCipher.seal('hunter2', key);

    expect(payload, isNot(contains('hunter2')));
    expect(await SecretCipher.open(payload, key), 'hunter2');
  });

  test('a fresh nonce makes the same secret encrypt differently', () async {
    final SecretKey key = await SecretCipher.generateKey();

    final String first = await SecretCipher.seal('hunter2', key);
    final String second = await SecretCipher.seal('hunter2', key);

    expect(first, isNot(second));
  });

  test('an empty secret round-trips', () async {
    final SecretKey key = await SecretCipher.generateKey();

    final String payload = await SecretCipher.seal('', key);

    expect(await SecretCipher.open(payload, key), '');
  });

  test('another key cannot open the payload', () async {
    final String payload = await SecretCipher.seal(
      'hunter2',
      await SecretCipher.generateKey(),
    );

    expect(
      await SecretCipher.open(payload, await SecretCipher.generateKey()),
      isNull,
    );
  });

  test('a tampered payload does not open', () async {
    final SecretKey key = await SecretCipher.generateKey();
    final String payload = await SecretCipher.seal('hunter2', key);
    // Flip one character of the base64 body and leave the rest alone.
    final int bodyStart = payload.indexOf('.') + 1;
    final int index = bodyStart + (payload.length - bodyStart) ~/ 2;
    final String original = payload[index];
    final String tampered = payload.replaceRange(
      index,
      index + 1,
      original == 'A' ? 'B' : 'A',
    );

    expect(await SecretCipher.open(tampered, key), isNull);
  });

  test('an unknown format version does not open', () async {
    final SecretKey key = await SecretCipher.generateKey();
    final String payload = await SecretCipher.seal('hunter2', key);

    expect(
      await SecretCipher.open(
        '9.${payload.substring(payload.indexOf('.') + 1)}',
        key,
      ),
      isNull,
    );
  });

  test('garbage does not open', () async {
    final SecretKey key = await SecretCipher.generateKey();

    expect(await SecretCipher.open('not a payload', key), isNull);
    expect(await SecretCipher.open('', key), isNull);
  });

  test('keys encode and decode for storage', () async {
    final SecretKey key = await SecretCipher.generateKey();
    final List<int> bytes = await key.extractBytes();

    final List<int> decoded = SecretCipher.decodeKey(
      SecretCipher.encodeKey(bytes),
    );

    expect(decoded, bytes);
  });

  test('a key of the wrong length is rejected', () {
    expect(
      () => SecretCipher.decodeKey(SecretCipher.encodeKey(<int>[1, 2, 3])),
      throwsFormatException,
    );
  });
}
