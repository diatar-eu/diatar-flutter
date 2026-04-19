import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

import '../l10n/l10n.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.initialSettings,
    required this.senderSuggestions,
    required this.channelSuggestions,
    required this.onApply,
    required this.onRefreshUsers,
    required this.onSenderFilterChanged,
    required this.onSenderChosen,
  });

  final AppSettings initialSettings;
  final List<String> senderSuggestions;
  final List<String> channelSuggestions;
  final ValueChanged<AppSettings> onApply;
  final VoidCallback onRefreshUsers;
  final ValueChanged<String> onSenderFilterChanged;
  final ValueChanged<String> onSenderChosen;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _port;
  late final TextEditingController _clipL;
  late final TextEditingController _clipT;
  late final TextEditingController _clipR;
  late final TextEditingController _clipB;
  late final TextEditingController _mqttUser;
  late bool _ipMode;

  late bool _borderToClip;
  late bool _mirror;
  late bool _boot;
  late int _rotate;
  late String _channel;
  late Color _bkColor;
  late Color _txtColor;
  late Color _blankColor;
  late Color _hiColor;

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.initialSettings;
    _port = TextEditingController(text: s.port.toString());
    _clipL = TextEditingController(text: s.clipL.toString());
    _clipT = TextEditingController(text: s.clipT.toString());
    _clipR = TextEditingController(text: s.clipR.toString());
    _clipB = TextEditingController(text: s.clipB.toString());
    _mqttUser = TextEditingController(text: s.mqttUser);
    _ipMode = s.mqttUser.trim().isEmpty;
    _borderToClip = s.borderToClip;
    _mirror = s.mirror;
    _boot = s.boot;
    _rotate = s.rotateQuarterTurns;
    _channel = s.mqttChannel;
    _bkColor = s.bkColor;
    _txtColor = s.txtColor;
    _blankColor = s.blankColor;
    _hiColor = s.hiColor;

    _mqttUser.addListener(() {
      widget.onSenderFilterChanged(_mqttUser.text);
      setState(() {
        _ipMode = _mqttUser.text.trim().isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _port.dispose();
    _clipL.dispose();
    _clipT.dispose();
    _clipR.dispose();
    _clipB.dispose();
    _mqttUser.dispose();
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
            Text(l10n.settingsTitleReceiver, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    groupValue: _ipMode,
                    onChanged: (bool? v) {
                      if (v == true) {
                        setState(() {
                          _ipMode = true;
                          _mqttUser.text = '';
                        });
                      }
                    },
                    title: Text(l10n.modeIp),
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    groupValue: _ipMode,
                    onChanged: (bool? v) {
                      if (v == false) {
                        setState(() {
                          _ipMode = false;
                        });
                        widget.onRefreshUsers();
                      }
                    },
                    title: Text(l10n.modeInternet),
                    dense: true,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              enabled: _ipMode,
              decoration: InputDecoration(labelText: l10n.tcpPortRange),
            ),
            if (!_ipMode) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _mqttUser,
                      decoration: InputDecoration(
                        labelText: l10n.senderLabel,
                        helperText: l10n.senderHelper,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onRefreshUsers,
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.senderRefreshTooltip,
                  ),
                ],
              ),
              if (widget.senderSuggestions.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: widget.senderSuggestions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String sender = widget.senderSuggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(sender),
                        onTap: () {
                          _mqttUser.text = sender;
                          widget.onSenderChosen(sender);
                        },
                      );
                    },
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _channel,
                decoration: InputDecoration(labelText: l10n.channelLabel),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(value: '1', child: Text('1.')),
                  ...widget.channelSuggestions.asMap().entries.map((MapEntry<int, String> e) {
                    final String value = '${e.key + 1}';
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text('${e.key + 1}. ${e.value}'),
                    );
                  }),
                ],
                onChanged: (String? v) => setState(() => _channel = v ?? '1'),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _clipField(l10n.clipLeft, _clipL),
                _clipField(l10n.clipTop, _clipT),
                _clipField(l10n.clipRight, _clipR),
                _clipField(l10n.clipBottom, _clipB),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _borderToClip,
              onChanged: (bool v) => setState(() => _borderToClip = v),
              title: Text(l10n.borderToClip),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mirror,
              onChanged: (bool v) => setState(() => _mirror = v),
              title: Text(l10n.mirror),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _boot,
              onChanged: (bool v) => setState(() => _boot = v),
              title: Text(l10n.autoBootIndicator),
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
                    if (picked != null) setState(() => _bkColor = picked);
                  },
                ),
                _colorButton(
                  label: l10n.textColor,
                  color: _txtColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _txtColor, title: l10n.textColorTitle);
                    if (picked != null) setState(() => _txtColor = picked);
                  },
                ),
                _colorButton(
                  label: l10n.emptySlideColor,
                  color: _blankColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _blankColor, title: l10n.emptySlideColorTitle);
                    if (picked != null) setState(() => _blankColor = picked);
                  },
                ),
                _colorButton(
                  label: l10n.highlightColor,
                  color: _hiColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _hiColor, title: l10n.highlightColorTitle);
                    if (picked != null) setState(() => _hiColor = picked);
                  },
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: _rotate,
              decoration: InputDecoration(labelText: l10n.rotationLabel),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text('0°')),
                DropdownMenuItem<int>(value: 1, child: Text('90°')),
                DropdownMenuItem<int>(value: 2, child: Text('180°')),
                DropdownMenuItem<int>(value: 3, child: Text('270°')),
              ],
              onChanged: (int? v) => setState(() => _rotate = v ?? 0),
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

  Widget _clipField(String label, TextEditingController controller) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: !_borderToClip,
        decoration: InputDecoration(labelText: label),
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
      mqttUser: _ipMode ? '' : _mqttUser.text.trim(),
      mqttChannel: _channel,
      clipL: double.tryParse(_clipL.text.trim()) ?? widget.initialSettings.clipL,
      clipT: double.tryParse(_clipT.text.trim()) ?? widget.initialSettings.clipT,
      clipR: double.tryParse(_clipR.text.trim()) ?? widget.initialSettings.clipR,
      clipB: double.tryParse(_clipB.text.trim()) ?? widget.initialSettings.clipB,
      borderToClip: _borderToClip,
      mirror: _mirror,
      boot: _boot,
      rotateQuarterTurns: _rotate,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
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
                        if (parsed != null) setState(() => temp = parsed);
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
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
                FilledButton(onPressed: () => Navigator.of(context).pop(temp), child: Text(context.l10n.ok)),
              ],
            );
          },
        );
      },
    );
  }

  String _colorToHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color? _parseHexColor(String input) {
    String value = input.trim().replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}
