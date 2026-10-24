import 'package:flutter/services.dart';

import 'desktop_hotkey.dart';

/// A gyorsbillentyű-parancs típusa.
///
/// Ugyanazt a feloldást használja a vezérlőablak és a vetítőablak, így a
/// rejtett vezérlőablak mellett is minden beállított gyorsbillentyű működik.
enum DesktopHotkeyKind { action, song, orderSet }

const String _kindAction = 'action';
const String _kindSong = 'song';
const String _kindOrderSet = 'orderSet';

String desktopHotkeyKindName(DesktopHotkeyKind kind) {
  switch (kind) {
    case DesktopHotkeyKind.action:
      return _kindAction;
    case DesktopHotkeyKind.song:
      return _kindSong;
    case DesktopHotkeyKind.orderSet:
      return _kindOrderSet;
  }
}

DesktopHotkeyKind? desktopHotkeyKindFromName(String name) {
  switch (name) {
    case _kindAction:
      return DesktopHotkeyKind.action;
    case _kindSong:
      return DesktopHotkeyKind.song;
    case _kindOrderSet:
      return DesktopHotkeyKind.orderSet;
    default:
      return null;
  }
}

/// Egy feloldott gyorsbillentyű-parancs, amely a vetítőablakból a vezérlőablak
/// felé továbbítható (és ott végrehajtható).
class DesktopHotkeyCommand {
  const DesktopHotkeyCommand(this.kind, this.value);

  final DesktopHotkeyKind kind;
  final String value;

  /// Csatornán továbbítható reprezentáció.
  Map<String, Object?> toMap() => <String, Object?>{
        'kind': desktopHotkeyKindName(kind),
        'value': value,
      };

  /// Visszafejti a csatornán érkező reprezentációt; érvénytelen bemenetre
  /// `null`-t ad.
  static DesktopHotkeyCommand? fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? kindRaw = raw['kind'];
    final Object? valueRaw = raw['value'];
    if (kindRaw is! String || valueRaw is! String || valueRaw.isEmpty) {
      return null;
    }
    final DesktopHotkeyKind? kind = desktopHotkeyKindFromName(kindRaw);
    if (kind == null) {
      return null;
    }
    return DesktopHotkeyCommand(kind, valueRaw);
  }

  @override
  bool operator ==(Object other) =>
      other is DesktopHotkeyCommand &&
      other.kind == kind &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'DesktopHotkeyCommand(${kind.name}, $value)';
}

/// Feloldja a lenyomott billentyűt a beállított gyorsbillentyű-térképek
/// alapján.
///
/// A sorrend megegyezik a vezérlőablakéval: művelet -> dal -> sorrend-készlet.
/// A gépelés (szövegmező) kiszűrése a hívó felelőssége.
DesktopHotkeyCommand? desktopHotkeyCommandForEvent(
  KeyEvent event, {
  required Map<String, String> actionHotkeys,
  required Map<String, String> songHotkeys,
  required Map<String, String> orderSetHotkeys,
}) {
  if (event is! KeyDownEvent) {
    return null;
  }

  final String? actionId = desktopHotkeyActionForEvent(event, actionHotkeys);
  if (actionId != null && actionId.isNotEmpty) {
    return DesktopHotkeyCommand(DesktopHotkeyKind.action, actionId);
  }

  final String combo = desktopHotkeyComboForEvent(event);
  if (combo.isEmpty) {
    return null;
  }

  final String? songBinding = desktopHotkeyValueForCombo(combo, songHotkeys);
  if (songBinding != null && songBinding.isNotEmpty) {
    return DesktopHotkeyCommand(DesktopHotkeyKind.song, songBinding);
  }

  final String? orderSetId = desktopHotkeyValueForCombo(combo, orderSetHotkeys);
  if (orderSetId != null && orderSetId.isNotEmpty) {
    return DesktopHotkeyCommand(DesktopHotkeyKind.orderSet, orderSetId);
  }

  return null;
}
