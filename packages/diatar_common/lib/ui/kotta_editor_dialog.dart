import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/projection_frame.dart';
import '../models/projection_globals.dart';
import '../models/records.dart';
import 'projector_painter.dart';

class KottaEditorLabels {
  const KottaEditorLabels({
    required this.insertTitle,
    required this.editTitle,
    required this.source,
    required this.sourceHint,
    required this.invalidSource,
    required this.preview,
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
  final String source;
  final String sourceHint;
  final String invalidSource;
  final String preview;
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

Future<String?> showKottaEditorDialog({
  required BuildContext context,
  required KottaEditorLabels labels,
  required String followingText,
  String? initialSource,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _KottaEditorDialog(
      labels: labels,
      followingText: followingText,
      initialSource: initialSource,
    ),
  );
}

class _KottaEditorDialog extends StatefulWidget {
  const _KottaEditorDialog({
    required this.labels,
    required this.followingText,
    this.initialSource,
  });

  final KottaEditorLabels labels;
  final String followingText;
  final String? initialSource;

  @override
  State<_KottaEditorDialog> createState() => _KottaEditorDialogState();
}

class _KottaEditorDialogState extends State<_KottaEditorDialog> {
  late final TextEditingController _sourceController;
  late final FocusNode _sourceFocusNode;
  bool _dotted = false;

  bool get _isValid =>
      _sourceController.text.isNotEmpty && _sourceController.text.length.isEven;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(text: widget.initialSource ?? '')
      ..addListener(_sourceChanged);
    _sourceFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _sourceController
      ..removeListener(_sourceChanged)
      ..dispose();
    _sourceFocusNode.dispose();
    super.dispose();
  }

  void _sourceChanged() => setState(() {});

  void _insertCommand(String command) {
    assert(command.length == 2);
    final TextSelection selection = _sourceController.selection.isValid
        ? _sourceController.selection
        : TextSelection.collapsed(offset: _sourceController.text.length);
    final String text = _sourceController.text.replaceRange(
      selection.start,
      selection.end,
      command,
    );
    _sourceController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + command.length,
      ),
    );
    _sourceFocusNode.requestFocus();
  }

  String _rhythmCommand(String value) => '${_dotted ? 'R' : 'r'}$value';

  @override
  Widget build(BuildContext context) {
    final KottaEditorLabels labels = widget.labels;
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.initialSource == null ? labels.insertTitle : labels.editTitle,
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(labels.preview, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              _KottaPreview(
                source: _sourceController.text,
                followingText: widget.followingText,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sourceController,
                focusNode: _sourceFocusNode,
                decoration: InputDecoration(
                  labelText: labels.source,
                  helperText: labels.sourceHint,
                  errorText: _sourceController.text.isNotEmpty && !_isValid
                      ? labels.invalidSource
                      : null,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[\\;\r\n]'),
                    replacementString: '',
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    _KottaEditorCommand('${labels.flats} $index', 'e$index'),
                  for (int index = 1; index <= 7; index++)
                    _KottaEditorCommand('${labels.sharps} $index', 'E$index'),
                ],
                onPressed: _insertCommand,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labels.dotted),
                value: _dotted,
                onChanged: (bool value) => setState(() => _dotted = value),
              ),
              _CommandSection(
                label: labels.rhythm,
                commands: <_KottaEditorCommand>[
                  _KottaEditorCommand(labels.whole, _rhythmCommand('1')),
                  _KottaEditorCommand(labels.half, _rhythmCommand('2')),
                  _KottaEditorCommand(labels.quarter, _rhythmCommand('4')),
                  _KottaEditorCommand(labels.eighth, _rhythmCommand('8')),
                  _KottaEditorCommand(labels.sixteenth, _rhythmCommand('6')),
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
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.cancel),
        ),
        FilledButton(
          onPressed: _isValid
              ? () => Navigator.of(context).pop(_sourceController.text)
              : null,
          child: Text(labels.apply),
        ),
      ],
    );
  }
}

class _KottaPreview extends StatelessWidget {
  const _KottaPreview({required this.source, required this.followingText});

  final String source;
  final String followingText;

  @override
  Widget build(BuildContext context) {
    final String lyric = followingText.trim().isEmpty
        ? '\u00A0'
        : followingText;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          painter: ProjectorPainter(
            frame: TextFrame(
              record: RecTextRecord(
                scholaLine: '',
                title: '',
                lines: <String>['\\K$source;$lyric'],
              ),
            ),
            globals: const ProjectionGlobals(
              fontSize: 34,
              autoResize: true,
              hCenter: true,
              vCenter: true,
              hideTitle: true,
              useAkkord: false,
              useKotta: true,
            ),
            settings: const AppSettings(receiverUseKotta: true),
          ),
          child: const SizedBox.expand(),
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
