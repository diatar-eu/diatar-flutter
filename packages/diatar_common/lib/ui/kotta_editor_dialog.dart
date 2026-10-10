import 'dart:async';
import 'dart:math' as math;

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
    required this.clef,
    required this.keySignature,
    required this.rhythm,
    required this.notes,
    required this.rests,
    required this.accidentals,
    required this.barlines,
    required this.gClef,
    required this.fClef,
    required this.noKeySignature,
    required this.flats,
    required this.sharps,
    required this.whole,
    required this.half,
    required this.quarter,
    required this.eighth,
    required this.sixteenth,
    required this.dotted,
    required this.natural,
    required this.flat,
    required this.sharp,
    required this.doubleFlat,
    required this.doubleSharp,
    required this.cancel,
    required this.apply,
  });

  final String insertTitle;
  final String editTitle;
  final String clef;
  final String keySignature;
  final String rhythm;
  final String notes;
  final String rests;
  final String accidentals;
  final String barlines;
  final String gClef;
  final String fClef;
  final String noKeySignature;
  final String flats;
  final String sharps;
  final String whole;
  final String half;
  final String quarter;
  final String eighth;
  final String sixteenth;
  final String dotted;
  final String natural;
  final String flat;
  final String sharp;
  final String doubleFlat;
  final String doubleSharp;
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

class _KottaEditorDialogState extends State<_KottaEditorDialog> {
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'kotta-editor');
  late List<KottaEditorElement> _elements;
  late int _kottaCursor;
  late int _textCursor;
  late final Timer _caretTimer;
  bool _textCursorActive = false;
  bool _activeCursorVisible = true;
  bool _dotted = false;

  bool get _isValid => _elements.isNotEmpty;

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
    setState(() {
      _elements.insert(
        _kottaCursor,
        KottaEditorElement(command: command, textOffset: _textCursor),
      );
      _kottaCursor++;
      _textCursorActive = false;
      _activeCursorVisible = true;
    });
  }

  String _rhythmCommand(String value) => '${_dotted ? 'R' : 'r'}$value';

  void _toggleActiveCursor() {
    setState(() {
      _textCursorActive = !_textCursorActive;
      _activeCursorVisible = true;
    });
  }

  void _moveActiveCursor(int direction) {
    setState(() {
      if (_textCursorActive) {
        _textCursor = (_textCursor + direction).clamp(
          0,
          widget.initialState.textLength,
        );
        _kottaCursor = _elements.indexWhere(
          (element) => element.textOffset > _textCursor,
        );
        if (_kottaCursor < 0) {
          _kottaCursor = _elements.length;
        }
      } else {
        _kottaCursor = _nextKottaCursor(direction);
        if (_elements.isNotEmpty) {
          _textCursor = _kottaCursor < _elements.length
              ? _elements[_kottaCursor].textOffset
              : _elements.last.textOffset;
        }
      }
      _activeCursorVisible = true;
    });
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
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _toggleActiveCursor();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _moveActiveCursor(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _moveActiveCursor(1);
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
                cursorOverlay: ProjectorEditorCursorOverlay(
                  kottaPosition: _kottaCursor,
                  textPosition: _textCursor,
                  textActive: _textCursorActive,
                  activeVisible: _activeCursorVisible,
                ),
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
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.keySignature,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(labels.noKeySignature, 'E0'),
                          for (int index = 1; index <= 7; index++)
                            _KottaEditorCommand(
                              '${labels.flats} $index',
                              'e$index',
                            ),
                          for (int index = 1; index <= 7; index++)
                            _KottaEditorCommand(
                              '${labels.sharps} $index',
                              'E$index',
                            ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(labels.dotted),
                        value: _dotted,
                        onChanged: (bool value) =>
                            setState(() => _dotted = value),
                      ),
                      _CommandSection(
                        label: labels.rhythm,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(
                            labels.whole,
                            _rhythmCommand('1'),
                          ),
                          _KottaEditorCommand(labels.half, _rhythmCommand('2')),
                          _KottaEditorCommand(
                            labels.quarter,
                            _rhythmCommand('4'),
                          ),
                          _KottaEditorCommand(
                            labels.eighth,
                            _rhythmCommand('8'),
                          ),
                          _KottaEditorCommand(
                            labels.sixteenth,
                            _rhythmCommand('6'),
                          ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.notes,
                        commands: <_KottaEditorCommand>[
                          for (final String octave in <String>['1', '2', '3'])
                            for (final String position in 'abcdefghi'.split(''))
                              _KottaEditorCommand(
                                '$octave$position',
                                '$octave$position',
                              ),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.rests,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(labels.whole, 's1'),
                          _KottaEditorCommand(labels.half, 's2'),
                          _KottaEditorCommand(labels.quarter, 's4'),
                          _KottaEditorCommand(labels.eighth, 's8'),
                          _KottaEditorCommand(labels.sixteenth, 's6'),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.accidentals,
                        commands: <_KottaEditorCommand>[
                          _KottaEditorCommand(labels.natural, 'm0'),
                          _KottaEditorCommand(labels.flat, 'mb'),
                          _KottaEditorCommand(labels.sharp, 'mk'),
                          _KottaEditorCommand(labels.doubleFlat, 'mB'),
                          _KottaEditorCommand(labels.doubleSharp, 'mK'),
                        ],
                        onPressed: _insertCommand,
                      ),
                      _CommandSection(
                        label: labels.barlines,
                        commands: const <_KottaEditorCommand>[
                          _KottaEditorCommand('|', '|!'),
                          _KottaEditorCommand('||', '||'),
                          _KottaEditorCommand('|:', '|:'),
                          _KottaEditorCommand(':|', '|<'),
                        ],
                        onPressed: _insertCommand,
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
                ? () => Navigator.of(context).pop(
                    KottaEditorResult(
                      elements: List<KottaEditorElement>.unmodifiable(
                        _elements,
                      ),
                    ),
                  )
                : null,
            child: Text(labels.apply),
          ),
        ],
      ),
    );
  }
}

class _KottaPreview extends StatefulWidget {
  const _KottaPreview({required this.line, required this.cursorOverlay});

  final String line;
  final ProjectorEditorCursorOverlay cursorOverlay;

  @override
  State<_KottaPreview> createState() => _KottaPreviewState();
}

class _KottaPreviewState extends State<_KottaPreview> {
  final ScrollController _horizontalScrollController = ScrollController();
  Rect? _pendingCursorRect;
  bool _cursorScrollScheduled = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleEditorCursorLayout(ProjectorEditorCursorLayout layout) {
    _pendingCursorRect = widget.cursorOverlay.textActive
        ? layout.textRect
        : layout.kottaRect;
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
                  child: CustomPaint(painter: painter),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KottaEditorCommand {
  const _KottaEditorCommand(this.label, this.source);

  final String label;
  final String source;
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.label,
    required this.commands,
    required this.onPressed,
  });

  final String label;
  final List<_KottaEditorCommand> commands;
  final ValueChanged<String> onPressed;

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
            children: commands
                .map(
                  (_KottaEditorCommand command) => OutlinedButton(
                    onPressed: () => onPressed(command.source),
                    child: Text(command.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
