import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

import '../../l10n/generated/app_localizations.dart';
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
    required this.onExitRequested,
    required this.onShutdownRequested,
    required this.onRebootRequested,
  });

  final AppSettings initialSettings;
  final List<String> senderSuggestions;
  final List<String> channelSuggestions;
  final ValueChanged<AppSettings> onApply;
  final VoidCallback onRefreshUsers;
  final ValueChanged<String> onSenderFilterChanged;
  final ValueChanged<String> onSenderChosen;
  final VoidCallback onExitRequested;
  final VoidCallback onShutdownRequested;
  final VoidCallback onRebootRequested;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  static const List<Color> _palette = <Color>[
    Color(0xFF000000),
    Color(0xFF1E1E1E),
    Color(0xFF37474F),
    Color(0xFF263238),
    Color(0xFFFFFFFF),
    Color(0xFFECEFF1),
    Color(0xFFFFEB3B),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF03A9F4),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

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
  late bool _receiverUseServerColors;
  late bool _receiverShowHighlight;
  late bool _receiverUseAkkord;
  late bool _receiverUseKotta;
  late bool _projectionScrollable;
  late String _appLanguage;
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
    _receiverUseServerColors = s.receiverUseServerColors;
    _receiverShowHighlight = s.receiverShowHighlight;
    _receiverUseAkkord = s.receiverUseAkkord;
    _receiverUseKotta = s.receiverUseKotta;
    _projectionScrollable = !s.projAutoSize;
    _appLanguage = _isSupportedLanguage(s.appLanguage) ? s.appLanguage : '';
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
            DropdownButtonFormField<String>(
              initialValue: _appLanguage,
              decoration: InputDecoration(labelText: l10n.uiLanguage),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(l10n.languageSystem),
                ),
                ...AppLocalizations.supportedLocales.map((Locale locale) {
                  final String code = locale.languageCode;
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(_languageLabel(context, code)),
                  );
                }),
              ],
              onChanged: (String? v) => setState(() => _appLanguage = v ?? ''),
            ),
            const SizedBox(height: 12),
            Text(l10n.projectionFilteringTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseServerColors,
              onChanged: (bool v) => setState(() => _receiverUseServerColors = v),
              title: Text(l10n.receiverUseServerColors),
              subtitle: Text(l10n.receiverUseServerColorsHint),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverShowHighlight,
              onChanged: (bool v) => setState(() => _receiverShowHighlight = v),
              title: Text(l10n.receiverShowHighlight),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseAkkord,
              onChanged: (bool v) => setState(() => _receiverUseAkkord = v),
              title: Text(l10n.showChords),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseKotta,
              onChanged: (bool v) => setState(() => _receiverUseKotta = v),
              title: Text(l10n.showKotta),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _projectionScrollable,
              onChanged: (bool v) => setState(() => _projectionScrollable = v),
              title: Text(l10n.scrollableProjection),
              subtitle: Text(l10n.scrollableProjectionHint),
            ),
            const SizedBox(height: 12),
            Text(l10n.localColorsTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _colorRow(l10n.backgroundColorLabel, _bkColor, (Color c) => setState(() => _bkColor = c), enabled: !_receiverUseServerColors),
            _colorRow(l10n.textColorLabel, _txtColor, (Color c) => setState(() => _txtColor = c), enabled: !_receiverUseServerColors),
            _colorRow(l10n.blankColorLabel, _blankColor, (Color c) => setState(() => _blankColor = c), enabled: !_receiverUseServerColors),
            _colorRow(l10n.highlightColorLabel, _hiColor, (Color c) => setState(() => _hiColor = c), enabled: !_receiverUseServerColors),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: widget.onExitRequested,
                  child: Text(l10n.exit),
                ),
                OutlinedButton(
                  onPressed: widget.onShutdownRequested,
                  child: Text(l10n.shutdown),
                ),
                OutlinedButton(
                  onPressed: widget.onRebootRequested,
                  child: Text(l10n.reboot),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      appLanguage: _appLanguage,
      receiverUseServerColors: _receiverUseServerColors,
      receiverShowHighlight: _receiverShowHighlight,
      receiverUseAkkord: _receiverUseAkkord,
      receiverUseKotta: _receiverUseKotta,
      projAutoSize: !_projectionScrollable,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  bool _isSupportedLanguage(String code) {
    if (code.trim().isEmpty) {
      return true;
    }
    return AppLocalizations.supportedLocales.any((Locale locale) => locale.languageCode == code);
  }

  String _languageLabel(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'hu':
        return l10n.languageHungarian;
      case 'en':
        return l10n.languageEnglish;
      default:
        return code;
    }
  }

  Widget _colorRow(String label, Color color, ValueChanged<Color> onChanged, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          InkWell(
            onTap: enabled ? () => _pickColor(color, onChanged) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled ? () => _pickColor(color, onChanged) : null,
            child: Text(context.l10n.change),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(Color current, ValueChanged<Color> onChanged) async {
    final Color? selected = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.colorPickerTitle),
          content: SizedBox(
            width: 360,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((Color c) {
                final bool selected = c.toARGB32() == current.toARGB32();
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
          ],
        );
      },
    );
    if (selected != null) {
      onChanged(selected);
    }
  }
}
