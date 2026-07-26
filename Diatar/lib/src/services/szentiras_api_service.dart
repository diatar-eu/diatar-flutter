import 'dart:convert';

import 'package:http/http.dart' as http;

class SzentirasTranslation {
  const SzentirasTranslation({
    required this.abbrev,
    required this.name,
    this.language = '',
  });

  final String abbrev;
  final String name;
  final String language;

  factory SzentirasTranslation.fromJson(Map<String, dynamic> json) {
    return SzentirasTranslation(
      abbrev: json['abbrev'] as String? ?? '',
      name: json['name'] as String? ?? '',
      language: json['language'] as String? ?? '',
    );
  }
}

class SzentirasVerse {
  const SzentirasVerse({
    required this.reference,
    required this.text,
  });

  final String reference;
  final String text;
}

class SzentirasQuoteResult {
  const SzentirasQuoteResult({
    required this.translationName,
    required this.translationAbbrev,
    required this.verses,
  });

  final String translationName;
  final String translationAbbrev;
  final List<SzentirasVerse> verses;
}

class SzentirasApiService {
  static const String _baseUrl = 'https://szentiras.eu/api';
  final http.Client _client = http.Client();

  Map<String, String> _headers(String apiKey) => <String, String>{
    'X-API-Key': apiKey,
  };

  Future<List<SzentirasTranslation>> getTranslations(String apiKey) async {
    final Uri uri = Uri.parse('$_baseUrl/forditasok');
    final http.Response response = await _client
        .get(uri, headers: _headers(apiKey))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401) {
      throw SzentirasApiException('Unauthorized – érvénytelen API kulcs');
    }
    if (response.statusCode == 429) {
      throw SzentirasApiException('Túl sok kérés – próbáld újra később');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SzentirasApiException('Hiba: ${response.statusCode}');
    }
    final Map<String, dynamic> decoded =
        json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> rawTranslations =
        decoded['translations'] as List<dynamic>? ?? <dynamic>[];
    return rawTranslations
        .map((dynamic e) => SzentirasTranslation.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }

  Future<SzentirasQuoteResult> getQuote(
    String apiKey,
    String reference, {
    String? translation,
  }) async {
    final String path = translation != null && translation.isNotEmpty
        ? '$_baseUrl/idezet/$reference/$translation'
        : '$_baseUrl/idezet/$reference';
    final Uri uri = Uri.parse(path);
    final http.Response response = await _client
        .get(uri, headers: _headers(apiKey))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401) {
      throw SzentirasApiException('Unauthorized – érvénytelen API kulcs');
    }
    if (response.statusCode == 429) {
      throw SzentirasApiException('Túl sok kérés – próbáld újra később');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SzentirasApiException('Hiba: ${response.statusCode}');
    }
    final Map<String, dynamic> decoded =
        json.decode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> valasz =
        decoded['valasz'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic> forditasInfo =
        valasz['forditas'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String translationName = forditasInfo['nev'] as String? ?? '';
    final String translationAbbrev = forditasInfo['rov'] as String? ?? '';
    final List<dynamic> rawVerses =
        valasz['versek'] as List<dynamic>? ?? <dynamic>[];
    final List<SzentirasVerse> verses = rawVerses.map((dynamic e) {
      final Map<String, dynamic> v = e as Map<String, dynamic>;
      final Map<String, dynamic> hely =
          v['hely'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String szep = hely['szep'] as String? ?? '';
      return SzentirasVerse(
        reference: szep,
        text: v['szoveg'] as String? ?? '',
      );
    }).toList();
    return SzentirasQuoteResult(
      translationName: translationName,
      translationAbbrev: translationAbbrev,
      verses: verses,
    );
  }

  void dispose() {
    _client.close();
  }
}

class SzentirasApiException implements Exception {
  const SzentirasApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
