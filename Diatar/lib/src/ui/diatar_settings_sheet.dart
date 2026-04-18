import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class DiatarSettingsSheet extends StatefulWidget {
  const DiatarSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onApply,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onApply;

  @override
  State<DiatarSettingsSheet> createState() => _DiatarSettingsSheetState();
}

class _DiatarSettingsSheetState extends State<DiatarSettingsSheet> {
  late final TextEditingController _port;
  late final TextEditingController _mqttUser;
  late final TextEditingController _mqttPassword;
  late final TextEditingController _mqttChannel;
  late final TextEditingController _dtxPath;
  late final TextEditingController _blankPicPath;
  late final TextEditingController _projFontSize;
  late final TextEditingController _projTitleSize;
  late final TextEditingController _projLeftIndent;
  late final TextEditingController _projBorderL;
  late final TextEditingController _projBorderT;
  late final TextEditingController _projBorderR;
  late final TextEditingController _projBorderB;
  late int _projSpacingStep;
  late int _projKottaArany;
  late int _projAkkordArany;
  late int _projBgMode;
  late int _projBackTrans;
  late int _projBlankTrans;
  late bool _projAutoSize;
  late bool _projHCenter;
  late bool _projVCenter;
  late bool _projUseAkkord;
  late bool _projUseKotta;
  late bool _projUseTitle;
  late bool _projBoldText;
  late Color _bkColor;
  late Color _txtColor;
  late Color _blankColor;
  late Color _hiColor;

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.initialSettings;
    _port = TextEditingController(text: s.port.toString());
    _mqttUser = TextEditingController(text: s.mqttUser);
    _mqttPassword = TextEditingController(text: s.mqttPassword);
    _mqttChannel = TextEditingController(text: s.mqttChannel);
    _dtxPath = TextEditingController(text: s.dtxPath);
    _blankPicPath = TextEditingController(text: s.blankPicPath);
    _projFontSize = TextEditingController(text: s.projFontSize.toString());
    _projTitleSize = TextEditingController(text: s.projTitleSize.toString());
    _projLeftIndent = TextEditingController(text: s.projLeftIndent.toString());
    _projBorderL = TextEditingController(text: s.projBorderL.toString());
    _projBorderT = TextEditingController(text: s.projBorderT.toString());
    _projBorderR = TextEditingController(text: s.projBorderR.toString());
    _projBorderB = TextEditingController(text: s.projBorderB.toString());
    _projSpacingStep = s.projSpacingStep.clamp(0, 10);
    _projKottaArany = s.projKottaArany.clamp(10, 200);
    _projAkkordArany = s.projAkkordArany.clamp(10, 200);
    _projBgMode = s.projBgMode.clamp(0, 4);
    _projBackTrans = s.projBackTrans.clamp(0, 100);
    _projBlankTrans = s.projBlankTrans.clamp(0, 100);
    _projAutoSize = s.projAutoSize;
    _projHCenter = s.projHCenter;
    _projVCenter = s.projVCenter;
    _projUseAkkord = s.projUseAkkord;
    _projUseKotta = s.projUseKotta;
    _projUseTitle = s.projUseTitle;
    _projBoldText = s.projBoldText;
    _bkColor = s.bkColor;
    _txtColor = s.txtColor;
    _blankColor = s.blankColor;
    _hiColor = s.hiColor;
  }

  @override
  void dispose() {
    _port.dispose();
    _mqttUser.dispose();
    _mqttPassword.dispose();
    _mqttChannel.dispose();
    _dtxPath.dispose();
    _blankPicPath.dispose();
    _projFontSize.dispose();
    _projTitleSize.dispose();
    _projLeftIndent.dispose();
    _projBorderL.dispose();
    _projBorderT.dispose();
    _projBorderR.dispose();
    _projBorderB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.settingsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.tcpPortRange),
            ),
            TextField(
              controller: _mqttUser,
              decoration: InputDecoration(
                labelText: l10n.mqttUserHint,
              ),
            ),
            TextField(
              controller: _mqttPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.mqttPassword),
            ),
            TextField(
              controller: _mqttChannel,
              decoration: InputDecoration(labelText: l10n.mqttChannel),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _dtxPath,
                    decoration: InputDecoration(labelText: l10n.dtxFolderPath),
                  ),
                ),
                IconButton(
                  onPressed: _pickDtxFolder,
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.fileChoose,
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _blankPicPath,
                    decoration: InputDecoration(labelText: l10n.blankImagePath),
                  ),
                ),
                IconButton(
                  onPressed: _pickBlankFile,
                  icon: const Icon(Icons.folder_open),
                  tooltip: l10n.fileChoose,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.projectionSettingsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _projectionNumberField(l10n.fontSize, _projFontSize),
                _projectionNumberField(l10n.titleSize, _projTitleSize),
                _projectionNumberField(l10n.leftMargin, _projLeftIndent),
                _projectionNumberField(l10n.borderLeft, _projBorderL),
                _projectionNumberField(l10n.borderTop, _projBorderT),
                _projectionNumberField(l10n.borderRight, _projBorderR),
                _projectionNumberField(l10n.borderBottom, _projBorderB),
              ],
            ),
            DropdownButtonFormField<int>(
              value: _projSpacingStep,
              decoration: InputDecoration(labelText: l10n.lineSpacing),
              items: List<DropdownMenuItem<int>>.generate(
                11,
                (int i) => DropdownMenuItem<int>(
                  value: i,
                  child: Text('${100 + i * 10}%'),
                ),
              ),
              onChanged: (int? v) => setState(() => _projSpacingStep = v ?? 0),
            ),
            DropdownButtonFormField<int>(
              value: _projKottaArany,
              decoration: InputDecoration(labelText: l10n.kottaScale),
              items: List<DropdownMenuItem<int>>.generate(
                20,
                (int i) {
                  final int value = (i + 1) * 10;
                  return DropdownMenuItem<int>(value: value, child: Text('$value%'));
                },
              ),
              onChanged: (int? v) => setState(() => _projKottaArany = v ?? 100),
            ),
            DropdownButtonFormField<int>(
              value: _projAkkordArany,
              decoration: InputDecoration(labelText: l10n.chordScale),
              items: List<DropdownMenuItem<int>>.generate(
                20,
                (int i) {
                  final int value = (i + 1) * 10;
                  return DropdownMenuItem<int>(value: value, child: Text('$value%'));
                },
              ),
              onChanged: (int? v) => setState(() => _projAkkordArany = v ?? 100),
            ),
            DropdownButtonFormField<int>(
              value: _projBgMode,
              decoration: InputDecoration(labelText: l10n.backgroundMode),
              items: <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text(l10n.bgModeCenter)),
                DropdownMenuItem<int>(value: 1, child: Text(l10n.bgModeZoom)),
                DropdownMenuItem<int>(value: 2, child: Text(l10n.bgModeFull)),
                DropdownMenuItem<int>(value: 3, child: Text(l10n.bgModeCascade)),
                DropdownMenuItem<int>(value: 4, child: Text(l10n.bgModeMirror)),
              ],
              onChanged: (int? v) => setState(() => _projBgMode = v ?? 0),
            ),
            DropdownButtonFormField<int>(
              value: _projBackTrans,
              decoration: InputDecoration(labelText: l10n.backgroundOpacity),
              items: List<DropdownMenuItem<int>>.generate(
                11,
                (int i) {
                  final int value = i * 10;
                  return DropdownMenuItem<int>(value: value, child: Text('$value%'));
                },
              ),
              onChanged: (int? v) => setState(() => _projBackTrans = v ?? 0),
            ),
            DropdownButtonFormField<int>(
              value: _projBlankTrans,
              decoration: InputDecoration(labelText: l10n.blankOpacity),
              items: List<DropdownMenuItem<int>>.generate(
                11,
                (int i) {
                  final int value = i * 10;
                  return DropdownMenuItem<int>(value: value, child: Text('$value%'));
                },
              ),
              onChanged: (int? v) => setState(() => _projBlankTrans = v ?? 0),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: !_projAutoSize,
              onChanged: (bool v) => setState(() => _projAutoSize = !v),
              title: Text(l10n.scrollableProjection),
              subtitle: Text(l10n.scrollableProjectionHint),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projUseTitle,
              onChanged: (bool v) => setState(() => _projUseTitle = v),
              title: Text(l10n.showTitle),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projHCenter,
              onChanged: (bool v) => setState(() => _projHCenter = v),
              title: Text(l10n.hCenter),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projVCenter,
              onChanged: (bool v) => setState(() => _projVCenter = v),
              title: Text(l10n.vCenter),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projUseAkkord,
              onChanged: (bool v) => setState(() => _projUseAkkord = v),
              title: Text(l10n.showChords),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projUseKotta,
              onChanged: (bool v) => setState(() => _projUseKotta = v),
              title: Text(l10n.showKotta),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projBoldText,
              onChanged: (bool v) => setState(() => _projBoldText = v),
              title: Text(l10n.boldText),
            ),
            const SizedBox(height: 8),
            Text(l10n.colorsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _colorButton(
                  label: l10n.backgroundColor,
                  color: _bkColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _bkColor, title: l10n.backgroundColorTitle);
                    if (picked != null) {
                      setState(() => _bkColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: l10n.textColor,
                  color: _txtColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _txtColor, title: l10n.textColorTitle);
                    if (picked != null) {
                      setState(() => _txtColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: l10n.emptySlideColor,
                  color: _blankColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _blankColor, title: l10n.emptySlideColorTitle);
                    if (picked != null) {
                      setState(() => _blankColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: l10n.highlightColor,
                  color: _hiColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _hiColor, title: l10n.highlightColorTitle);
                    if (picked != null) {
                      setState(() => _hiColor = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final int port = int.tryParse(_port.text.trim()) ?? widget.initialSettings.port;
    if (port < 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.invalidPortRange)));
      return;
    }

    final AppSettings updated = widget.initialSettings.copyWith(
      port: port,
      mqttUser: _mqttUser.text.trim(),
      mqttPassword: _mqttPassword.text,
      mqttChannel: _mqttChannel.text.trim().isEmpty ? '1' : _mqttChannel.text.trim(),
      dtxPath: _dtxPath.text.trim(),
      blankPicPath: _blankPicPath.text.trim(),
      projFontSize: _parseInt(_projFontSize.text, widget.initialSettings.projFontSize, min: 12, max: 128),
      projTitleSize: _parseInt(_projTitleSize.text, widget.initialSettings.projTitleSize, min: 12, max: 128),
      projLeftIndent: _parseInt(_projLeftIndent.text, widget.initialSettings.projLeftIndent, min: 0, max: 10),
      projBorderL: _parseInt(_projBorderL.text, widget.initialSettings.projBorderL, min: 0, max: 1000),
      projBorderT: _parseInt(_projBorderT.text, widget.initialSettings.projBorderT, min: 0, max: 1000),
      projBorderR: _parseInt(_projBorderR.text, widget.initialSettings.projBorderR, min: 0, max: 1000),
      projBorderB: _parseInt(_projBorderB.text, widget.initialSettings.projBorderB, min: 0, max: 1000),
      projSpacingStep: _projSpacingStep.clamp(0, 10),
      projAutoSize: _projAutoSize,
      projHCenter: _projHCenter,
      projVCenter: _projVCenter,
      projUseAkkord: _projUseAkkord,
      projUseKotta: _projUseKotta,
      projUseTitle: _projUseTitle,
      projKottaArany: _projKottaArany.clamp(10, 200),
      projAkkordArany: _projAkkordArany.clamp(10, 200),
      projBgMode: _projBgMode.clamp(0, 4),
      projBackTrans: _projBackTrans.clamp(0, 100),
      projBlankTrans: _projBlankTrans.clamp(0, 100),
      projBoldText: _projBoldText,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  Widget _projectionNumberField(String label, TextEditingController controller) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  int _parseInt(String raw, int fallback, {required int min, required int max}) {
    final int value = int.tryParse(raw.trim()) ?? fallback;
    return value.clamp(min, max);
  }

  Future<void> _pickBlankFile() async {
    final XTypeGroup images = XTypeGroup(
      label: context.l10n.imagesFileTypeLabel,
      extensions: <String>['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[images]);
    if (!mounted || file == null) {
      return;
    }
    setState(() {
      _blankPicPath.text = file.path;
    });
  }

  Future<void> _pickDtxFolder() async {
    final String? folderPath = await getDirectoryPath();
    if (!mounted || folderPath == null) {
      return;
    }
    setState(() {
      _dtxPath.text = folderPath;
    });
  }

  Widget _colorButton({required String label, required Color color, required VoidCallback onPressed}) {
    final Color fg = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return SizedBox(
      width: 150,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg,
          side: BorderSide(color: fg.withValues(alpha: 0.25)),
        ),
        child: Text(label),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial, {required String title}) {
    final TextEditingController hex = TextEditingController(text: _colorToHex(initial));
    Color temp = initial;
    const List<Color> palette = <Color>[
      Color(0xFF000000),
      Color(0xFFFFFFFF),
      Color(0xFFFF0000),
      Color(0xFF00FF00),
      Color(0xFF0000FF),
      Color(0xFFFFFF00),
      Color(0xFF00FFFF),
      Color(0xFFFF00FF),
      Color(0xFF404040),
      Color(0xFF808080),
      Color(0xFF800000),
      Color(0xFF008000),
      Color(0xFF000080),
      Color(0xFF804000),
      Color(0xFF800080),
      Color(0xFF008080),
    ];

    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: temp,
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hex,
                      decoration: InputDecoration(
                        labelText: context.l10n.hexColorHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (String value) {
                        final Color? parsed = _parseHexColor(value);
                        if (parsed != null) {
                          setState(() => temp = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: palette
                          .map(
                            (Color c) => InkWell(
                              onTap: () {
                                setState(() {
                                  temp = c;
                                  hex.text = _colorToHex(c);
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: c,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(temp),
                  child: Text(context.l10n.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Color? _parseHexColor(String input) {
    String value = input.trim().replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) {
      return null;
    }
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }
}
