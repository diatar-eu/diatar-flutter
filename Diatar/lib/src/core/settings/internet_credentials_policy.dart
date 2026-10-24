/// Decides which MQTT password the internet section of the settings should
/// persist.
///
/// The settings sheet never reads the stored password back into its field, so
/// "the field is empty" has to mean something: it means *leave the stored
/// password alone*. Typing into the field replaces it, [removalRequested]
/// clears it, and switching the relay off (or clearing the username) drops it
/// because an unused password is a liability.
class InternetCredentialsPolicy {
  const InternetCredentialsPolicy();

  /// The password to store, or an empty string to remove the stored one.
  String resolvePassword({
    required String storedPassword,
    required String enteredPassword,
    required bool removalRequested,
    required bool relayEnabled,
    required String mqttUser,
  }) {
    if (!relayEnabled || mqttUser.trim().isEmpty || removalRequested) {
      return '';
    }
    if (enteredPassword.isNotEmpty) {
      return enteredPassword;
    }
    return storedPassword;
  }
}
