import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticLogSnapshot {
  const DiagnosticLogSnapshot({required this.enabled, required this.segments});

  final bool enabled;
  final Map<int, String> segments;
}

abstract interface class DiagnosticLogStore {
  static const int segmentCount = 32;

  Future<DiagnosticLogSnapshot> load();
  Future<void> setEnabled(bool enabled);
  Future<void> writeSegment(int index, String value);
  Future<void> clear();
}

class PreferencesDiagnosticLogStore implements DiagnosticLogStore {
  static const String _enabledKey = 'diagnostics.enabled';
  static String _segmentKey(int index) => 'diagnostics.segment.$index';

  @override
  Future<DiagnosticLogSnapshot> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return DiagnosticLogSnapshot(
      enabled: prefs.getBool(_enabledKey) ?? false,
      segments: <int, String>{
        for (int i = 0; i < DiagnosticLogStore.segmentCount; i++)
          if (prefs.getString(_segmentKey(i)) case final String value) i: value,
      },
    );
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _checkWrite(await prefs.setBool(_enabledKey, enabled));
  }

  @override
  Future<void> writeSegment(int index, String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _checkWrite(await prefs.setString(_segmentKey(index), value));
  }

  @override
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < DiagnosticLogStore.segmentCount; i++) {
      final String key = _segmentKey(i);
      if (prefs.containsKey(key)) {
        _checkWrite(await prefs.remove(key));
      }
    }
  }

  void _checkWrite(bool success) {
    if (!success) {
      throw StateError('Diagnostic storage write failed');
    }
  }
}
