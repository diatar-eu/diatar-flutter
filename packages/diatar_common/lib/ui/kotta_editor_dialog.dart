import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/projection_frame.dart';
import '../models/projection_globals.dart';
import '../models/records.dart';
import 'projector_painter.dart';

typedef KottaPreviewLineBuilder =
    String Function(List<KottaEditorElement> elements);

class KottaEditorElement {
  const KottaEditorElement({
    required this.command,
    required this.textOffset,
    this.isConditional = false,
  });

  final String command;
  final int textOffset;
  final bool isConditional;
}

class KottaEditorInitialState {
  const KottaEditorInitialState({
    required this.elements,
    required this.textLength,
    required this.kottaCursor,
    required this.textCursor,
    required this.isEditing,
  });

  final List<KottaEditorElement> elements;
  final int textLength;
  final int kottaCursor;
  final int textCursor;
  final bool isEditing;
}

class KottaEditorResult {
  const KottaEditorResult({required this.elements});

  final List<KottaEditorElement> elements;
}

class KottaEditorLabels {
  const KottaEditorLabels({
    required this.insertTitle,
    required this.editTitle,
    required this.cut,
    required this.copy,
    required this.paste,
    required this.undo,
    required this.redo,
    required this.clef,
    required this.keySignature,
    required this.barlines,
    required this.singleBarline,
    required this.doubleBarline,
    required this.finalBarline,
    required this.shortCaesura,
    required this.longCaesura,
    required this.openingRepeat,
    required this.bidirectionalRepeat,
    required this.closingRepeat,
    required this.meters,
    required this.meterSymbol,
    required this.meter44,
    required this.meter24,
    required this.meter34,
    required this.meter38,
    required this.meter68,
    required this.meter22,
    required this.meter32,
    required this.meter54,
    required this.meter64,
    required this.rests,
    required this.dotted,
    required this.stemDown,
    required this.stemless,
    required this.compact,
    required this.lowerSlur,
    required this.upperSlur,
    required this.triplet,
    required this.quintuplet,
    required this.beaming,
    required this.accidentals,
    required this.flat,
    required this.natural,
    required this.sharp,
    required this.doubleFlat,
    required this.doubleSharp,
    required this.agogics,
    required this.tenuto,
    required this.staccato,
    required this.marcato,
    required this.martellato,
    required this.fermata,
    required this.trill,
    required this.lowerTrill,
    required this.mordent,
    required this.lowerMordent,
    required this.wholeRest,
    required this.halfRest,
    required this.quarterRest,
    required this.eighthRest,
    required this.sixteenthRest,
    required this.notes,
    required this.noteProperties,
    required this.longa,
    required this.brevis,
    required this.semibrevis,
    required this.wholeNote,
    required this.halfNote,
    required this.quarterNote,
    required this.eighthNote,
    required this.sixteenthNote,
    required this.gClef,
    required this.fClef,
    required this.sopranoClef,
    required this.mezzoSopranoClef,
    required this.altoClef,
    required this.tenorClef,
    required this.baritoneClef,
    required this.doClefLine,
    required this.doClefSpace,
    required this.flats,
    required this.sharps,
    required this.flatKeys,
    required this.sharpKeys,
    required this.cancel,
    required this.apply,
  }) : assert(flatKeys.length == 7),
       assert(sharpKeys.length == 7);

  final String insertTitle;
  final String editTitle;
  final String cut;
  final String copy;
  final String paste;
  final String undo;
  final String redo;
  final String clef;
  final String keySignature;
  final String barlines;
  final String singleBarline;
  final String doubleBarline;
  final String finalBarline;
  final String shortCaesura;
  final String longCaesura;
  final String openingRepeat;
  final String bidirectionalRepeat;
  final String closingRepeat;
  final String meters;
  final String Function(int numerator, int denominator) meterSymbol;
  final String meter44;
  final String meter24;
  final String meter34;
  final String meter38;
  final String meter68;
  final String meter22;
  final String meter32;
  final String meter54;
  final String meter64;
  final String rests;
  final String dotted;
  final String stemDown;
  final String stemless;
  final String compact;
  final String lowerSlur;
  final String upperSlur;
  final String triplet;
  final String quintuplet;
  final String beaming;
  final String accidentals;
  final String flat;
  final String natural;
  final String sharp;
  final String doubleFlat;
  final String doubleSharp;
  final String agogics;
  final String tenuto;
  final String staccato;
  final String marcato;
  final String martellato;
  final String fermata;
  final String trill;
  final String lowerTrill;
  final String mordent;
  final String lowerMordent;
  final String wholeRest;
  final String halfRest;
  final String quarterRest;
  final String eighthRest;
  final String sixteenthRest;
  final String notes;
  final String noteProperties;
  final String longa;
  final String brevis;
  final String semibrevis;
  final String wholeNote;
  final String halfNote;
  final String quarterNote;
  final String eighthNote;
  final String sixteenthNote;
  final String gClef;
  final String fClef;
  final String sopranoClef;
  final String mezzoSopranoClef;
  final String altoClef;
  final String tenorClef;
  final String baritoneClef;
  final String Function(int line) doClefLine;
  final String Function(int lowerLine, int upperLine) doClefSpace;
  final String Function(int count) flats;
  final String Function(int count) sharps;
  final List<String> flatKeys;
  final List<String> sharpKeys;
  final String cancel;
  final String apply;
}

Future<KottaEditorResult?> showKottaEditorDialog({
  required BuildContext context,
  required KottaEditorLabels labels,
  required KottaPreviewLineBuilder previewLineBuilder,
  required KottaEditorInitialState initialState,
}) {
  return showDialog<KottaEditorResult>(
    context: context,
    builder: (BuildContext context) => _KottaEditorDialog(
      labels: labels,
      previewLineBuilder: previewLineBuilder,
      initialState: initialState,
    ),
  );
}

class _KottaEditorDialog extends StatefulWidget {
  const _KottaEditorDialog({
    required this.labels,
    required this.previewLineBuilder,
    required this.initialState,
  });

  final KottaEditorLabels labels;
  final KottaPreviewLineBuilder previewLineBuilder;
  final KottaEditorInitialState initialState;

  @override
  State<_KottaEditorDialog> createState() => _KottaEditorDialogState();
}

enum _KottaNoteMode {
  stemless('[0', '[1'),
  compact('Rt', 'rt');

  const _KottaNoteMode(this.enabled, this.disabled);

  final String enabled;
  final String disabled;
}

enum _KottaGroupKind { slur, tuplet }

class _KottaNoteGroup {
  _KottaNoteGroup(this.value);

  String value;
}

typedef _KottaNoteState = ({String rhythm, bool stemless, bool compact});

typedef _KottaEditorSnapshot = ({
  List<KottaEditorElement> elements,
  int kottaCursor,
  int textCursor,
  int? selectionAnchor,
  bool textCursorActive,
  bool dottedRests,
  bool dottedNotes,
  bool? stemDownOverride,
  Map<_KottaNoteMode, bool> noteModeOverrides,
  bool? beamingOverride,
  Map<_KottaGroupKind, String> groupOverrides,
  Map<String, String> noteModifiers,
});

