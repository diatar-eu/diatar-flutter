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
    this.customType,
    this.customData = const <String, dynamic>{},
    this.additionalFields = const <String, dynamic>{},
  });

  final String fileName;
  final int songIndex;
  final int verseIndex;
  final String label;
  final String? customTextTitle;
  final String? customTextBody;
  final String? customImagePath;
  final String? customType;
  final Map<String, dynamic> customData;
  final Map<String, dynamic> additionalFields;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'fileName': fileName,
      'songIndex': songIndex,
      'verseIndex': verseIndex,
      'label': label,
      'customTextTitle': customTextTitle,
      'customTextBody': customTextBody,
      'customImagePath': customImagePath,
    };
    if (customType != null && customType!.trim().isNotEmpty) {
      out['customType'] = customType;
    }
    if (customData.isNotEmpty) {
      out['customData'] = customData;
    }
    out.addAll(additionalFields);
    return out;
  }

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
    final Object? type = raw['customType'];
    final Object? data = raw['customData'];
    if (f is! String || s is! num || l is! String) {
      return null;
    }

    final Map<String, dynamic> additionalFields = <String, dynamic>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final Object? key = entry.key;
      if (key is! String) {
        continue;
      }
      if (key == 'fileName' ||
          key == 'songIndex' ||
          key == 'verseIndex' ||
          key == 'label' ||
          key == 'customTextTitle' ||
          key == 'customTextBody' ||
          key == 'customImagePath' ||
          key == 'customType' ||
          key == 'customData') {
        continue;
      }
      additionalFields[key] = entry.value;
    }

    return StoredCustomOrderEntry(
      fileName: f,
      songIndex: s.toInt(),
      verseIndex: v is num ? v.toInt() : 0,
      label: l,
      customTextTitle: textTitle is String ? textTitle : null,
      customTextBody: textBody is String ? textBody : null,
      customImagePath: imagePath is String ? imagePath : null,
      customType: type is String && type.trim().isNotEmpty ? type : null,
      customData: data is Map
          ? Map<String, dynamic>.fromEntries(
              data.entries
                  .where(
                    (MapEntry<dynamic, dynamic> entry) => entry.key is String,
                  )
                  .map(
                    (MapEntry<dynamic, dynamic> entry) =>
                        MapEntry<String, dynamic>(
                          entry.key as String,
                          entry.value,
                        ),
                  ),
            )
          : const <String, dynamic>{},
      additionalFields: additionalFields,
    );
  }
}

class DtxOrderStore {
  static const String _kDisabledSongbooks = 'DisabledSongbooks';
  static const String _kCurrentCustomOrder = 'CurrentCustomOrder';
  static const String _kCurrentCustomOrderActive = 'CurrentCustomOrderActive';
  static const String _kCurrentCustomOrderBaseName =
      'CurrentCustomOrderBaseName';
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
    String? baseName,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String json = jsonEncode(
      entries.map((StoredCustomOrderEntry e) => e.toJson()).toList(),
    );
    await prefs.setString(_kCurrentCustomOrder, json);
    await prefs.setBool(_kCurrentCustomOrderActive, active);
    final String normalized = (baseName ?? '').trim();
    await prefs.setString(_kCurrentCustomOrderBaseName, normalized);
  }

  Future<
    ({List<StoredCustomOrderEntry> entries, bool active, String? baseName})
  >
  loadCurrentCustomOrder() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_kCurrentCustomOrder) ?? '[]';
    final bool active = prefs.getBool(_kCurrentCustomOrderActive) ?? false;
    final String baseNameRaw =
        prefs.getString(_kCurrentCustomOrderBaseName) ?? '';
    final String? baseName = baseNameRaw.trim().isEmpty
        ? null
        : baseNameRaw.trim();

    final List<StoredCustomOrderEntry> entries = <StoredCustomOrderEntry>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final Object? e in decoded) {
          final StoredCustomOrderEntry? parsed =
              StoredCustomOrderEntry.fromJson(e);
          if (parsed != null) {
            entries.add(parsed);
          }
        }
      }
    } catch (_) {}

    return (entries: entries, active: active, baseName: baseName);
  }

  Future<Map<String, List<StoredCustomOrderEntry>>>
  loadCustomOrderPresets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_kCustomOrderPresets) ?? '{}';
    final Map<String, List<StoredCustomOrderEntry>> out =
        <String, List<StoredCustomOrderEntry>>{};

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((Object? key, Object? value) {
          if (key is! String || value is! List) {
            return;
          }
          final List<StoredCustomOrderEntry> entries =
              <StoredCustomOrderEntry>[];
          for (final Object? e in value) {
            final StoredCustomOrderEntry? parsed =
                StoredCustomOrderEntry.fromJson(e);
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

  Future<void> saveCustomOrderPresets(
    Map<String, List<StoredCustomOrderEntry>> presets,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, List<Map<String, dynamic>>> serializable =
        <String, List<Map<String, dynamic>>>{};
    presets.forEach((String name, List<StoredCustomOrderEntry> entries) {
      serializable[name] = entries
          .map((StoredCustomOrderEntry e) => e.toJson())
          .toList();
    });
    await prefs.setString(_kCustomOrderPresets, jsonEncode(serializable));
  }
}
