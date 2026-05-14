import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  late final TextEditingController _search;
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
  String _appVersion = '-';
  String _buildNumber = '-';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    final AppSettings s = widget.initialSettings;
    _search = TextEditingController();
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

  Future<void> _loadAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void dispose() {
    _search.dispose();
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
    final String query = _search.text.trim().toLowerCase();
    final bool internetEnabled = !_ipMode;
    final String senderSummary = _mqttUser.text.trim().isEmpty
        ? '-'
        : _mqttUser.text.trim();
    final String internetSummary = internetEnabled
        ? l10n.valueOn
        : l10n.valueOff;
    final String languageLabel = _appLanguage.trim().isEmpty
        ? l10n.languageSystem
        : _languageLabel(context, _appLanguage);
    final String filterSummary = _receiverUseServerColors
        ? l10n.projectionColorSourceServer
        : l10n.projectionColorSourceLocal;
    final bool showInternet = _matches(
      query,
      l10n.settingsSearchKeywordsInternet,
    );
    final bool showLan = _matches(query, l10n.settingsSearchKeywordsLan);
    final bool showProjectionImage = _matches(
      query,
      l10n.settingsSearchKeywordsProjectionImage,
    );
    final bool showProjectionFilter = _matches(
      query,
      l10n.settingsSearchKeywordsProjectionFilter,
    );
    final bool showColors = _matches(query, l10n.settingsSearchKeywordsColors);
    final bool showGeneral = _matches(
      query,
      l10n.settingsSearchKeywordsGeneral,
    );
    final bool showSystem = _matches(query, l10n.settingsSearchKeywordsSystem);
    final bool anyVisible =
        showInternet ||
        showLan ||
        showProjectionImage ||
        showProjectionFilter ||
        showColors ||
        showGeneral ||
        showSystem;
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                Text(
                  l10n.settingsTitleReceiver,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.settingsVersionLabel(_appVersion, _buildNumber),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.settingsSearchLabel,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  if (showInternet)
                    _settingsTile(
                      leading: const Icon(Icons.public),
                      title: Text(l10n.settingsInternetTitle),
                      subtitle: Text(
                        l10n.settingsInternetSubtitle(
                          internetSummary,
                          senderSummary,
                        ),
                      ),
                      onTap: _openInternetSettings,
                    ),
                  if (showInternet &&
                      (showLan ||
                          showProjectionImage ||
                          showProjectionFilter ||
                          showColors ||
                          showGeneral ||
                          showSystem))
                    const Divider(height: 1),
                  if (showLan)
                    _settingsTile(
                      leading: const Icon(Icons.lan),
                      title: Text(l10n.settingsLocalNetworkTitle),
                      subtitle: Text(
                        l10n.settingsLocalNetworkSubtitle(
                          _port.text.trim().isEmpty ? '-' : _port.text.trim(),
                        ),
                      ),
                      onTap: _openLocalNetworkSettings,
                    ),
                  if (showLan &&
                      (showProjectionImage ||
                          showProjectionFilter ||
                          showColors ||
                          showGeneral ||
                          showSystem))
                    const Divider(height: 1),
                  if (showProjectionImage)
                    _settingsTile(
                      leading: const Icon(Icons.crop_free),
                      title: Text(l10n.projectionImageTitle),
                      subtitle: Text(
                        l10n.projectionImageSummary(
                          '${_rotate * 90}°',
                          _mirror ? l10n.valueOn : l10n.valueOff,
                        ),
                      ),
                      onTap: _openProjectionLayoutSettings,
                    ),
                  if (showProjectionImage &&
                      (showProjectionFilter ||
                          showColors ||
                          showGeneral ||
                          showSystem))
                    const Divider(height: 1),
                  if (showProjectionFilter)
                    _settingsTile(
                      leading: const Icon(Icons.filter_alt_outlined),
                      title: Text(l10n.projectionFilteringTitle),
                      subtitle: Text(
                        l10n.projectionFilterSummary(
                          filterSummary,
                          _projectionScrollable ? l10n.valueOn : l10n.valueOff,
                        ),
                      ),
                      onTap: _openProjectionFilterSettings,
                    ),
                  if (showProjectionFilter &&
                      (showColors || showGeneral || showSystem))
                    const Divider(height: 1),
                  if (showColors)
                    _settingsTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(l10n.localColorsTitle),
                      subtitle: Text(
                        l10n.localColorsSummary(
                          _shortColorHex(_bkColor),
                          _shortColorHex(_txtColor),
                        ),
                      ),
                      onTap: _openColorSettings,
                    ),
                  if (showColors && (showGeneral || showSystem))
                    const Divider(height: 1),
                  if (showGeneral)
                    _settingsTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.settingsGeneralTitle),
                      subtitle: Text(
                        l10n.settingsGeneralSubtitle(
                          languageLabel,
                          _boot ? l10n.valueOn : l10n.valueOff,
                        ),
                      ),
                      onTap: _openGeneralSettings,
                    ),
                  if (showGeneral && showSystem) const Divider(height: 1),
                  if (showSystem)
                    _settingsTile(
                      leading: const Icon(Icons.power_settings_new),
                      title: Text(l10n.systemActionsTitle),
                      subtitle: Text(l10n.systemActionsSummary),
                      onTap: _openSystemActions,
                    ),
                  if (!anyVisible)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(l10n.settingsNoResults),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const Spacer(),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInternetSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsInternetTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        final bool internetEnabled = !_ipMode;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: internetEnabled,
            onChanged: (bool v) {
              setBoth(() {
                _ipMode = !v;
                if (_ipMode) {
                  _mqttUser.text = '';
                }
              });
              if (v) {
                widget.onRefreshUsers();
              }
            },
            title: Text(l10n.internetBroadcastTitle),
          ),
          if (internetEnabled) ...<Widget>[
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
                        setBoth(() {
                          _mqttUser.text = sender;
                        });
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
                ...widget.channelSuggestions.asMap().entries.map((
                  MapEntry<int, String> e,
                ) {
                  final String value = '${e.key + 1}';
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text('${e.key + 1}. ${e.value}'),
                  );
                }),
              ],
              onChanged: (String? v) => setBoth(() => _channel = v ?? '1'),
            ),
          ],
        ];
      },
    );
  }

  Future<void> _openLocalNetworkSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsLocalNetworkTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ipMode,
            onChanged: (bool v) {
              setBoth(() {
                _ipMode = v;
                if (_ipMode) {
                  _mqttUser.text = '';
                }
              });
              if (!v) {
                widget.onRefreshUsers();
              }
            },
            title: Text(l10n.settingsLocalNetworkTitle),
          ),
          TextField(
            controller: _port,
            enabled: _ipMode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.tcpPortRange),
          ),
        ];
      },
    );
  }

  Future<void> _openProjectionLayoutSettings() {
    return _openSectionSheet(
      title: context.l10n.projectionImageTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
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
            onChanged: (bool v) => setBoth(() => _borderToClip = v),
            title: Text(l10n.borderToClip),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mirror,
            onChanged: (bool v) => setBoth(() => _mirror = v),
            title: Text(l10n.mirror),
          ),
          DropdownButtonFormField<int>(
            initialValue: _rotate,
            decoration: InputDecoration(labelText: l10n.rotationLabel),
            items: <DropdownMenuItem<int>>[
              for (int i = 0; i < 4; i++)
                DropdownMenuItem<int>(value: i, child: Text('${i * 90}°')),
            ],
            onChanged: (int? v) => setBoth(() => _rotate = v ?? 0),
          ),
        ];
      },
    );
  }

  Future<void> _openProjectionFilterSettings() {
    return _openSectionSheet(
      title: context.l10n.projectionFilteringTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _receiverUseServerColors,
            onChanged: (bool v) => setBoth(() => _receiverUseServerColors = v),
            title: Text(l10n.receiverUseServerColors),
            subtitle: Text(l10n.receiverUseServerColorsHint),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _receiverShowHighlight,
            onChanged: (bool v) => setBoth(() => _receiverShowHighlight = v),
            title: Text(l10n.receiverShowHighlight),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _receiverUseAkkord,
            onChanged: (bool v) => setBoth(() => _receiverUseAkkord = v),
            title: Text(l10n.showChords),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _receiverUseKotta,
            onChanged: (bool v) => setBoth(() => _receiverUseKotta = v),
            title: Text(l10n.showKotta),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projectionScrollable,
            onChanged: (bool v) => setBoth(() => _projectionScrollable = v),
            title: Text(l10n.scrollableProjection),
            subtitle: Text(l10n.scrollableProjectionHint),
          ),
        ];
      },
    );
  }

  Future<void> _openColorSettings() {
    return _openSectionSheet(
      title: context.l10n.localColorsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          _colorRow(
            l10n.backgroundColorLabel,
            _bkColor,
            (Color c) => setBoth(() => _bkColor = c),
            enabled: !_receiverUseServerColors,
          ),
          _colorRow(
            l10n.textColorLabel,
            _txtColor,
            (Color c) => setBoth(() => _txtColor = c),
            enabled: !_receiverUseServerColors,
          ),
          _colorRow(
            l10n.blankColorLabel,
            _blankColor,
            (Color c) => setBoth(() => _blankColor = c),
            enabled: !_receiverUseServerColors,
          ),
          _colorRow(
            l10n.highlightColorLabel,
            _hiColor,
            (Color c) => setBoth(() => _hiColor = c),
            enabled: !_receiverUseServerColors,
          ),
        ];
      },
    );
  }

  Future<void> _openGeneralSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsGeneralTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _boot,
            onChanged: (bool v) => setBoth(() => _boot = v),
            title: Text(l10n.autoBootIndicator),
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
            onChanged: (String? v) => setBoth(() => _appLanguage = v ?? ''),
          ),
        ];
      },
    );
  }

  Future<void> _openSystemActions() {
    return _openSectionSheet(
      title: context.l10n.systemActionsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
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
        ];
      },
    );
  }

  Future<void> _openSectionSheet({
    required String title,
    required List<Widget> Function(
      BuildContext context,
      void Function(void Function()) setBoth,
    )
    builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setModalState,
              ) {
                void setBoth(void Function() fn) {
                  if (mounted) {
                    setState(fn);
                  }
                  setModalState(() {});
                }

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...builder(context, setBoth),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.l10n.ok),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  bool _matches(String query, String haystack) {
    if (query.isEmpty) {
      return true;
    }
    return haystack.toLowerCase().contains(query);
  }

  Widget _settingsTile({
    required Widget leading,
    required Widget title,
    required Widget subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
    final int port =
        int.tryParse(_port.text.trim()) ?? widget.initialSettings.port;
    if (port < 0 || port > 65535) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.invalidPortRange)));
      return;
    }

    final AppSettings updated = widget.initialSettings.copyWith(
      port: port,
      mqttUser: _ipMode ? '' : _mqttUser.text.trim(),
      mqttChannel: _channel,
      clipL:
          double.tryParse(_clipL.text.trim()) ?? widget.initialSettings.clipL,
      clipT:
          double.tryParse(_clipT.text.trim()) ?? widget.initialSettings.clipT,
      clipR:
          double.tryParse(_clipR.text.trim()) ?? widget.initialSettings.clipR,
      clipB:
          double.tryParse(_clipB.text.trim()) ?? widget.initialSettings.clipB,
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
    return AppLocalizations.supportedLocales.any(
      (Locale locale) => locale.languageCode == code,
    );
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

  Widget _colorRow(
    String label,
    Color color,
    ValueChanged<Color> onChanged, {
    required bool enabled,
  }) {
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
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
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
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white24,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  String _shortColorHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
