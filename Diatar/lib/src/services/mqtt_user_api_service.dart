import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MqttUserApiService {
  static const String _baseUrl = 'https://mqtt.diatar.eu';
  static const int _maxRedirects = 5;

  final HttpClient _client = HttpClient();

  Future<void> createUser({
    required String username,
    required String password,
    required String email,
  }) {
    return _post('/api/v1/users/create', <String, String>{
      'username': username,
      'password': password,
      'email': email,
    });
  }

  Future<void> resendVerification({
    required String username,
    required String email,
  }) {
    return _post('/api/v1/users/resend-verification', <String, String>{
      'username': username,
      'email': email,
    });
  }

  Future<void> deleteUser({
    required String username,
    required String password,
  }) {
    return _post('/api/v1/users/delete', <String, String>{
      'username': username,
      'password': password,
    });
  }

  Future<void> changePassword({
    required String username,
    required String password,
    required String newPassword,
  }) {
    return _post('/api/v1/users/change-password', <String, String>{
      'username': username,
      'password': password,
      'newPassword': newPassword,
    });
  }

  Future<void> changeEmail({
    required String username,
    required String password,
    required String newEmail,
  }) {
    return _post('/api/v1/users/change-email', <String, String>{
      'username': username,
      'password': password,
      'newEmail': newEmail,
    });
  }

  Future<void> changeUsername({
    required String username,
    required String password,
    required String newUsername,
    required String newPassword,
  }) {
    return _post('/api/v1/users/change-username', <String, String>{
      'username': username,
      'password': password,
      'newUsername': newUsername,
      'newPassword': newPassword,
    });
  }

  Future<void> _post(String path, Map<String, String> payload) async {
    Uri uri = Uri.parse('$_baseUrl$path');
    for (int redirectCount = 0; redirectCount <= _maxRedirects; redirectCount++) {
      final HttpClientRequest request = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(payload));

      final HttpClientResponse response = await request
          .close()
          .timeout(const Duration(seconds: 12));

      if (_isRedirect(response.statusCode)) {
        final String location = response.headers.value(HttpHeaders.locationHeader) ?? '';
        if (location.isEmpty) {
          throw Exception('HTTP ${response.statusCode}');
        }
        uri = uri.resolve(location);
        continue;
      }

      final String body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractError(body, response.statusCode));
      }
      return;
    }

    throw Exception('Too many redirects');
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  String _extractError(String body, int statusCode) {
    if (body.trim().isEmpty) {
      return 'HTTP $statusCode';
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic message =
            decoded['message'] ?? decoded['error'] ?? decoded['title'] ?? decoded['detail'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return 'HTTP $statusCode: $body';
  }
}