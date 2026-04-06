import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';

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
  late bool _borderToClip;
  late bool _mirror;
  late bool _boot;
  late int _rotate;
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
    _borderToClip = s.borderToClip;
    _mirror = s.mirror;
    _boot = s.boot;
    _rotate = s.rotateQuarterTurns;
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
            const Text('Diatar beallitasok', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'TCP port (0..65535)'),
            ),
            TextField(
              controller: _mqttUser,
              decoration: const InputDecoration(
                labelText: 'MQTT user (ures = TCP mod)',
              ),
            ),
            TextField(
              controller: _mqttPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'MQTT jelszo'),
            ),
            TextField(
              controller: _mqttChannel,
              decoration: const InputDecoration(labelText: 'MQTT csatorna'),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            const Text('Szinek', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _colorButton(
                  label: 'Hatter',
                  color: _bkColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _bkColor, title: 'Hatter szine');
                    if (picked != null) {
                      setState(() => _bkColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: 'Szoveg',
                  color: _txtColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _txtColor, title: 'Szoveg szine');
                    if (picked != null) {
                      setState(() => _txtColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: 'Ures dia',
                  color: _blankColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _blankColor, title: 'Ures dia szine');
                    if (picked != null) {
                      setState(() => _blankColor = picked);
                    }
                  },
                ),
                _colorButton(
                  label: 'Kiemeles',
                  color: _hiColor,
                  onPressed: () async {
                    final Color? picked = await _pickColor(context, _hiColor, title: 'Kiemeles szine');
                    if (picked != null) {
                      setState(() => _hiColor = picked);
                    }
                  },
                ),
              ],
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

  void _save() {
    final int port = int.tryParse(_port.text.trim()) ?? widget.initialSettings.port;
    if (port < 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A port 0..65535 kozott legyen.')));
      return;
    }

    final AppSettings updated = widget.initialSettings.copyWith(
      port: port,
      mqttUser: _mqttUser.text.trim(),
      mqttPassword: _mqttPassword.text,
      mqttChannel: _mqttChannel.text.trim().isEmpty ? '1' : _mqttChannel.text.trim(),
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
                      decoration: const InputDecoration(
                        labelText: 'Hex szin (#AARRGGBB vagy #RRGGBB)',
                        border: OutlineInputBorder(),
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
                  child: const Text('Megse'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(temp),
                  child: const Text('OK'),
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
