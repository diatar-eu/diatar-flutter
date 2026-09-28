import 'package:diatar_app/src/core/settings/internet_credentials_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const InternetCredentialsPolicy policy = InternetCredentialsPolicy();

  String resolve({
    String storedPassword = 'stored',
    String enteredPassword = '',
    bool removalRequested = false,
    bool relayEnabled = true,
    String mqttUser = 'user',
  }) {
    return policy.resolvePassword(
      storedPassword: storedPassword,
      enteredPassword: enteredPassword,
      removalRequested: removalRequested,
      relayEnabled: relayEnabled,
      mqttUser: mqttUser,
    );
  }

  test('an empty field keeps the stored password', () {
    expect(resolve(), 'stored');
  });

  test('a typed password replaces the stored one', () {
    expect(resolve(enteredPassword: 'new'), 'new');
  });

  test('removal wins over a typed password', () {
    expect(resolve(enteredPassword: 'new', removalRequested: true), '');
  });

  test('removal clears the stored password', () {
    expect(resolve(removalRequested: true), '');
  });

  test('turning the relay off drops the password', () {
    expect(resolve(relayEnabled: false), '');
  });

  test('an empty username drops the password', () {
    expect(resolve(mqttUser: '   '), '');
  });

  test('an empty username drops a typed password too', () {
    expect(resolve(enteredPassword: 'new', mqttUser: ''), '');
  });

  test('nothing stored and nothing typed stays empty', () {
    expect(resolve(storedPassword: ''), '');
  });
}
