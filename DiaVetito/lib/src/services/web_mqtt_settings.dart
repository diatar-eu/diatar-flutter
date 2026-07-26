/// Returns the MQTT sender configured in a web URL, if it is usable.
///
/// `Uri.queryParameters` also decodes percent-encoded values, so this accepts
/// links such as `?mqtt=K%C3%B6zvet%C3%ADt%C5%91`.
String? mqttUsernameFromWebUri(Uri uri) {
  final String? username = uri.queryParameters['mqtt']?.trim();
  return username == null || username.isEmpty ? null : username;
}
