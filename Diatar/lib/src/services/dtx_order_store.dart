import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StoredCustomOrderEntry {
  const StoredCustomOrderEntry({
    required this.fileName,
    required this.songIndex,
    required this.verseIndex,
    required this.label,
    this.customTextTitle,
    this.customTextBody,
    this.customImagePath,
  });

  final String fileName;
  final int songIndex;
  final int verseIndex;
  final String label;
  final String? customTextTitle;
  final String? customTextBody;
  final String? customImagePath;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fileName': fileName,
        'songIndex': songIndex,
        'verseIndex': verseIndex,
        'label': label,
        'customTextTitle': customTextTitle,
        'customTextBody': customTextBody,
        'customImagePath': customImagePath,
      };

  static StoredCustomOrderEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? f = raw['fileName'];
    final Object? s = raw['songIndex'];
    final Object? v = raw['verseIndex'];
    final Object? l = raw['label'];
    final Object? textTitle = raw['customTextTitle'];
    final Object? textBody = raw['customTextBody'];
    final Object? imagePath = raw['customImagePath'];
    if (f is! String || s is! num || l is! String) {
      return null;
    }
    return StoredCustomOrderEntry(
      fileName: f,
      songIndex: s.toInt(),
      verseIndex: v is num ? v.toInt() : 0,
      label: l,
      customTextTitle: textTitle is String ? textTitle : null,
      customTextBody: textBody is String ? textBody : null,
      customImagePath: imagePath is String ? imagePath : null,
    );
  }
}

class DtxOrderStore {
  static const String _kDisabledSongbooks = 'DisabledSongbooks';
  static const String _kCurrentCustomOrder = 'CurrentCustomOrder';
  static const String _kCurrentCustomOrderActive = 'CurrentCustomOrderActive';
  static const String _kCustomOrderPresets = 'CustomOrderPresets';

  Future<Set<String>> loadDisabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kDisabledSongbooks) ?? const <String>[])
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> saveDisabled(Set<String> disabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> sorted = disabled.toList()..sort();
    await prefs.setStringList(_kDisabledSongbooks, sorted);
  }

  Future<void> saveCurrentCustomOrder(
    List<StoredCustomOrderEntry> entries, {
    required bool active,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String json = jsonEncode(entries.map((StoredCustomOrderEntry e) => e.toJson()).toList());
    await prefs.setString(_kCurrentCustomOrder, json);
    await prefs.setBool(_kCurrentCustomOrderActive, active);
  }

  Future<({List<StoredCustomOrderEntry> entries, bool active})> loadCurrentCustomOrder() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_kCurrentCustomOrder) ?? '[]';
    final bool active = prefs.getBool(_kCurrentCustomOrderActive) ?? false;

    final List<StoredCustomOrderEntry> entries = <StoredCustomOrderEntry>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final Object? e in decoded) {
          final StoredCustomOrderEntry? parsed = StoredCustomOrderEntry.fromJson(e);
          if (parsed != null) {
            entries.add(parsed);
          }
        }
      }
    } catch (_) {}

    return (entries: entries, active: active);
  }

  Future<Map<String, List<StoredCustomOrderEntry>>> loadCustomOrderPresets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_kCustomOrderPresets) ?? '{}';
    final Map<String, List<StoredCustomOrderEntry>> out = <String, List<StoredCustomOrderEntry>>{};

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((Object? key, Object? value) {
          if (key is! String || value is! List) {
            return;
          }
          final List<StoredCustomOrderEntry> entries = <StoredCustomOrderEntry>[];
          for (final Object? e in value) {
            final StoredCustomOrderEntry? parsed = StoredCustomOrderEntry.fromJson(e);
            if (parsed != null) {
              entries.add(parsed);
            }
          }
          out[key] = entries;
        });
      }
    } catch (_) {}

    return out;
  }

  Future<void> saveCustomOrderPresets(Map<String, List<StoredCustomOrderEntry>> presets) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, List<Map<String, dynamic>>> serializable = <String, List<Map<String, dynamic>>>{};
    presets.forEach((String name, List<StoredCustomOrderEntry> entries) {
      serializable[name] = entries.map((StoredCustomOrderEntry e) => e.toJson()).toList();
    });
    await prefs.setString(_kCustomOrderPresets, jsonEncode(serializable));
  }
}
