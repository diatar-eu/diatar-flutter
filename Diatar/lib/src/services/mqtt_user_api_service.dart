import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MqttUserApiException implements Exception {
  const MqttUserApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MqttUserApiService {
  static const String _baseUrl = 'https://mqtt.diatar.eu';
  static const int _maxRedirects = 5;

  MqttUserApiService({String? Function()? acceptLanguageProvider})
      : _acceptLanguageProvider = acceptLanguageProvider;

  final String? Function()? _acceptLanguageProvider;
  final http.Client _client = http.Client();

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

  Future<void> requestPasswordReset({
    required String username,
    required String email,
  }) {
    return _post('/api/v1/users/request-password-reset', <String, String>{
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
      final String? acceptLanguage = _normalizeLanguageCode(
        _acceptLanguageProvider?.call(),
      );
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (acceptLanguage != null) {
        headers['Accept-Language'] = acceptLanguage;
      }

      final http.Response response = await _client
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final String location = response.headers['location'] ?? '';
        if (location.isEmpty) {
          throw MqttUserApiException(
            message: 'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
        uri = uri.resolve(location);
        continue;
      }

      final String body = response.body;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MqttUserApiException(
          message: _extractError(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return;
    }

    throw const MqttUserApiException(message: 'Too many redirects');
  }

  bool _isRedirect(int statusCode) {
    return statusCode >= 300 && statusCode < 400;
  }

  String _extractError(String body, int statusCode) {
    if (body.trim().isEmpty) {
      return 'HTTP $statusCode';
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final String? validationErrors = _extractValidationErrors(decoded['errors']);
        if (validationErrors != null) {
          return validationErrors;
        }
        final dynamic message =
            decoded['message'] ?? decoded['error'] ?? decoded['title'] ?? decoded['detail'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return 'HTTP $statusCode: $body';
  }

  String? _extractValidationErrors(dynamic errors) {
    if (errors is! Map) {
      return null;
    }

    final List<String> messages = <String>[];
    errors.forEach((dynamic key, dynamic value) {
      final String field = key?.toString().trim() ?? '';
      if (value is List) {
        for (final dynamic item in value) {
          final String text = item?.toString().trim() ?? '';
          if (text.isEmpty) {
            continue;
          }
          messages.add(field.isEmpty ? text : '$field: $text');
        }
        return;
      }

      final String text = value?.toString().trim() ?? '';
      if (text.isEmpty) {
        return;
      }
      messages.add(field.isEmpty ? text : '$field: $text');
    });

    if (messages.isEmpty) {
      return null;
    }
    return messages.join('\n');
  }

  String? _normalizeLanguageCode(String? languageCode) {
    final String normalized = languageCode?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.split(RegExp(r'[_-]')).first;
  }
}