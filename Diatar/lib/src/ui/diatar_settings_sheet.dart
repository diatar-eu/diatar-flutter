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
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }
}