class _KottaEditorDialogState extends State<_KottaEditorDialog> {
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'kotta-editor');
  late List<KottaEditorElement> _elements;
  late int _kottaCursor;
  late int _textCursor;
  int? _kottaSelectionAnchor;
  late final Timer _caretTimer;
  bool _textCursorActive = false;
  bool _activeCursorVisible = true;
  bool _dottedRests = false;
  bool _dottedNotes = false;
  bool? _stemDownOverride;
  final Map<_KottaNoteMode, bool> _noteModeOverrides = <_KottaNoteMode, bool>{};
  bool? _beamingOverride;
  final Map<_KottaGroupKind, String> _groupOverrides =
      <_KottaGroupKind, String>{};
  final Map<String, String> _noteModifiers = <String, String>{};
  final List<_KottaEditorSnapshot> _undoStack = <_KottaEditorSnapshot>[];
  final List<_KottaEditorSnapshot> _redoStack = <_KottaEditorSnapshot>[];

  _KottaEditorSnapshot _snapshot() => (
    elements: List<KottaEditorElement>.of(_elements),
    kottaCursor: _kottaCursor,
    textCursor: _textCursor,
    selectionAnchor: _kottaSelectionAnchor,
    textCursorActive: _textCursorActive,
    dottedRests: _dottedRests,
    dottedNotes: _dottedNotes,
    stemDownOverride: _stemDownOverride,
    noteModeOverrides: Map<_KottaNoteMode, bool>.of(_noteModeOverrides),
    beamingOverride: _beamingOverride,
    groupOverrides: Map<_KottaGroupKind, String>.of(_groupOverrides),
    noteModifiers: Map<String, String>.of(_noteModifiers),
  );

  void _edit(VoidCallback change) {
    final _KottaEditorSnapshot before = _snapshot();
    setState(() {
      change();
      final bool changed =
          before.elements.length != _elements.length ||
          before.elements.asMap().entries.any((entry) {
            final KottaEditorElement current = _elements[entry.key];
            return entry.value.command != current.command ||
                entry.value.textOffset != current.textOffset ||
                entry.value.isConditional != current.isConditional;
          });
      if (changed) {
        _undoStack.add(before);
        _redoStack.clear();
      }
    });
  }

  void _restoreHistory(
    List<_KottaEditorSnapshot> from,
    List<_KottaEditorSnapshot> to,
  ) {
    if (from.isEmpty) {
      return;
    }
    setState(() {
      to.add(_snapshot());
      final _KottaEditorSnapshot snapshot = from.removeLast();
      _elements = List<KottaEditorElement>.of(snapshot.elements);
      _kottaCursor = snapshot.kottaCursor;
      _textCursor = snapshot.textCursor;
      _kottaSelectionAnchor = snapshot.selectionAnchor;
      _textCursorActive = snapshot.textCursorActive;
      _dottedRests = snapshot.dottedRests;
      _dottedNotes = snapshot.dottedNotes;
      _stemDownOverride = snapshot.stemDownOverride;
      _noteModeOverrides
        ..clear()
        ..addAll(snapshot.noteModeOverrides);
      _beamingOverride = snapshot.beamingOverride;
      _groupOverrides
        ..clear()
        ..addAll(snapshot.groupOverrides);
      _noteModifiers
        ..clear()
        ..addAll(snapshot.noteModifiers);
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  void _undo() => _restoreHistory(_undoStack, _redoStack);

  void _redo() => _restoreHistory(_redoStack, _undoStack);

  bool get _isValid =>
      widget.initialState.elements.isNotEmpty || _elements.isNotEmpty;

  String _precedingPitch(int position) {
    for (int index = position - 1; index >= 0; index--) {
      if (_isPitch(_elements[index].command)) {
        return _elements[index].command;
      }
    }
    return '2g';
  }

  bool get _stemDown {
    final TextSelection? selection = _kottaSelection;
    if (selection != null) {
      final Iterable<String> pitches = _elements
          .sublist(selection.start, selection.end)
          .map((element) => element.command)
          .where(_isPitch);
      return pitches.isNotEmpty &&
          pitches.every((pitch) => pitch == pitch.toUpperCase());
    }
    final String pitch = _precedingPitch(
      _kottaSelection?.start ?? _kottaCursor,
    );
    return _stemDownOverride ?? (pitch == pitch.toUpperCase());
  }

  Map<KottaEditorElement, int> _beamGroups([
    List<KottaEditorElement>? elements,
  ]) {
    final Map<KottaEditorElement, int> groups = <KottaEditorElement, int>{};
    int nextGroup = 0;
    int? group;
    for (final KottaEditorElement element in elements ?? _elements) {
      if (element.command == '[?') {
        group ??= nextGroup++;
      } else if (element.command[0] == ']' &&
          element.command != ']3' &&
          element.command != ']5') {
        group = null;
      } else if (_isPitch(element.command) && group != null) {
        groups[element] = group;
      }
    }
    return groups;
  }

  KottaEditorElement? _precedingNote(int position) {
    for (int index = position - 1; index >= 0; index--) {
      if (_isPitch(_elements[index].command)) {
        return _elements[index];
      }
    }
    return null;
  }

  bool _isSlurMarker(String command) =>
      const <String>{'(a', ')a', '(f', ')f'}.contains(command);

  Map<KottaEditorElement, _KottaNoteGroup> _slurGroups([
    List<KottaEditorElement>? elements,
  ]) {
    final Map<KottaEditorElement, _KottaNoteGroup> groups =
        <KottaEditorElement, _KottaNoteGroup>{};
    _KottaNoteGroup? pending;
    _KottaNoteGroup? active;
    for (final KottaEditorElement element in elements ?? _elements) {
      final String command = element.command;
      if (_isSlurMarker(command)) {
        if (command[0] == '(') {
          pending = _KottaNoteGroup(command[1]);
        } else {
          // The legacy renderer takes the direction from the closing code.
          active?.value = command[1];
          active = null;
          pending = null;
        }
      } else if (_isPitch(command)) {
        active ??= pending;
        pending = null;
        if (active != null) {
          groups[element] = active;
        }
      }
    }
    return groups;
  }

  bool _isTupletMarker(String command) =>
      const <String>{'[3', ']3', '[5', ']5'}.contains(command);

  Map<KottaEditorElement, _KottaNoteGroup> _tupletGroups([
    List<KottaEditorElement>? elements,
  ]) {
    final Map<KottaEditorElement, _KottaNoteGroup> groups =
        <KottaEditorElement, _KottaNoteGroup>{};
    _KottaNoteGroup? active;
    for (final KottaEditorElement element in elements ?? _elements) {
      final String command = element.command;
      if (_isTupletMarker(command)) {
        active = command[0] == '[' ? _KottaNoteGroup(command[1]) : null;
      } else if (_isPitch(command) && active != null) {
        groups[element] = active;
      }
    }
    return groups;
  }

  Map<KottaEditorElement, _KottaNoteGroup> _noteGroups(_KottaGroupKind kind) =>
      kind == _KottaGroupKind.slur ? _slurGroups() : _tupletGroups();

  String get _slurDirection => _groupValue(_KottaGroupKind.slur);

  String get _tuplet => _groupValue(_KottaGroupKind.tuplet);

  String _groupValue(_KottaGroupKind kind) {
    final Map<KottaEditorElement, _KottaNoteGroup> groups = _noteGroups(kind);
    final TextSelection? selection = _kottaSelection;
    if (selection == null) {
      return _groupOverrides[kind] ??
          groups[_precedingNote(_kottaCursor)]?.value ??
          '';
    }
    final List<KottaEditorElement> notes = _elements
        .sublist(selection.start, selection.end)
        .where((element) => _isPitch(element.command))
        .toList();
    if (notes.isEmpty) {
      return '';
    }
    final String? value = groups[notes.first]?.value;
    return value != null &&
            notes.every((element) => groups[element]?.value == value)
        ? value
        : '';
  }

  void _toggleGroup(_KottaGroupKind kind, String value) {
    final bool apply = _groupValue(kind) != value;
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        _groupOverrides[kind] = apply ? value : '';
        return;
      }
      final Map<KottaEditorElement, _KottaNoteGroup> groups = _noteGroups(kind);
      final _KottaNoteGroup group = _KottaNoteGroup(value);
      for (final KottaEditorElement element in _elements.sublist(
        selection.start,
        selection.end,
      )) {
        if (_isPitch(element.command)) {
          if (apply) {
            groups[element] = group;
          } else {
            groups.remove(element);
          }
        }
      }
      _normalizeCommands(
        null,
        kind == _KottaGroupKind.slur ? groups : null,
        kind == _KottaGroupKind.tuplet ? groups : null,
      );
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  bool _noteModeBefore(_KottaNoteMode mode, int position) {
    for (int index = position - 1; index >= 0; index--) {
      final String command = _elements[index].command;
      if (command == mode.enabled || command == mode.disabled) {
        return command == mode.enabled;
      }
    }
    return false;
  }

  bool get _stemless => _noteModeState(_KottaNoteMode.stemless);

  bool get _compact => _noteModeState(_KottaNoteMode.compact);

  bool _noteModeState(_KottaNoteMode mode) {
    final TextSelection? selection = _kottaSelection;
    if (selection == null) {
      if (_noteModeOverrides[mode] case final bool value) {
        return value;
      }
      for (int index = _kottaCursor - 1; index >= 0; index--) {
        if (_isPitch(_elements[index].command)) {
          return _noteModeBefore(mode, index);
        }
      }
      return false;
    }
    bool found = false;
    bool enabled = _noteModeBefore(mode, selection.start);
    for (int index = selection.start; index < selection.end; index++) {
      final String command = _elements[index].command;
      if (command == mode.enabled || command == mode.disabled) {
        enabled = command == mode.enabled;
      } else if (_isPitch(command)) {
        if (!enabled) {
          return false;
        }
        found = true;
      }
    }
    return found;
  }

  void _toggleNoteMode(_KottaNoteMode mode) {
    final bool apply = !_noteModeState(mode);
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        _noteModeOverrides[mode] = apply;
        return;
      }
      if (!_elements
          .sublist(selection.start, selection.end)
          .any((element) => _isPitch(element.command))) {
        return;
      }
      final List<KottaEditorElement> updated = <KottaEditorElement>[];
      bool original = false;
      bool output = false;
      int start = 0;
      int end = 0;
      for (int index = 0; index <= _elements.length; index++) {
        if (index == selection.start) {
          start = updated.length;
        }
        if (index == selection.end) {
          end = updated.length;
          // Note modes persist: restore the original at the selection edge.
          if (index < _elements.length && output != original) {
            final KottaEditorElement following = _elements[index];
            updated.add(
              KottaEditorElement(
                command: original ? mode.enabled : mode.disabled,
                textOffset: following.textOffset,
                isConditional: following.isConditional,
              ),
            );
            output = original;
          }
        }
        if (index == _elements.length) {
          break;
        }
        final KottaEditorElement element = _elements[index];
        final bool selected = index >= selection.start && index < selection.end;
        if (element.command == mode.enabled ||
            element.command == mode.disabled) {
          original = element.command == mode.enabled;
          if (selected) {
            continue;
          }
          output = original;
        } else if (selected && _isPitch(element.command) && output != apply) {
          updated.add(
            KottaEditorElement(
              command: apply ? mode.enabled : mode.disabled,
              textOffset: element.textOffset,
              isConditional: element.isConditional,
            ),
          );
          output = apply;
        }
        updated.add(element);
      }
      _elements = updated;
      final bool forward = selection.baseOffset < selection.extentOffset;
      _kottaSelectionAnchor = forward ? start : end;
      _kottaCursor = forward ? end : start;
      _normalizeNoteMode(mode);
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  bool get _beaming {
    final Map<KottaEditorElement, int> groups = _beamGroups();
    final TextSelection? selection = _kottaSelection;
    if (selection == null) {
      return _beamingOverride ??
          groups.containsKey(_precedingNote(_kottaCursor));
    }
    final List<KottaEditorElement> notes = _elements
        .sublist(selection.start, selection.end)
        .where((element) => _isPitch(element.command))
        .toList();
    return notes.isNotEmpty && notes.every(groups.containsKey);
  }

  void _normalizeNoteMode(_KottaNoteMode mode) {
    final Set<int> requiredMarkers = <int>{};
    bool desired = false;
    bool output = false;
    int? pendingMarker;
    for (int index = 0; index < _elements.length; index++) {
      final String command = _elements[index].command;
      if (command == mode.enabled || command == mode.disabled) {
        desired = command == mode.enabled;
        pendingMarker = index;
      } else if (_isPitch(command) &&
          desired != output &&
          pendingMarker != null) {
        requiredMarkers.add(pendingMarker);
        output = desired;
      }
    }
    final List<KottaEditorElement> updated = <KottaEditorElement>[];
    final List<int> positions = List<int>.filled(_elements.length + 1, 0);
    for (int index = 0; index < _elements.length; index++) {
      positions[index] = updated.length;
      final KottaEditorElement element = _elements[index];
      if ((element.command == mode.enabled ||
              element.command == mode.disabled) &&
          !requiredMarkers.contains(index)) {
        continue;
      }
      updated.add(element);
    }
    positions[_elements.length] = updated.length;
    _kottaCursor = positions[_kottaCursor];
    if (_kottaSelectionAnchor case final int anchor) {
      _kottaSelectionAnchor = positions[anchor];
    }
    _elements = updated;
  }

  void _normalizeCommands([
    Map<KottaEditorElement, int>? groups,
    Map<KottaEditorElement, _KottaNoteGroup>? slurs,
    Map<KottaEditorElement, _KottaNoteGroup>? tuplets,
    Map<KottaEditorElement, _KottaNoteState>? states,
  ]) {
    slurs ??= _slurGroups();
    tuplets ??= _tupletGroups();
    if (states != null) {
      _applyNormalized(_withNoteStates(_elements, states));
    }
    for (final _KottaNoteMode mode in _KottaNoteMode.values) {
      _normalizeNoteMode(mode);
    }
    groups ??= _beamGroups();
    _normalizeNoteGroups<int>(
      groups,
      isMarker: (command) => command == '[?' || command == ']?',
      opening: (_) => '[?',
      closing: (_) => ']?',
    );
    _normalizeNoteGroups<_KottaNoteGroup>(
      slurs,
      isMarker: _isSlurMarker,
      opening: (group) => '(${group.value}',
      closing: (group) => ')${group.value}',
    );
    _normalizeNoteGroups<_KottaNoteGroup>(
      tuplets,
      isMarker: _isTupletMarker,
      opening: (group) => '[${group.value}',
      closing: (group) => ']${group.value}',
    );
  }

  void _normalizeNoteGroups<T>(
    Map<KottaEditorElement, T> groups, {
    required bool Function(String) isMarker,
    required String Function(T) opening,
    required String Function(T) closing,
  }) {
    _applyNormalized(
      _normalizedNoteGroups(
        _elements,
        groups,
        isMarker: isMarker,
        opening: opening,
        closing: closing,
      ),
    );
  }

  void _applyNormalized(
    ({List<KottaEditorElement> elements, List<int> positions}) result,
  ) {
    _kottaCursor = result.positions[_kottaCursor];
    if (_kottaSelectionAnchor case final int anchor) {
      _kottaSelectionAnchor = result.positions[anchor];
    }
    _elements = result.elements;
  }

  ({List<KottaEditorElement> elements, List<int> positions})
  _normalizedNoteGroups<T>(
    List<KottaEditorElement> elements,
    Map<KottaEditorElement, T> groups, {
    required bool Function(String) isMarker,
    required String Function(T) opening,
    required String Function(T) closing,
  }) {
    final List<KottaEditorElement> updated = <KottaEditorElement>[];
    final List<int> positions = List<int>.filled(elements.length + 1, 0);
    final List<KottaEditorElement> notes = elements
        .where((element) => _isPitch(element.command))
        .toList();
    int noteIndex = 0;
    T? previousGroup;
    for (int index = 0; index < elements.length; index++) {
      positions[index] = updated.length;
      final KottaEditorElement element = elements[index];
      if (isMarker(element.command)) {
        continue;
      }
      if (!_isPitch(element.command)) {
        updated.add(element);
        continue;
      }
      final T? group = groups[element];
      KottaEditorElement marker(String command) => KottaEditorElement(
        command: command,
        textOffset: element.textOffset,
        isConditional: element.isConditional,
      );
      if (group != null && group != previousGroup) {
        updated.add(marker(opening(group)));
      }
      updated.add(element);
      noteIndex++;
      final T? nextGroup = noteIndex < notes.length
          ? groups[notes[noteIndex]]
          : null;
      if (group != null && group != nextGroup) {
        updated.add(marker(closing(group)));
      }
      previousGroup = group;
    }
    positions[elements.length] = updated.length;
    return (elements: updated, positions: positions);
  }

  Map<KottaEditorElement, _KottaNoteState> _noteStates([
    List<KottaEditorElement>? elements,
  ]) {
    final Map<KottaEditorElement, _KottaNoteState> states =
        <KottaEditorElement, _KottaNoteState>{};
    String rhythm = 'r4';
    bool stemless = false;
    bool compact = false;
    for (final KottaEditorElement element in elements ?? _elements) {
      final String command = element.command;
      if (_isRhythm(command)) {
        rhythm = command;
      } else if (command == '[0' || command == '[1') {
        stemless = command == '[0';
      } else if (command == 'Rt' || command == 'rt') {
        compact = command == 'Rt';
      } else if (_isPitch(command)) {
        states[element] = (
          rhythm: rhythm,
          stemless: stemless,
          compact: compact,
        );
      }
    }
    return states;
  }

  ({List<KottaEditorElement> elements, List<int> positions}) _withNoteStates(
    List<KottaEditorElement> elements,
    Map<KottaEditorElement, _KottaNoteState> states,
  ) {
    final List<KottaEditorElement> updated = <KottaEditorElement>[];
    final List<int> positions = List<int>.filled(elements.length + 1, 0);
    String rhythm = 'r4';
    bool stemless = false;
    bool compact = false;
    for (int index = 0; index < elements.length; index++) {
      positions[index] = updated.length;
      final KottaEditorElement element = elements[index];
      final String command = element.command;
      void add(String command) => updated.add(
        KottaEditorElement(
          command: command,
          textOffset: element.textOffset,
          isConditional: element.isConditional,
        ),
      );
      if (states[element] case final _KottaNoteState state) {
        if (rhythm != state.rhythm) {
          add(state.rhythm);
          rhythm = state.rhythm;
        }
        if (stemless != state.stemless) {
          add(state.stemless ? '[0' : '[1');
          stemless = state.stemless;
        }
        if (compact != state.compact) {
          add(state.compact ? 'Rt' : 'rt');
          compact = state.compact;
        }
      }
      updated.add(element);
      if (_isRhythm(command)) {
        rhythm = command;
      } else if (command == '[0' || command == '[1') {
        stemless = command == '[0';
      } else if (command == 'Rt' || command == 'rt') {
        compact = command == 'Rt';
      }
    }
    positions[elements.length] = updated.length;
    return (elements: updated, positions: positions);
  }

  void _toggleBeaming() {
    final bool apply = !_beaming;
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        _beamingOverride = apply;
        return;
      }
      final Map<KottaEditorElement, int> groups = _beamGroups();
      final int group = groups.values.fold<int>(-1, math.max) + 1;
      for (final KottaEditorElement element in _elements.sublist(
        selection.start,
        selection.end,
      )) {
        if (_isPitch(element.command)) {
          if (apply) {
            groups[element] = group;
          } else {
            groups.remove(element);
          }
        }
      }
      _normalizeCommands(groups);
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  void _toggleStemDirection() {
    final bool down = !_stemDown;
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        _stemDownOverride = down;
        return;
      }
      for (int index = selection.start; index < selection.end; index++) {
        final KottaEditorElement element = _elements[index];
        if (!_isPitch(element.command)) {
          continue;
        }
        _elements[index] = KottaEditorElement(
          command: down
              ? element.command.toUpperCase()
              : element.command.toLowerCase(),
          textOffset: element.textOffset,
          isConditional: element.isConditional,
        );
      }
      _stemDownOverride = null;
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  TextSelection? get _kottaSelection {
    final int? anchor = _kottaSelectionAnchor;
    if (anchor == null || anchor == _kottaCursor) {
      return null;
    }
    final int rawStart = math.min(anchor, _kottaCursor);
    final int rawEnd = math.max(anchor, _kottaCursor);
    int start = rawStart;
    while (start < rawEnd &&
        !_isVisibleKottaElement(_elements[start].command)) {
      start++;
    }
    if (start == rawEnd) {
      return null;
    }
    int end = rawEnd;
    while (end > start && !_isVisibleKottaElement(_elements[end - 1].command)) {
      end--;
    }
    while (start > 0 &&
        !_isVisibleKottaElement(_elements[start - 1].command) &&
        !_isClosingCommand(_elements[start - 1].command)) {
      start--;
    }
    while (end < _elements.length &&
        _isClosingCommand(_elements[end].command)) {
      end++;
    }
    return TextSelection(
      baseOffset: anchor < _kottaCursor ? start : end,
      extentOffset: anchor < _kottaCursor ? end : start,
    );
  }

  bool _isClosingCommand(String command) =>
      command[0] == ')' ||
      command[0] == ']' ||
      command == '[1' ||
      command == 'rt';

  void _normalizeSelectionBoundaries() {
    bool hasPrefix = false;
    bool needsOrdering = false;
    for (final KottaEditorElement element in _elements) {
      if (_isVisibleKottaElement(element.command)) {
        hasPrefix = false;
      } else if (_isClosingCommand(element.command)) {
        needsOrdering |= hasPrefix;
      } else {
        hasPrefix = true;
      }
    }
    if (!needsOrdering) {
      return;
    }
    _normalizeCommands();
    final List<KottaEditorElement> updated = <KottaEditorElement>[];
    final List<KottaEditorElement> prefixes = <KottaEditorElement>[];
    final List<int> positions = List<int>.filled(_elements.length + 1, 0);
    for (int index = 0; index < _elements.length; index++) {
      positions[index] = updated.length;
      final KottaEditorElement element = _elements[index];
      if (_isVisibleKottaElement(element.command)) {
        // Closings stay on the left of a boundary, note prefixes on the right.
        for (final KottaEditorElement prefix in prefixes) {
          updated.add(
            KottaEditorElement(
              command: prefix.command,
              textOffset: element.textOffset,
              isConditional: prefix.isConditional,
            ),
          );
        }
        prefixes.clear();
        updated.add(element);
      } else if (_isClosingCommand(element.command)) {
        updated.add(element);
      } else {
        prefixes.add(element);
      }
    }
    updated.addAll(prefixes);
    positions[_elements.length] = updated.length;
    _applyNormalized((elements: updated, positions: positions));
  }

  List<KottaEditorElement> _clipboardElements(TextSelection selection) {
    List<KottaEditorElement> elements = _withNoteStates(
      _elements.sublist(selection.start, selection.end),
      _noteStates(),
    ).elements;
    elements = _normalizedNoteGroups(
      elements,
      _beamGroups(),
      isMarker: (command) => command == '[?' || command == ']?',
      opening: (_) => '[?',
      closing: (_) => ']?',
    ).elements;
    elements = _normalizedNoteGroups(
      elements,
      _slurGroups(),
      isMarker: _isSlurMarker,
      opening: (group) => '(${group.value}',
      closing: (group) => ')${group.value}',
    ).elements;
    elements = _normalizedNoteGroups(
      elements,
      _tupletGroups(),
      isMarker: _isTupletMarker,
      opening: (group) => '[${group.value}',
      closing: (group) => ']${group.value}',
    ).elements;
    for (final _KottaNoteMode mode in _KottaNoteMode.values) {
      final Iterable<KottaEditorElement> markers = elements.where(
        (element) =>
            element.command == mode.enabled || element.command == mode.disabled,
      );
      if (markers.isNotEmpty && markers.last.command == mode.enabled) {
        final KottaEditorElement last = elements.last;
        elements.add(
          KottaEditorElement(
            command: mode.disabled,
            textOffset: last.textOffset,
            isConditional: last.isConditional,
          ),
        );
      }
    }
    return elements;
  }

  Future<void> _copySelection({bool cut = false}) async {
    final TextSelection? selection = _kottaSelection;
    if (selection == null) {
      return;
    }
    final List<KottaEditorElement> selected = _elements.sublist(
      selection.start,
      selection.end,
    );
    await Clipboard.setData(
      ClipboardData(
        text: _clipboardElements(selection)
            .map(
              (element) =>
                  '${element.isConditional ? r'\?K' : r'\K'}'
                  '${element.command};',
            )
            .join(),
      ),
    );
    if (!mounted) {
      return;
    }
    if (cut &&
        _kottaSelection == selection &&
        selection.end <= _elements.length &&
        selected.asMap().entries.every(
          (entry) =>
              identical(entry.value, _elements[selection.start + entry.key]),
        )) {
      final Map<KottaEditorElement, int> groups = _beamGroups();
      final Map<KottaEditorElement, _KottaNoteGroup> slurs = _slurGroups();
      final Map<KottaEditorElement, _KottaNoteGroup> tuplets = _tupletGroups();
      final Map<KottaEditorElement, _KottaNoteState> states = _noteStates();
      _edit(() {
        _textCursor = _elements[selection.start].textOffset;
        _elements.removeRange(selection.start, selection.end);
        _kottaCursor = selection.start;
        _kottaSelectionAnchor = null;
        _normalizeCommands(groups, slurs, tuplets, states);
        _textCursorActive = false;
        _activeCursorVisible = true;
      });
    }
    _editorFocusNode.requestFocus();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) {
      return;
    }
    final String source = data!.text!;
    final RegExp notation = RegExp(r'\\(\?)?K((?:[^;\\\r\n]{2})+);');
    final List<RegExpMatch> matches = notation.allMatches(source).toList();
    if (matches.isEmpty ||
        matches.map((match) => match.group(0)).join() != source) {
      return;
    }
    _edit(() {
      final Map<KottaEditorElement, int> groups = _beamGroups();
      final Map<KottaEditorElement, _KottaNoteGroup> slurs = _slurGroups();
      final Map<KottaEditorElement, _KottaNoteGroup> tuplets = _tupletGroups();
      final Map<KottaEditorElement, _KottaNoteState> states = _noteStates();
      final TextSelection? selection = _kottaSelection;
      if (selection != null) {
        _kottaCursor = selection.start;
        _textCursor = _elements[selection.start].textOffset;
        _elements.removeRange(selection.start, selection.end);
      }
      final List<KottaEditorElement> inserted = <KottaEditorElement>[
        for (final RegExpMatch match in matches)
          for (int index = 0; index < match.group(2)!.length; index += 2)
            KottaEditorElement(
              command: match.group(2)!.substring(index, index + 2),
              textOffset: _textCursor,
              isConditional: match.group(1) != null,
            ),
      ];
      final int groupOffset = groups.values.fold<int>(-1, math.max) + 1;
      groups.addAll(
        _beamGroups(
          inserted,
        ).map((element, group) => MapEntry(element, group + groupOffset)),
      );
      slurs.addAll(_slurGroups(inserted));
      tuplets.addAll(_tupletGroups(inserted));
      states.addAll(_noteStates(inserted));
      _elements.insertAll(_kottaCursor, inserted);
      _kottaCursor += inserted.length;
      _kottaSelectionAnchor = null;
      _normalizeCommands(groups, slurs, tuplets, states);
      _textCursorActive = false;
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _elements = List<KottaEditorElement>.from(widget.initialState.elements);
    _kottaCursor = widget.initialState.kottaCursor.clamp(0, _elements.length);
    _textCursor = widget.initialState.textCursor.clamp(
      0,
      widget.initialState.textLength,
    );
    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() => _activeCursorVisible = !_activeCursorVisible);
      }
    });
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _editorFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    _caretTimer.cancel();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _insertCommand(String command) {
    assert(command.length == 2);
    if (_canDot(command)) {
      if (command[0] == 's' && _dottedRests ||
          command[0] == 'r' && _dottedNotes) {
        command = _withDot(command, true);
      }
    }
    final bool beaming = _beaming;
    final String slurDirection = _slurDirection;
    final Map<KottaEditorElement, _KottaNoteGroup> slurs = _slurGroups();
    final String tuplet = _tuplet;
    final Map<KottaEditorElement, _KottaNoteGroup> tuplets = _tupletGroups();
    final Map<_KottaNoteMode, bool> modes = <_KottaNoteMode, bool>{
      for (final _KottaNoteMode mode in _KottaNoteMode.values)
        mode: _noteModeState(mode),
    };
    final Map<KottaEditorElement, int> groups = _beamGroups();
    final Map<KottaEditorElement, _KottaNoteState> states = _noteStates();
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      final String followingRhythm = _rhythmBefore(
        selection?.end ?? _kottaCursor,
      );
      final Map<_KottaNoteMode, bool> followingModes = <_KottaNoteMode, bool>{
        for (final _KottaNoteMode mode in _KottaNoteMode.values)
          mode: _noteModeBefore(mode, selection?.end ?? _kottaCursor),
      };
      if (selection != null) {
        _kottaCursor = selection.start;
        _textCursor = _elements[selection.start].textOffset;
        _elements.removeRange(selection.start, selection.end);
      }
      _kottaSelectionAnchor = null;
      if (_isRhythm(command)) {
        _insertNote(
          command,
          followingRhythm: followingRhythm,
          beaming: beaming,
          modes: modes,
          followingModes: followingModes,
          groups: groups,
          slurs: slurs,
          slurDirection: slurDirection,
          tuplets: tuplets,
          tuplet: tuplet,
        );
      } else {
        _elements.insert(
          _kottaCursor,
          KottaEditorElement(command: command, textOffset: _textCursor),
        );
        _kottaCursor++;
        _normalizeCommands(groups, slurs, tuplets, states);
      }
      _textCursorActive = false;
      _activeCursorVisible = true;
    });
  }

  bool _isPitch(String command) => RegExp(
    r'^(?:[12][gahcdef]|3[gahcd])$',
    caseSensitive: false,
  ).hasMatch(command);

  bool _isRhythm(String command) =>
      command.length == 2 &&
      (command[0] == 'r' || command[0] == 'R') &&
      command[1] != 't';

  String _rhythmBefore(int position) {
    for (int index = position - 1; index >= 0; index--) {
      if (_isRhythm(_elements[index].command)) {
        return _elements[index].command;
      }
    }
    return 'r4';
  }

  bool _canDot(String command) => RegExp(r'^[rRsS][12486]$').hasMatch(command);

  String _withDot(String command, bool dotted) =>
      '${dotted ? command[0].toUpperCase() : command[0].toLowerCase()}${command[1]}';

  bool _dottedState({required bool rests}) {
    final TextSelection? selection = _kottaSelection;
    if (selection == null) {
      return rests ? _dottedRests : _dottedNotes;
    }
    String rhythm = _rhythmBefore(selection.start);
    bool found = false;
    for (int index = selection.start; index < selection.end; index++) {
      final String command = _elements[index].command;
      if (_isRhythm(command)) {
        rhythm = command;
      }
      final String? candidate = rests
          ? (command[0].toLowerCase() == 's' ? command : null)
          : (_isPitch(command) ? rhythm : null);
      if (candidate != null && _canDot(candidate)) {
        if (candidate[0] == candidate[0].toLowerCase()) {
          return false;
        }
        found = true;
      }
    }
    return found;
  }

  void _toggleDotted({required bool rests}) {
    final bool dotted = !_dottedState(rests: rests);
    _edit(() {
      if (rests) {
        _dottedRests = dotted;
      } else {
        _dottedNotes = dotted;
      }
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        return;
      }
      final List<KottaEditorElement> updated = <KottaEditorElement>[];
      String originalRhythm = 'r4';
      String outputRhythm = 'r4';
      int start = 0;
      int end = 0;
      for (int index = 0; index < _elements.length; index++) {
        if (index == selection.start) {
          start = updated.length;
        }
        if (index == selection.end) {
          end = updated.length;
        }
        final KottaEditorElement element = _elements[index];
        final bool selected = index >= selection.start && index < selection.end;
        String command = element.command;
        if (_isRhythm(command)) {
          originalRhythm = command;
          if (!rests && selected && _canDot(command)) {
            command = _withDot(command, dotted);
          }
          outputRhythm = command;
        } else if (!rests && _isPitch(command)) {
          final String desired = selected && _canDot(originalRhythm)
              ? _withDot(originalRhythm, dotted)
              : originalRhythm;
          // Rhythm commands persist: isolate both edges of the selection.
          if (outputRhythm != desired) {
            updated.add(
              KottaEditorElement(
                command: desired,
                textOffset: element.textOffset,
                isConditional: element.isConditional,
              ),
            );
            outputRhythm = desired;
          }
        } else if (rests &&
            selected &&
            command[0].toLowerCase() == 's' &&
            _canDot(command)) {
          command = _withDot(command, dotted);
        }
        updated.add(
          command == element.command
              ? element
              : KottaEditorElement(
                  command: command,
                  textOffset: element.textOffset,
                  isConditional: element.isConditional,
                ),
        );
      }
      if (selection.end == _elements.length) {
        end = updated.length;
      }
      _elements = updated;
      final bool forward = selection.baseOffset < selection.extentOffset;
      _kottaSelectionAnchor = forward ? start : end;
      _kottaCursor = forward ? end : start;
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  ButtonStyle _toggleButtonStyle({required bool selected}) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton.styleFrom(
      fixedSize: const Size(56, 56),
      foregroundColor: colors.onSurface,
      side: BorderSide(color: colors.outline),
      backgroundColor: selected ? colors.secondaryContainer : null,
    );
  }

  Widget _dottedButton({required bool rests}) {
    final bool selected = _dottedState(rests: rests);
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: IconButton.outlined(
        tooltip: widget.labels.dotted,
        isSelected: selected,
        onPressed: () => _toggleDotted(rests: rests),
        style: _toggleButtonStyle(selected: selected),
        icon: const Icon(Icons.fiber_manual_record, size: 10),
      ),
    );
  }

  Map<int, List<int>> _selectedNoteModifiers(String prefix) {
    final TextSelection? selection = _kottaSelection;
    final Map<int, List<int>> notes = <int, List<int>>{};
    if (selection == null) {
      return notes;
    }
    final List<int> pending = <int>[];
    for (int index = 0; index < _elements.length; index++) {
      final String command = _elements[index].command;
      if (command[0] == prefix) {
        pending.add(index);
      } else if (_isPitch(command)) {
        if (index >= selection.start && index < selection.end) {
          notes[index] = List<int>.of(pending);
        }
        pending.clear();
      } else if (prefix == 'm' && command[0].toLowerCase() == 's') {
        pending.clear();
      }
    }
    return notes;
  }

  bool _noteModifierState(String command) {
    if (_kottaSelection == null) {
      return _noteModifiers[command[0]] == command;
    }
    final Map<int, List<int>> notes = _selectedNoteModifiers(command[0]);
    return notes.isNotEmpty &&
        notes.values.every(
          (indices) =>
              indices.isNotEmpty && _elements[indices.last].command == command,
        );
  }

  void _toggleNoteModifier(String command) {
    final String prefix = command[0];
    final bool apply = !_noteModifierState(command);
    _edit(() {
      final TextSelection? selection = _kottaSelection;
      if (selection == null) {
        if (apply) {
          _noteModifiers[prefix] = command;
        } else {
          _noteModifiers.remove(prefix);
        }
        return;
      }
      final Map<int, List<int>> notes = _selectedNoteModifiers(prefix);
      final Set<int> removed = notes.values
          .expand((indices) => indices)
          .toSet();
      final List<KottaEditorElement> updated = <KottaEditorElement>[];
      int start = 0;
      int end = 0;
      for (int index = 0; index <= _elements.length; index++) {
        if (index == selection.start) {
          start = updated.length;
        }
        if (index == selection.end) {
          end = updated.length;
        }
        if (index == _elements.length || removed.contains(index)) {
          continue;
        }
        final KottaEditorElement element = _elements[index];
        if (apply && notes.containsKey(index)) {
          updated.add(
            KottaEditorElement(
              command: command,
              textOffset: element.textOffset,
              isConditional: element.isConditional,
            ),
          );
        }
        updated.add(element);
      }
      _elements = updated;
      _noteModifiers.remove(prefix);
      final bool forward = selection.baseOffset < selection.extentOffset;
      _kottaSelectionAnchor = forward ? start : end;
      _kottaCursor = forward ? end : start;
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  void _insertNote(
    String rhythm, {
    required String followingRhythm,
    required bool beaming,
    required Map<_KottaNoteMode, bool> modes,
    required Map<_KottaNoteMode, bool> followingModes,
    required Map<KottaEditorElement, int> groups,
    required Map<KottaEditorElement, _KottaNoteGroup> slurs,
    required String slurDirection,
    required Map<KottaEditorElement, _KottaNoteGroup> tuplets,
    required String tuplet,
  }) {
    final int group =
        groups[_precedingNote(_kottaCursor)] ??
        (groups.values.fold<int>(-1, math.max) + 1);
    final String precedingPitch = _precedingPitch(_kottaCursor);
    final String pitch = _stemDown
        ? precedingPitch.toUpperCase()
        : precedingPitch.toLowerCase();
    _stemDownOverride = null;
    bool restoreRhythm = false;
    if (rhythm != followingRhythm) {
      for (int index = _kottaCursor; index < _elements.length; index++) {
        final String command = _elements[index].command;
        if (_isRhythm(command)) {
          break;
        }
        if (_isPitch(command)) {
          restoreRhythm = true;
          break;
        }
      }
    }
    final List<KottaEditorElement> inserted = <KottaEditorElement>[
      if (_rhythmBefore(_kottaCursor) != rhythm)
        KottaEditorElement(command: rhythm, textOffset: _textCursor),
      for (final _KottaNoteMode mode in _KottaNoteMode.values)
        if (_noteModeBefore(mode, _kottaCursor) != modes[mode])
          KottaEditorElement(
            command: modes[mode]! ? mode.enabled : mode.disabled,
            textOffset: _textCursor,
          ),
      for (final String prefix in <String>['m', 'a'])
        if (_noteModifiers[prefix] case final String command)
          KottaEditorElement(command: command, textOffset: _textCursor),
      KottaEditorElement(command: pitch, textOffset: _textCursor),
    ];
    _noteModifiers.clear();
    _elements.insertAll(_kottaCursor, inserted);
    _kottaCursor += inserted.length;
    for (final _KottaNoteMode mode in _KottaNoteMode.values) {
      if (_kottaCursor < _elements.length &&
          modes[mode] != followingModes[mode]) {
        final KottaEditorElement following = _elements[_kottaCursor];
        _elements.insert(
          _kottaCursor,
          KottaEditorElement(
            command: followingModes[mode]! ? mode.enabled : mode.disabled,
            textOffset: following.textOffset,
            isConditional: following.isConditional,
          ),
        );
      }
    }
    for (int index = _kottaCursor; index < _elements.length; index++) {
      final String command = _elements[index].command;
      if (_isPitch(command)) {
        break;
      }
      if (_isRhythm(command)) {
        if (command == rhythm) {
          _elements.removeAt(index);
          index--;
          continue;
        }
        break;
      }
    }
    if (restoreRhythm) {
      final KottaEditorElement following = _elements[_kottaCursor];
      _elements.insert(
        _kottaCursor,
        KottaEditorElement(
          command: followingRhythm,
          textOffset: following.textOffset,
          isConditional: following.isConditional,
        ),
      );
    }
    if (beaming) {
      groups[inserted.last] = group;
    }
    void extendGroup(
      Map<KottaEditorElement, _KottaNoteGroup> groups,
      String value,
    ) {
      if (value.isEmpty) {
        return;
      }
      final _KottaNoteGroup? preceding =
          groups[_precedingNote(_kottaCursor - inserted.length)];
      groups[inserted.last] = preceding?.value == value
          ? preceding!
          : _KottaNoteGroup(value);
    }

    extendGroup(slurs, slurDirection);
    extendGroup(tuplets, tuplet);
    _normalizeCommands(groups, slurs, tuplets);
    _groupOverrides.clear();
    _beamingOverride = null;
    _noteModeOverrides.clear();
  }

  void _toggleActiveCursor() {
    setState(() {
      _kottaSelectionAnchor = null;
      _textCursorActive = !_textCursorActive;
      _activeCursorVisible = true;
    });
  }

  void _changePitch(int direction) {
    final TextSelection? selection = _kottaSelection;
    int start = selection?.start ?? _kottaCursor;
    final int end = selection?.end ?? _kottaCursor;
    if (selection == null) {
      while (start > 0) {
        start--;
        if (_isVisibleKottaElement(_elements[start].command)) {
          break;
        }
      }
    }
    const String notes = 'gahcdef';
    _edit(() {
      for (int index = start; index < end; index++) {
        final KottaEditorElement element = _elements[index];
        final String command = element.command;
        if (!_isPitch(command)) {
          continue;
        }
        final int pitch =
            (int.parse(command[0]) - 1) * notes.length +
            notes.indexOf(command[1].toLowerCase());
        final int updated = (pitch + direction).clamp(0, 18);
        final String note = notes[updated % notes.length];
        _elements[index] = KottaEditorElement(
          command:
              '${updated ~/ notes.length + 1}'
              '${command == command.toUpperCase() ? note.toUpperCase() : note}',
          textOffset: element.textOffset,
          isConditional: element.isConditional,
        );
      }
      _activeCursorVisible = true;
    });
  }

  void _moveActiveCursor(int direction, {bool extendSelection = false}) {
    setState(() {
      if (_textCursorActive) {
        _kottaSelectionAnchor = null;
        _textCursor = (_textCursor + direction).clamp(
          0,
          widget.initialState.textLength,
        );
        _syncKottaCursorToText();
      } else {
        final TextSelection? selection = _kottaSelection;
        if (extendSelection) {
          _kottaSelectionAnchor ??= _kottaCursor;
          _kottaCursor = _nextKottaCursor(direction);
          _normalizeSelectionBoundaries();
        } else {
          _kottaSelectionAnchor = null;
          _kottaCursor = selection == null
              ? _nextKottaCursor(direction)
              : direction < 0
              ? selection.start
              : selection.end;
        }
        _syncTextCursorToKotta();
      }
      _activeCursorVisible = true;
    });
  }

  void _syncKottaCursorToText() {
    _groupOverrides.clear();
    _stemDownOverride = null;
    _noteModeOverrides.clear();
    _beamingOverride = null;
    _kottaCursor = _elements.indexWhere(
      (element) => element.textOffset > _textCursor,
    );
    if (_kottaCursor < 0) {
      _kottaCursor = _elements.length;
    }
  }

  void _syncTextCursorToKotta() {
    _groupOverrides.clear();
    _stemDownOverride = null;
    _noteModeOverrides.clear();
    _beamingOverride = null;
    if (_elements.isNotEmpty) {
      _textCursor = _kottaCursor < _elements.length
          ? _elements[_kottaCursor].textOffset
          : _elements.last.textOffset;
    }
  }

  void _placeCursor(({int position, bool textActive}) hit) {
    setState(() {
      _kottaSelectionAnchor = null;
      _textCursorActive = hit.textActive;
      if (_textCursorActive) {
        _textCursor = hit.position.clamp(0, widget.initialState.textLength);
        _syncKottaCursorToText();
      } else {
        _kottaCursor = hit.position.clamp(0, _elements.length);
        _syncTextCursorToKotta();
      }
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  void _selectKotta(TextSelection selection) {
    setState(() {
      _kottaSelectionAnchor = selection.baseOffset.clamp(0, _elements.length);
      _kottaCursor = selection.extentOffset.clamp(0, _elements.length);
      _normalizeSelectionBoundaries();
      _textCursorActive = false;
      _syncTextCursorToKotta();
      _activeCursorVisible = true;
    });
    _editorFocusNode.requestFocus();
  }

  int _nextKottaCursor(int direction) {
    if (direction > 0) {
      for (int index = _kottaCursor; index < _elements.length; index++) {
        if (_isVisibleKottaElement(_elements[index].command)) {
          return index + 1;
        }
      }
      return _kottaCursor;
    }
    for (
      int index = math.min(_kottaCursor - 1, _elements.length - 1);
      index >= 0;
      index--
    ) {
      final int candidate = index + 1;
      if (candidate < _kottaCursor &&
          _isVisibleKottaElement(_elements[index].command)) {
        return candidate;
      }
    }
    return 0;
  }

  bool _isVisibleKottaElement(String command) {
    if (command.length != 2) {
      return false;
    }
    return !<String>{
      'r',
      'R',
      '-',
      'm',
      'a',
      '[',
      ']',
      '(',
      ')',
    }.contains(command[0]);
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ ||
          event.logicalKey == LogicalKeyboardKey.keyY) {
        if (event.logicalKey == LogicalKeyboardKey.keyY ||
            HardwareKeyboard.instance.isShiftPressed) {
          _redo();
        } else {
          _undo();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX ||
          event.logicalKey == LogicalKeyboardKey.keyC ||
          event.logicalKey == LogicalKeyboardKey.keyV) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyV) {
            unawaited(_paste());
          } else {
            unawaited(
              _copySelection(cut: event.logicalKey == LogicalKeyboardKey.keyX),
            );
          }
        }
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _toggleActiveCursor();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveActiveCursor(
        -1,
        extendSelection: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveActiveCursor(
        1,
        extendSelection: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _changePitch(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _changePitch(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final KottaEditorLabels labels = widget.labels;
    final double contentHeight = math.min(
      650,
      MediaQuery.sizeOf(context).height * 0.7,
    );
    return Focus(
      focusNode: _editorFocusNode,
      autofocus: true,
      child: AlertDialog(
        title: Text(
          !widget.initialState.isEditing
              ? labels.insertTitle
              : labels.editTitle,
        ),
        content: SizedBox(
          width: 720,
          height: contentHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _KottaPreview(
                line: widget.previewLineBuilder(_elements),
                onCursorPlaced: _placeCursor,
                onSelectionChanged: _selectKotta,
                cursorOverlay: ProjectorEditorCursorOverlay(
                  kottaPosition: _kottaCursor,
                  textPosition: _textCursor,
                  textActive: _textCursorActive,
                  activeVisible: _activeCursorVisible,
                  kottaSelection: _kottaSelection,
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: labels.cut,
                    visualDensity: VisualDensity.compact,
                    onPressed: _kottaSelection == null
                        ? null
                        : () => _copySelection(cut: true),
                    icon: const Icon(Icons.content_cut, size: 18),
                  ),
                  IconButton(
                    tooltip: labels.copy,
                    visualDensity: VisualDensity.compact,
                    onPressed: _kottaSelection == null ? null : _copySelection,
                    icon: const Icon(Icons.content_copy, size: 18),
                  ),
                  IconButton(
                    tooltip: labels.paste,
                    visualDensity: VisualDensity.compact,
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste, size: 18),
                  ),
                  IconButton(
                    tooltip: labels.undo,
                    visualDensity: VisualDensity.compact,
                    onPressed: _undoStack.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo, size: 18),
                  ),
                  IconButton(
                    tooltip: labels.redo,
                    visualDensity: VisualDensity.compact,
                    onPressed: _redoStack.isEmpty ? null : _redo,
                    icon: const Icon(Icons.redo, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CommandSection(
                        label: labels.clef,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(labels.gClef, 'kG'),
                          _KottaEditorCommand(labels.fClef, 'kF'),
                          _KottaEditorCommand(labels.sopranoClef, 'k1'),
                          _KottaEditorCommand(labels.mezzoSopranoClef, 'k2'),
                          _KottaEditorCommand(labels.altoClef, 'k3'),
                          _KottaEditorCommand(labels.tenorClef, 'k4'),
                          _KottaEditorCommand(labels.baritoneClef, 'k5'),
                          for (int index = 0; index < 9; index++)
                            _KottaEditorCommand(
                              index.isEven
                                  ? labels.doClefLine(index ~/ 2 + 1)
                                  : labels.doClefSpace(
                                      index ~/ 2 + 1,
                                      index ~/ 2 + 2,
                                    ),
                              'k${String.fromCharCode(97 + index)}',
                            ),
                        ],
                        graphicalClefs: true,
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.keySignature,
                        commands: <_KottaEditorCommand>[
                          for (int index = 1; index <= 7; index++)
                            _KottaEditorCommand(
                              labels.flats(index),
                              'e$index',
                              hint: labels.flatKeys[index - 1],
                            ),
                          for (int index = 1; index <= 7; index++)
                            _KottaEditorCommand(
                              labels.sharps(index),
                              'E$index',
                              hint: labels.sharpKeys[index - 1],
                            ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.barlines,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.singleBarline,
                            '|1',
                            asset: 'utemjel',
                          ),
                          _KottaEditorCommand(
                            labels.doubleBarline,
                            '||',
                            asset: 'utemjel2',
                          ),
                          _KottaEditorCommand(
                            labels.finalBarline,
                            '|.',
                            asset: 'utemjelveg',
                          ),
                          _KottaEditorCommand(
                            labels.shortCaesura,
                            "|'",
                            asset: 'cezura1',
                          ),
                          _KottaEditorCommand(
                            labels.longCaesura,
                            '|!',
                            asset: 'cezura2',
                          ),
                          _KottaEditorCommand(
                            labels.openingRepeat,
                            '|>',
                            asset: 'ismjel2',
                          ),
                          _KottaEditorCommand(
                            labels.bidirectionalRepeat,
                            '|:',
                            asset: 'ismjel3',
                          ),
                          _KottaEditorCommand(
                            labels.closingRepeat,
                            '|<',
                            asset: 'ismjel1',
                          ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.meters,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.meter44,
                            'u4',
                            meter: labels.meterSymbol(4, 4),
                          ),
                          _KottaEditorCommand(
                            labels.meter24,
                            'u2',
                            meter: labels.meterSymbol(2, 4),
                          ),
                          _KottaEditorCommand(
                            labels.meter34,
                            'u3',
                            meter: labels.meterSymbol(3, 4),
                          ),
                          _KottaEditorCommand(
                            labels.meter38,
                            'U8',
                            meter: labels.meterSymbol(3, 8),
                          ),
                          _KottaEditorCommand(
                            labels.meter68,
                            'U6',
                            meter: labels.meterSymbol(6, 8),
                          ),
                          _KottaEditorCommand(
                            labels.meter22,
                            'U2',
                            meter: labels.meterSymbol(2, 2),
                          ),
                          _KottaEditorCommand(
                            labels.meter32,
                            'U3',
                            meter: labels.meterSymbol(3, 2),
                          ),
                          _KottaEditorCommand(
                            labels.meter54,
                            'u5',
                            meter: labels.meterSymbol(5, 4),
                          ),
                          _KottaEditorCommand(
                            labels.meter64,
                            'u6',
                            meter: labels.meterSymbol(6, 4),
                          ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.rests,
                        trailing: _dottedButton(rests: true),
                        assetSize: 24,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.wholeRest,
                            's1',
                            asset: 'szunet1',
                          ),
                          _KottaEditorCommand(
                            labels.halfRest,
                            's2',
                            asset: 'szunet2',
                          ),
                          _KottaEditorCommand(
                            labels.quarterRest,
                            's4',
                            asset: 'szunet4',
                          ),
                          _KottaEditorCommand(
                            labels.eighthRest,
                            's8',
                            asset: 'szunet8',
                          ),
                          _KottaEditorCommand(
                            labels.sixteenthRest,
                            's6',
                            asset: 'szunet16',
                          ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.notes,
                        trailing: _dottedButton(rests: false),
                        assetSize: 24,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.longa,
                            'rl',
                            asset: 'editor_hang0',
                          ),
                          _KottaEditorCommand(
                            labels.brevis,
                            'rb',
                            asset: 'editor_hangbrevis1',
                          ),
                          _KottaEditorCommand(
                            labels.semibrevis,
                            'rs',
                            asset: 'editor_hangbrevis2',
                          ),
                          _KottaEditorCommand(
                            labels.wholeNote,
                            'r1',
                            asset: 'editor_hang1',
                          ),
                          _KottaEditorCommand(
                            labels.halfNote,
                            'r2',
                            asset: 'editor_hang2',
                          ),
                          _KottaEditorCommand(
                            labels.quarterNote,
                            'r4',
                            asset: 'editor_hang4',
                          ),
                          _KottaEditorCommand(
                            labels.eighthNote,
                            'r8',
                            asset: 'editor_hang8',
                          ),
                          _KottaEditorCommand(
                            labels.sixteenthNote,
                            'r6',
                            asset: 'editor_hang16',
                          ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.noteProperties,
                        commands: const <_KottaEditorCommand>[],
                        onPressed: _insertCommand,
                        trailing: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: <Widget>[
                            IconButton.outlined(
                              tooltip: labels.stemDown,
                              isSelected: _stemDown,
                              onPressed: _toggleStemDirection,
                              style: _toggleButtonStyle(selected: _stemDown),
                              icon: CustomPaint(
                                size: const Size(24, 24),
                                painter: _StemDirectionPainter(
                                  down: _stemDown,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: labels.beaming,
                              isSelected: _beaming,
                              onPressed: _toggleBeaming,
                              style: _toggleButtonStyle(selected: _beaming),
                              icon: CustomPaint(
                                size: const Size(24, 24),
                                painter: _BeamingPainter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: labels.stemless,
                              isSelected: _stemless,
                              onPressed: () =>
                                  _toggleNoteMode(_KottaNoteMode.stemless),
                              style: _toggleButtonStyle(selected: _stemless),
                              icon: CustomPaint(
                                size: const Size(24, 24),
                                painter: _StemlessPainter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: labels.compact,
                              isSelected: _compact,
                              onPressed: () =>
                                  _toggleNoteMode(_KottaNoteMode.compact),
                              style: _toggleButtonStyle(selected: _compact),
                              icon: CustomPaint(
                                size: const Size(24, 24),
                                painter: _CompactPainter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            for (final String direction in <String>['a', 'f'])
                              IconButton.outlined(
                                tooltip: direction == 'a'
                                    ? labels.lowerSlur
                                    : labels.upperSlur,
                                isSelected: _slurDirection == direction,
                                onPressed: () => _toggleGroup(
                                  _KottaGroupKind.slur,
                                  direction,
                                ),
                                style: _toggleButtonStyle(
                                  selected: _slurDirection == direction,
                                ),
                                icon: CustomPaint(
                                  size: const Size(24, 24),
                                  painter: _SlurPainter(
                                    down: direction == 'a',
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            for (final String count in <String>['3', '5'])
                              IconButton.outlined(
                                tooltip: count == '3'
                                    ? labels.triplet
                                    : labels.quintuplet,
                                isSelected: _tuplet == count,
                                onPressed: () =>
                                    _toggleGroup(_KottaGroupKind.tuplet, count),
                                style: _toggleButtonStyle(
                                  selected: _tuplet == count,
                                ),
                                icon: CustomPaint(
                                  size: const Size(24, 24),
                                  painter: _TupletPainter(
                                    count: count,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _CommandSection(
                        label: labels.accidentals,
                        assetSize: 24,
                        isSelected: _noteModifierState,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(labels.flat, 'mb', asset: 'be'),
                          _KottaEditorCommand(
                            labels.natural,
                            'm0',
                            asset: 'feloldo',
                          ),
                          _KottaEditorCommand(
                            labels.sharp,
                            'mk',
                            asset: 'kereszt',
                          ),
                          _KottaEditorCommand(
                            labels.doubleFlat,
                            'mB',
                            asset: 'bebe',
                          ),
                          _KottaEditorCommand(
                            labels.doubleSharp,
                            'mK',
                            asset: 'kettoskereszt',
                            assetSize: 12,
                          ),
                        ],
                        onPressed: _toggleNoteModifier,
                      ),
                      _CommandSection(
                        label: labels.agogics,
                        assetSize: 16.8,
                        isSelected: _noteModifierState,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.tenuto,
                            'a-',
                            asset: 'tenuto',
                          ),
                          _KottaEditorCommand(
                            labels.staccato,
                            'a.',
                            asset: 'pont',
                            assetSize: 5.6,
                          ),
                          _KottaEditorCommand(
                            labels.marcato,
                            'a>',
                            asset: 'marcato1',
                          ),
                          _KottaEditorCommand(
                            labels.martellato,
                            'a^',
                            asset: 'marcato2',
                          ),
                          _KottaEditorCommand(
                            labels.fermata,
                            'aK',
                            asset: 'koronale',
                          ),
                          _KottaEditorCommand(
                            labels.trill,
                            'at',
                            asset: 'trilla1',
                          ),
                          _KottaEditorCommand(
                            labels.lowerTrill,
                            'aT',
                            asset: 'trilla2',
                          ),
                          _KottaEditorCommand(
                            labels.mordent,
                            'am',
                            asset: 'mordent1',
                          ),
                          _KottaEditorCommand(
                            labels.lowerMordent,
                            'aM',
                            asset: 'mordent2',
                          ),
                        ],
                        onPressed: _toggleNoteModifier,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(labels.cancel),
          ),
          FilledButton(
            onPressed: _isValid
                ? () {
                    _normalizeCommands();
                    Navigator.of(context).pop(
                      KottaEditorResult(
                        elements: List<KottaEditorElement>.unmodifiable(
                          _elements,
                        ),
                      ),
                    );
                  }
                : null,
            child: Text(labels.apply),
          ),
        ],
      ),
    );
  }
}

class _KottaPreview extends StatefulWidget {
  const _KottaPreview({
    required this.line,
    required this.cursorOverlay,
    required this.onCursorPlaced,
    required this.onSelectionChanged,
  });

  final String line;
  final ProjectorEditorCursorOverlay cursorOverlay;
  final ValueChanged<({int position, bool textActive})> onCursorPlaced;
  final ValueChanged<TextSelection> onSelectionChanged;

  @override
  State<_KottaPreview> createState() => _KottaPreviewState();
}

class _KottaPreviewState extends State<_KottaPreview> {
  final ScrollController _horizontalScrollController = ScrollController();
  final GlobalKey _previewKey = GlobalKey();
  int? _dragAnchor;
  Rect? _pendingCursorRect;
  ProjectorEditorCursorLayout? _cursorLayout;
  bool _cursorScrollScheduled = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleEditorCursorLayout(ProjectorEditorCursorLayout layout) {
    _cursorLayout = layout;
    final Rect cursorRect = widget.cursorOverlay.textActive
        ? layout.textRect
        : layout.kottaRect;
    if (_pendingCursorRect == cursorRect) {
      return;
    }
    _pendingCursorRect = cursorRect;
    if (_cursorScrollScheduled) {
      return;
    }
    _cursorScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cursorScrollScheduled = false;
      if (!mounted || !_horizontalScrollController.hasClients) {
        return;
      }
      final Rect? cursorRect = _pendingCursorRect;
      if (cursorRect == null) {
        return;
      }
      const double margin = 24;
      final ScrollPosition position = _horizontalScrollController.position;
      final double left = position.pixels + margin;
      final double right =
          position.pixels + position.viewportDimension - margin;
      double target = position.pixels;
      if (cursorRect.left < left) {
        target = cursorRect.left - margin;
      } else if (cursorRect.right > right) {
        target = cursorRect.right - position.viewportDimension + margin;
      }
      target = target.clamp(0, position.maxScrollExtent);
      if (target != position.pixels) {
        _horizontalScrollController.jumpTo(target);
      }
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final ProjectorEditorCursorLayout? layout = _cursorLayout;
    if (layout == null) {
      return;
    }
    final hit = layout.hitTest(event.localPosition);
    _dragAnchor = hit.textActive ? null : hit.position;
    widget.onCursorPlaced(hit);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final int? anchor = _dragAnchor;
    final ProjectorEditorCursorLayout? layout = _cursorLayout;
    if (anchor == null ||
        layout == null ||
        event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final RenderBox box =
        _previewKey.currentContext!.findRenderObject()! as RenderBox;
    final hit = layout.hitTest(
      box.globalToLocal(event.position),
      textActive: false,
    );
    widget.onSelectionChanged(
      TextSelection(baseOffset: anchor, extentOffset: hit.position),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProjectorPainter painter = ProjectorPainter(
      frame: TextFrame(
        record: RecTextRecord(
          scholaLine: '',
          title: '',
          lines: <String>[widget.line.isEmpty ? '\u00A0' : widget.line],
        ),
      ),
      globals: const ProjectionGlobals(
        fontSize: 34,
        autoResize: false,
        hCenter: false,
        vCenter: true,
        hideTitle: true,
        useAkkord: false,
        useKotta: true,
      ),
      settings: const AppSettings(receiverUseKotta: true),
      allowLineWrapping: false,
      editorCursorOverlay: widget.cursorOverlay,
      onEditorCursorLayout: _handleEditorCursorLayout,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 180,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double contentWidth = math.max(
              constraints.maxWidth,
              painter.measureRequiredWidth() + 16,
            );
            return Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: contentWidth,
                  height: constraints.maxHeight,
                  child: Listener(
                    key: _previewKey,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: (_) => _dragAnchor = null,
                    onPointerCancel: (_) => _dragAnchor = null,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (TapUpDetails details) {
                        if (details.kind == PointerDeviceKind.mouse) {
                          return;
                        }
                        final ProjectorEditorCursorLayout? layout =
                            _cursorLayout;
                        if (layout != null) {
                          widget.onCursorPlaced(
                            layout.hitTest(details.localPosition),
                          );
                        }
                      },
                      child: CustomPaint(painter: painter),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TupletPainter extends CustomPainter {
  const _TupletPainter({required this.count, required this.color});

  final String count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(1, 21)
        ..lineTo(1, 16)
        ..lineTo(23, 16)
        ..lineTo(23, 21),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: count,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset((24 - text.width) / 2, 0));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TupletPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.color != color;
}

class _SlurPainter extends CustomPainter {
  const _SlurPainter({required this.down, required this.color});

  final bool down;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final double edge = down ? 8 : 16;
    final double apex = down ? 19 : 5;
    canvas.drawPath(
      Path()
        ..moveTo(1, edge)
        ..cubicTo(5, apex, 19, apex, 23, edge)
        ..cubicTo(
          18,
          apex + (down ? -4 : 4),
          6,
          apex + (down ? -4 : 4),
          1,
          edge,
        )
        ..close(),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlurPainter oldDelegate) =>
      oldDelegate.down != down || oldDelegate.color != color;
}

class _CompactPainter extends CustomPainter {
  const _CompactPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final Paint paint = Paint()..color = color;
    for (final double x in <double>[4, 11, 18]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 19), width: 7, height: 5),
        paint,
      );
      canvas.drawRect(Rect.fromLTWH(x + 2, 2, 1.5, 17), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompactPainter oldDelegate) => oldDelegate.color != color;
}

class _StemlessPainter extends CustomPainter {
  const _StemlessPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final Paint paint = Paint()..color = color;
    for (final Offset center in const <Offset>[
      Offset(4, 15),
      Offset(12, 9),
      Offset(20, 12),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 4, center.dy)
          ..lineTo(center.dx, center.dy - 3)
          ..lineTo(center.dx + 4, center.dy)
          ..lineTo(center.dx, center.dy + 3)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StemlessPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BeamingPainter extends CustomPainter {
  const _BeamingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final Paint paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(3, 8)
        ..lineTo(21, 3)
        ..lineTo(21, 7)
        ..lineTo(3, 12)
        ..close(),
      paint,
    );
    paint.strokeWidth = 2;
    for (int index = 0; index < 4; index++) {
      final double x = 3 + index * 6;
      final double y = 10 - index * 5 / 3;
      canvas.drawLine(Offset(x, y), Offset(x, y + 11), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeamingPainter oldDelegate) => color != oldDelegate.color;
}

class _StemDirectionPainter extends CustomPainter {
  const _StemDirectionPainter({required this.down, required this.color});

  final bool down;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    if (down) {
      canvas.translate(24, 24);
      canvas.rotate(math.pi);
    }
    final Paint paint = Paint()..color = color;
    canvas.drawOval(const Rect.fromLTWH(5, 16, 12, 7), paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(16, 19), const Offset(16, 2), paint);
    canvas.drawPath(
      Path()
        ..moveTo(12, 6)
        ..lineTo(16, 2)
        ..lineTo(20, 6),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StemDirectionPainter oldDelegate) =>
      down != oldDelegate.down || color != oldDelegate.color;
}

class _KottaEditorCommand {
  const _KottaEditorCommand(
    this.label,
    this.source, {
    this.hint,
    this.asset,
    this.assetSize,
    this.meter,
  });

  final String label;
  final String source;
  final String? hint;
  final String? asset;
  final double? assetSize;
  final String? meter;
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.label,
    required this.commands,
    required this.onPressed,
    this.graphicalClefs = false,
    this.assetSize = 48,
    this.trailing,
    this.isSelected,
  });

  final String label;
  final List<_KottaEditorCommand> commands;
  final ValueChanged<String> onPressed;
  final bool graphicalClefs;
  final double assetSize;
  final Widget? trailing;
  final bool Function(String command)? isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              ...commands.map(
                (_KottaEditorCommand command) =>
                    graphicalClefs ||
                        command.asset != null ||
                        command.meter != null
                    ? Tooltip(
                        message: command.label,
                        child: OutlinedButton(
                          onPressed: () => onPressed(command.source),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: Size.zero,
                            backgroundColor:
                                isSelected?.call(command.source) == true
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : null,
                          ),
                          child: Semantics(
                            label: command.label,
                            toggled: isSelected?.call(command.source),
                            child: command.meter != null
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        command.meter!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 20,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  )
                                : command.asset != null
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: Image.asset(
                                        'assets/kotta/${command.asset}.png',
                                        width: command.assetSize ?? assetSize,
                                        height: command.assetSize ?? assetSize,
                                        filterQuality: FilterQuality.none,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        colorBlendMode: BlendMode.srcIn,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  )
                                : CustomPaint(
                                    size: const Size(48, 48),
                                    painter: KottaClefPainter(
                                      command: command.source,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                          ),
                        ),
                      )
                    : command.hint != null
                    ? Tooltip(
                        message: command.hint!,
                        child: OutlinedButton(
                          onPressed: () => onPressed(command.source),
                          child: Text(command.label),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: () => onPressed(command.source),
                        child: Text(command.label),
                      ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}
