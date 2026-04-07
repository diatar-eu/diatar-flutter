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
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }
}
