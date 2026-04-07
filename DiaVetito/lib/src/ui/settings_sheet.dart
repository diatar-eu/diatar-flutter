import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

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
            const Text('Beallitasok', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
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
                    title: const Text('IP'),
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
                    title: const Text('Internet'),
                    dense: true,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              enabled: _ipMode,
              decoration: const InputDecoration(labelText: 'TCP port (0..65535)'),
            ),
            if (!_ipMode) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _mqttUser,
                      decoration: const InputDecoration(
                        labelText: 'Kuldo',
                        helperText: 'MQTT sender neve',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onRefreshUsers,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Kuldo lista frissites',
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
                value: _channel,
                decoration: const InputDecoration(labelText: 'Csatorna'),
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
                _clipField('Bal', _clipL),
                _clipField('Felso', _clipT),
                _clipField('Jobb', _clipR),
                _clipField('Also', _clipB),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _borderToClip,
              onChanged: (bool v) => setState(() => _borderToClip = v),
              title: const Text('Margok a vezerlotol (Border2Clip)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mirror,
              onChanged: (bool v) => setState(() => _mirror = v),
              title: const Text('Tukrozes'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _boot,
              onChanged: (bool v) => setState(() => _boot = v),
              title: const Text('Automatikus inditas (jelzo)'),
            ),
            DropdownButtonFormField<int>(
              value: _rotate,
              decoration: const InputDecoration(labelText: 'Forgatas'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 0, child: Text('0°')),
                DropdownMenuItem<int>(value: 1, child: Text('90°')),
                DropdownMenuItem<int>(value: 2, child: Text('180°')),
                DropdownMenuItem<int>(value: 3, child: Text('270°')),
              ],
              onChanged: (int? v) => setState(() => _rotate = v ?? 0),
            ),
            const SizedBox(height: 12),
            const Text('Vetites szurese', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseServerColors,
              onChanged: (bool v) => setState(() => _receiverUseServerColors = v),
              title: const Text('Szerver szinei'),
              subtitle: const Text('Ha ki van kapcsolva, a helyi szinek lesznek hasznalva.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverShowHighlight,
              onChanged: (bool v) => setState(() => _receiverShowHighlight = v),
              title: const Text('Kiemeles megjelenitese'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseAkkord,
              onChanged: (bool v) => setState(() => _receiverUseAkkord = v),
              title: const Text('Akkordok mutatasa'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _receiverUseKotta,
              onChanged: (bool v) => setState(() => _receiverUseKotta = v),
              title: const Text('Kotta mutatasa'),
            ),
            const SizedBox(height: 12),
            const Text('Helyi szinek', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _colorRow('Hatterszin', _bkColor, (Color c) => setState(() => _bkColor = c), enabled: !_receiverUseServerColors),
            _colorRow('Szovegszin', _txtColor, (Color c) => setState(() => _txtColor = c), enabled: !_receiverUseServerColors),
            _colorRow('Blank szin', _blankColor, (Color c) => setState(() => _blankColor = c), enabled: !_receiverUseServerColors),
            _colorRow('Kiemeles szin', _hiColor, (Color c) => setState(() => _hiColor = c), enabled: !_receiverUseServerColors),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: widget.onExitRequested,
                  child: const Text('Kilepes'),
                ),
                OutlinedButton(
                  onPressed: widget.onShutdownRequested,
                  child: const Text('Leallitas'),
                ),
                OutlinedButton(
                  onPressed: widget.onRebootRequested,
                  child: const Text('Ujrainditas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Megse')),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('Ment')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A port 0..65535 kozott legyen.')));
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
      receiverUseServerColors: _receiverUseServerColors,
      receiverShowHighlight: _receiverShowHighlight,
      receiverUseAkkord: _receiverUseAkkord,
      receiverUseKotta: _receiverUseKotta,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
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
                '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}',
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
            child: const Text('Valt'),
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
          title: const Text('Színválasztó'),
          content: SizedBox(
            width: 360,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((Color c) {
                final bool selected = c.value == current.value;
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Megse')),
          ],
        );
      },
    );
    if (selected != null) {
      onChanged(selected);
    }
  }
}
