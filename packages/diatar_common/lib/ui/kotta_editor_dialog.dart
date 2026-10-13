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

class _KottaEditorDialogState extends State<_KottaEditorDialog> {
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'kotta-editor');
  late List<KottaEditorElement> _elements;
  late int _kottaCursor;
  late int _textCursor;
  int? _kottaSelectionAnchor;
  late final Timer _caretTimer;
  bool _textCursorActive = false;
  bool _activeCursorVisible = true;

  bool get _isValid => _elements.isNotEmpty;

  TextSelection? get _kottaSelection {
    final int? anchor = _kottaSelectionAnchor;
    if (anchor == null || anchor == _kottaCursor) {
      return null;
    }
    return TextSelection(baseOffset: anchor, extentOffset: _kottaCursor);
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
    setState(() {
      final TextSelection? selection = _kottaSelection;
      if (selection != null) {
        _kottaCursor = selection.start;
        _textCursor = _elements[selection.start].textOffset;
        _elements.removeRange(selection.start, selection.end);
      }
      _kottaSelectionAnchor = null;
      _elements.insert(
        _kottaCursor,
        KottaEditorElement(command: command, textOffset: _textCursor),
      );
      _kottaCursor++;
      _textCursorActive = false;
      _activeCursorVisible = true;
    });
  }

  void _toggleActiveCursor() {
    setState(() {
      _kottaSelectionAnchor = null;
      _textCursorActive = !_textCursorActive;
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
    _kottaCursor = _elements.indexWhere(
      (element) => element.textOffset > _textCursor,
    );
    if (_kottaCursor < 0) {
      _kottaCursor = _elements.length;
    }
  }

  void _syncTextCursorToKotta() {
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

class _KottaEditorCommand {
  const _KottaEditorCommand(
    this.label,
    this.source, {
    this.hint,
    this.asset,
    this.meter,
  });

  final String label;
  final String source;
  final String? hint;
  final String? asset;
  final String? meter;
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.label,
    required this.commands,
    required this.onPressed,
    this.graphicalClefs = false,
  });

  final String label;
  final List<_KottaEditorCommand> commands;
  final ValueChanged<String> onPressed;
  final bool graphicalClefs;

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
                            ),
                            child: Semantics(
                              label: command.label,
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
                                  ? Image.asset(
                                      'assets/kotta/${command.asset}.png',
                                      width: 48,
                                      height: 48,
                                      filterQuality: FilterQuality.none,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      colorBlendMode: BlendMode.srcIn,
                                      excludeFromSemantics: true,
                                    )
                                  : CustomPaint(
                                      size: const Size(48, 88),
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
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
