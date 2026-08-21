import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:diatar_speech/diatar_speech.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/path_helper.dart';
import '../utils/file_system_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../../l10n/generated/app_localizations.dart';
import '../l10n/l10n.dart';
import '../services/mqtt_user_api_service.dart';
import '../services/cast_service.dart';
import '../services/export_import_service.dart';
import '../services/desktop_projector_bridge.dart';
import '../services/macos_file_panels.dart';
import '../services/blank_image_storage.dart';
import '../services/web_diavetito_url.dart';
import '../utils/friendly_path.dart';
import 'onboarding_sheet.dart';

class SongHotkeyOption {
  const SongHotkeyOption({required this.id, required this.label});

  final String id;
  final String label;
}

class CustomOrderSetOption {
  const CustomOrderSetOption({required this.id, required this.name});

  final String id;
  final String name;
}

enum DiatarSettingsInitialSection { internet, localNetwork }

class DiatarSettingsSheet extends StatefulWidget {
  const DiatarSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onApply,
    required this.onExitRequested,
    required this.onReloadBooksRequested,
    required this.onRemoteStopRequested,
    required this.onRemoteShutdownRequested,
    this.availableSongs = const <SongHotkeyOption>[],
    this.availableSongsLoader,
    this.availableOrderSets = const <CustomOrderSetOption>[],
    this.availableOrderSetsLoader,
    this.initialSection,
    this.closeAfterInitialSectionClose = false,
  });

  final AppSettings initialSettings;
  final Future<void> Function(AppSettings) onApply;
  final VoidCallback onExitRequested;
  final VoidCallback onReloadBooksRequested;
  final VoidCallback onRemoteStopRequested;
  final VoidCallback onRemoteShutdownRequested;
  final List<SongHotkeyOption> availableSongs;
  final List<SongHotkeyOption> Function()? availableSongsLoader;
  final List<CustomOrderSetOption> availableOrderSets;
  final List<CustomOrderSetOption> Function()? availableOrderSetsLoader;
  final DiatarSettingsInitialSection? initialSection;
  final bool closeAfterInitialSectionClose;

  @override
  State<DiatarSettingsSheet> createState() => _DiatarSettingsSheetState();
}

class _DiatarSettingsSheetState extends State<DiatarSettingsSheet> {
  static const MethodChannel _androidBackupSaveChannel = MethodChannel(
    'diatar.eu/dia_save',
  );
  static final RegExp _simpleEmailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  late final TextEditingController _search;
  late final TextEditingController _tcpTargets;
  late final TextEditingController _mqttUser;
  late final TextEditingController _mqttPassword;
  late final TextEditingController _blankPicPath;
  late final TextEditingController _diaExportPath;
  final BlankImageStore _blankImageStore = BlankImageStore();
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
  late int _appThemeMode;
  late String _appLanguage;
  late bool _homeShowHighlightControls;
  late bool _projAutoSize;
  late bool _projHCenter;
  late bool _projVCenter;
  late bool _projUseAkkord;
  late bool _projUseKotta;
  late bool _projShowBackgroundImage;
  late bool _useSound;
  late bool _projUseTitle;
  late bool _projBoldText;
  late int _desktopProjectorMonitor;
  late bool _desktopProjectorEnabled;
  late bool _internetRelayEnabled;
  late bool _localNetworkEnabled;
  late bool _castEnabled;
  late String _castDeviceId;
  late String? _liveSubtitleDeviceId;
  late String _liveSubtitleLanguage;
  late int _castPort;
  late bool _castAutoConnect;
  late Map<String, String> _desktopActionHotkeys;
  late Map<String, String> _desktopSongHotkeys;
  late Map<String, String> _desktopOrderSetHotkeys;
  late List<SongHotkeyOption> _availableSongs;
  late List<CustomOrderSetOption> _availableOrderSets;
  bool _availableSongsResolved = false;
  String _selectedSongHotkeyOptionId = '';
  bool _availableOrderSetsResolved = false;
  String _selectedOrderSetOptionId = '';
  bool _showInternetPassword = false;
  bool _internetActionRunning = false;
  late final TextEditingController _szentirasApiKey;
  void Function(void Function())? _setInternetSectionState;
  late final MqttUserApiService _userApi;
  CastService? _castService;
  late Color _bkColor;
  late Color _txtColor;
  late Color _blankColor;
  late Color _hiColor;
  String _appVersion = '-';
  String _buildNumber = '-';
  final ExportImportService _exportImportService = ExportImportService();
  bool _fileTransferRunning = false;

  String get _internetRelayUrl => webDiaVetitoUrl(_mqttUser.text);

  bool get _canShowInternetQr =>
      _internetRelayEnabled && _mqttUser.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _userApi = MqttUserApiService(
      acceptLanguageProvider: _currentAcceptLanguage,
    );
    if (!kIsWeb) {
      _castService = CastService();
      unawaited(_castService!.initialize());
    }
    _loadAppVersion();
    final AppSettings s = widget.initialSettings;
    _search = TextEditingController();
    _tcpTargets = TextEditingController(text: s.tcpTargets.join('\n'));
    _mqttUser = TextEditingController(text: s.mqttUser);
    _mqttPassword = TextEditingController(text: s.mqttPassword);
    _szentirasApiKey = TextEditingController(text: s.szentirasApiKey);
    _blankPicPath = TextEditingController(text: s.blankPicPath);
    _diaExportPath = TextEditingController(text: s.diaExportPath);
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
    _appThemeMode = s.appThemeMode.clamp(0, 1);
    _appLanguage = _isSupportedLanguage(s.appLanguage) ? s.appLanguage : '';
    _homeShowHighlightControls = s.homeShowHighlightControls;
    _projAutoSize = s.projAutoSize;
    _projHCenter = s.projHCenter;
    _projVCenter = s.projVCenter;
    _projUseAkkord = s.projUseAkkord;
    _projUseKotta = s.projUseKotta;
    _projShowBackgroundImage = s.projShowBackgroundImage;
    _useSound = s.useSound;
    _projUseTitle = s.projUseTitle;
    _projBoldText = s.projBoldText;
    _desktopProjectorMonitor = s.desktopProjectorMonitor;
    _desktopProjectorEnabled = s.desktopProjectorEnabled;
    _internetRelayEnabled = s.internetRelayEnabled;
    _localNetworkEnabled = s.tcpClientEnabled;
    _castEnabled = s.castEnabled;
    _castDeviceId = s.castDeviceId;
    _liveSubtitleDeviceId = s.liveSubtitleDeviceId;
    _liveSubtitleLanguage = s.liveSubtitleLanguage;
    _castPort = s.castPort;
    _castAutoConnect = s.castAutoConnect;
    _desktopActionHotkeys = Map<String, String>.from(s.desktopActionHotkeys);
    _desktopSongHotkeys = Map<String, String>.from(s.desktopSongHotkeys);
    _desktopOrderSetHotkeys = Map<String, String>.from(
      s.desktopOrderSetHotkeys,
    );
    _availableSongs = List<SongHotkeyOption>.from(widget.availableSongs);
    _availableSongsResolved = widget.availableSongs.isNotEmpty;
    if (_availableSongs.isNotEmpty) {
      _selectedSongHotkeyOptionId = _availableSongs.first.id;
    }
    _availableOrderSets = List<CustomOrderSetOption>.from(
      widget.availableOrderSets,
    );
    _availableOrderSetsResolved = widget.availableOrderSets.isNotEmpty;
    if (_selectedOrderSetOptionId.isEmpty && _availableOrderSets.isNotEmpty) {
      _selectedOrderSetOptionId = _availableOrderSets.first.id;
    }
    _bkColor = s.bkColor;
    _txtColor = s.txtColor;
    _blankColor = s.blankColor;
    _hiColor = s.hiColor;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openInitialSectionIfNeeded());
    });
  }

  Future<void> _openInitialSectionIfNeeded() async {
    if (!mounted) {
      return;
    }
    switch (widget.initialSection) {
      case DiatarSettingsInitialSection.internet:
        await _openInternetSettings();
        break;
      case DiatarSettingsInitialSection.localNetwork:
        await _openLocalNetworkSettings();
        break;
      case null:
        return;
    }
    if (!mounted || !widget.closeAfterInitialSectionClose) {
      return;
    }
    await Navigator.of(context).maybePop();
  }

  String? _currentAcceptLanguage() {
    final String languageCode = context.l10n.localeName.trim();
    if (languageCode.isEmpty) {
      return null;
    }
    return languageCode.split(RegExp(r'[_-]')).first;
  }

  Future<void> _loadAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      final parts = info.version.split('.');
      _appVersion = parts.length >= 2
          ? '${parts[0]}.${parts[1]}'
          : info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void dispose() {
    _castService?.dispose();
    _search.dispose();
    _tcpTargets.dispose();
    _mqttUser.dispose();
    _mqttPassword.dispose();
    _szentirasApiKey.dispose();
    _blankPicPath.dispose();
    _diaExportPath.dispose();
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
    final String query = _search.text.trim().toLowerCase();
    final String internetStatus = _internetRelayEnabled
        ? l10n.internetStatusOn
        : l10n.internetStatusOff;
    final String mqttUser = _mqttUser.text.trim().isEmpty
        ? l10n.valueNotSet
        : _mqttUser.text.trim();
    final String localNetworkStatus = _localNetworkEnabled
        ? l10n.internetStatusOn
        : l10n.internetStatusOff;
    final List<String> tcpTargets = _parseTcpTargets(_tcpTargets.text);
    final String tcpSummary = tcpTargets.isEmpty
        ? l10n.tcpNoTargets
        : l10n.tcpTargetsCount(tcpTargets.length);
    final String languageLabel = _appLanguage.trim().isEmpty
        ? l10n.languageSystem
        : _languageLabel(context, _appLanguage);
    final String themeLabel = _appThemeMode == 0
        ? l10n.themeDark
        : l10n.themeLight;
    final String blankSummary = _blankPicPath.text.trim().isEmpty
        ? l10n.valueNotSet
        : shortFriendlyPathLabel(_blankPicPath.text.trim(), l10n);
    final bool desktopHotkeysAvailable = _supportsHotkeysPlatform();
    final bool showInternet = _matches(
      query,
      'internet mqtt kozvetites felhasznalo user',
    );
    final bool showLan =
        !kIsWeb && _matches(query, 'helyi halozat tcp ip port');
    final bool showCast =
        (_castService?.isSupported ?? false) &&
        _matches(query, 'cast google cast');
    final bool showProjection = _matches(
      query,
      'vetites betu meret cim hatter opacity szinek szin',
    );
    final bool showFiles = _matches(
      query,
      'enektar fajlok dtx hatterkep hatter kep blank export import backup biztonsagi mentes zip',
    );
    final bool showGeneral = _matches(
      query,
      'altalanos tema nyelv language gorgetheto akkord kotta hatterkep szokiemeles',
    );
    final bool showSpeech = !kIsWeb && _matches(
      query,
      'beszedfelismero speech recognition mikrofon',
    );
    final bool showSystem = _matches(
      query,
      'rendszer kilepes leallas stop shutdown epstop epshutdown',
    );
    final bool showHotkeys =
        desktopHotkeysAvailable &&
        _matches(
          query,
          'gyorsbillentyu hotkey billentyu shortcut vezerles enek',
        );
    final bool showApiKeys = _matches(query, 'api kulcs key szentiras');
    final bool showImpresszum = _matches(
      query,
      'impresszum impress imprint névjegy about verzió version licenc license',
    );
    final bool anyVisible =
        showInternet ||
        showLan ||
        showCast ||
        showProjection ||
        showFiles ||
        showGeneral ||
        showSpeech ||
        showSystem ||
        showHotkeys ||
        showApiKeys ||
        showImpresszum;
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
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.settingsVersionLabel(_appVersion, _buildNumber),
                  style: Theme.of(context).textTheme.bodySmall,
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
                        l10n.settingsInternetSubtitle(internetStatus, mqttUser),
                      ),
                      onTap: _openInternetSettings,
                      description: l10n.settingsInternetDescription,
                    ),
                  if (showInternet &&
                      (showLan ||
                          showProjection ||
                          showFiles ||
                          showGeneral ||
                          showApiKeys))
                    const Divider(height: 1),
                  if (showApiKeys)
                    _settingsTile(
                      leading: const Icon(Icons.vpn_key),
                      title: Text(l10n.settingsApiKeysTitle),
                      subtitle: Text(
                        l10n.settingsApiKeysSubtitle(
                          _szentirasApiKey.text.trim().isEmpty
                              ? l10n.settingsApiKeysStatusMissing
                              : l10n.settingsApiKeysStatusSet,
                        ),
                      ),
                      onTap: _openApiKeysSettings,
                    ),
                  if (showApiKeys &&
                      (showLan || showProjection || showFiles || showGeneral))
                    const Divider(height: 1),
                  if (showLan)
                    _settingsTile(
                      leading: const Icon(Icons.lan),
                      title: Text(l10n.settingsLocalNetworkTitle),
                      subtitle: Text(
                        l10n.settingsLocalNetworkSubtitle(
                          localNetworkStatus,
                          tcpSummary,
                        ),
                      ),
                      onTap: _openLocalNetworkSettings,
                      description: l10n.settingsLocalNetworkDescription,
                    ),
                  if (showLan &&
                      (showCast || showProjection || showFiles || showGeneral))
                    const Divider(height: 1),
                  if (showCast && (_castService?.isSupported ?? false))
                    _settingsTile(
                      leading: const Icon(Icons.cast),
                      title: Text(l10n.castSettingsTitle),
                      subtitle: Text(l10n.castSettingsSummary),
                      onTap: _openCastSettings,
                      description: l10n.castSettingsDescription,
                    ),
                  if (showCast &&
                      (_castService?.isSupported ?? false) &&
                      (showProjection || showFiles || showGeneral))
                    const Divider(height: 1),
                  if (showProjection)
                    _settingsTile(
                      leading: const Icon(Icons.slideshow),
                      title: Text(l10n.projectionSettingsTitle),
                      subtitle: Text(
                        l10n.settingsProjectionSummary(
                          _projFontSize.text.trim(),
                          _projTitleSize.text.trim(),
                        ),
                      ),
                      onTap: _openProjectionSettings,
                      description: l10n.projectionSettingsDescription,
                    ),
                  if (showProjection &&
                      (showFiles || showGeneral || showSpeech || showHotkeys))
                    const Divider(height: 1),
                  if (showFiles)
                    _settingsTile(
                      leading: const Icon(Icons.folder),
                      title: Text(l10n.settingsFilesTitle),
                      subtitle: Text(l10n.settingsFilesSummary(blankSummary)),
                      onTap: _openFileSettings,
                      description: l10n.settingsFilesDescription,
                    ),
                  if (showFiles && (showGeneral || showSpeech || showHotkeys))
                    const Divider(height: 1),
                  if (showGeneral)
                    _settingsTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.settingsGeneralTitle),
                      subtitle: Text(
                        l10n.settingsGeneralSummary(themeLabel, languageLabel),
                      ),
                      onTap: _openGeneralSettings,
                      description: l10n.settingsGeneralDescription,
                    ),
                  if (showGeneral && (showSpeech || showSystem || showHotkeys))
                    const Divider(height: 1),
                  if (showSpeech)
                    _settingsTile(
                      leading: const Icon(Icons.mic),
                      title: Text(l10n.speechSettingsTitle),
                      subtitle: Text(l10n.speechSettingsSummary),
                      onTap: _openSpeechSettings,
                    ),
                  if (showSpeech && (showSystem || showHotkeys))
                    const Divider(height: 1),
                  if (showSystem)
                    _settingsTile(
                      leading: const Icon(Icons.power_settings_new),
                      title: Text(l10n.systemActionsTitle),
                      subtitle: Text(l10n.systemActionsSummary),
                      onTap: _openSystemActions,
                      description: l10n.systemActionsDescription,
                    ),
                  if (showSystem && showHotkeys) const Divider(height: 1),
                  if (showHotkeys)
                    _settingsTile(
                      leading: const Icon(Icons.keyboard_alt_outlined),
                      title: Text(l10n.settingsHotkeysTitle),
                      subtitle: Text(l10n.settingsHotkeysSummary),
                      onTap: _openDesktopHotkeySettings,
                      description: l10n.settingsHotkeysDescription,
                    ),
                  if (showHotkeys && showImpresszum) const Divider(height: 1),
                  if (showImpresszum)
                    _settingsTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.impresszumTitle),
                      subtitle: Text(l10n.impresszumSummary),
                      onTap: _openImpresszumSheet,
                      description: l10n.impresszumDescription,
                    ),
                  if (!anyVisible)
                    Padding(
                      padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.auto_stories, size: 18),
              label: Text(l10n.settingsOnboardingButton),
              onPressed: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (BuildContext bc) {
                    return OnboardingSheet(
                      onComplete: () {
                        Navigator.of(bc).pop();
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
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
    String? description,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (description != null)
            Tooltip(
              message: description,
              child: IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    content: Text(description!),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(context.l10n.ok),
                      ),
                    ],
                  ),
                ),
                padding: EdgeInsets.zero,
                splashRadius: 16,
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _openInternetSettings() {
    final bool originalInternetRelayEnabled = _internetRelayEnabled;
    final String originalMqttUser = _mqttUser.text;
    final String originalMqttPassword = _mqttPassword.text;
    final bool originalShowInternetPassword = _showInternetPassword;

    return _openSectionSheet(
      title: context.l10n.settingsInternetTitle,
      showCancelButton: true,
      onConfirmClose: _applyNetworkSettings,
      onCancel: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _internetRelayEnabled = originalInternetRelayEnabled;
          _mqttUser.text = originalMqttUser;
          _mqttPassword.text = originalMqttPassword;
          _showInternetPassword = originalShowInternetPassword;
        });
      },
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        _setInternetSectionState = setBoth;
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _internetRelayEnabled,
            onChanged: (bool v) => setBoth(() => _internetRelayEnabled = v),
            title: Text(l10n.internetRelaySwitchTitle),
          ),
          TextField(
            controller: _mqttUser,
            enabled: _internetRelayEnabled,
            onChanged: (_) => setBoth(() {}),
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _internetRelayUrl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _canShowInternetQr
                    ? () => _openInternetQrDialog(context)
                    : null,
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.internetRelayQrButton),
              ),
            ],
          ),
          TextField(
            controller: _mqttPassword,
            enabled: _internetRelayEnabled,
            obscureText: !_showInternetPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldPassword,
              suffixIcon: IconButton(
                tooltip: _showInternetPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: _internetRelayEnabled
                    ? () => setBoth(
                        () => _showInternetPassword = !_showInternetPassword,
                      )
                    : null,
                icon: Icon(
                  _showInternetPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            l10n.internetUserActionsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _registerUser,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(l10n.userActionRegister),
              ),
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _resendVerification,
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: Text(l10n.userActionResendVerification),
              ),
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _forgotPassword,
                icon: const Icon(Icons.lock_reset),
                label: Text(l10n.userActionForgotPassword),
              ),
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _deleteUser,
                icon: const Icon(Icons.person_remove_alt_1),
                label: Text(l10n.userActionDeleteUser),
              ),
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _changePassword,
                icon: const Icon(Icons.password),
                label: Text(l10n.userActionChangePassword),
              ),
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _changeEmail,
                icon: const Icon(Icons.alternate_email),
                label: Text(l10n.userActionChangeEmail),
              ),
            ],
          ),
          if (_internetActionRunning) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ];
      },
    ).whenComplete(() => _setInternetSectionState = null);
  }

  Future<void> _registerUser() async {
    final l10n = context.l10n;
    final _RegistrationInput? registration = await _askRegistrationInput(
      title: l10n.userActionRegister,
      initialUsername: _mqttUser.text.trim(),
    );
    if (registration == null) {
      return;
    }
    await _runUserApiAction(
      successMessage: l10n.userActionRegisterSuccess,
      action: () => _userApi.createUser(
        username: registration.username,
        password: registration.password,
        email: registration.email,
      ),
    );
  }

  Future<void> _resendVerification() async {
    final l10n = context.l10n;
    final _ResendVerificationInput? input = await _askResendVerificationInput(
      title: l10n.userActionResendVerification,
    );
    if (input == null) {
      return;
    }

    final String username = input.username;
    final String email = input.email;
    if (username.isEmpty || email.isEmpty) {
      await _showInternetResultDialog(l10n.userActionValidationRequiredFields);
      return;
    }
    if (!_simpleEmailPattern.hasMatch(email)) {
      await _showInternetResultDialog(l10n.userActionValidationInvalidEmail);
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionResendVerificationSuccess,
      action: () =>
          _userApi.resendVerification(username: username, email: email),
    );
  }

  Future<void> _deleteUser() async {
    final l10n = context.l10n;
    final _DeleteUserInput? input = await _askDeleteUserInput(
      title: l10n.userActionDeleteUser,
      initialUsername: _mqttUser.text.trim(),
    );
    if (input == null) {
      return;
    }

    final String username = input.username;
    final String password = input.password;
    if (username.isEmpty || password.isEmpty) {
      await _showInternetResultDialog(l10n.userActionValidationRequiredFields);
      return;
    }

    if (!mounted) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(l10n.userDeleteConfirmTitle),
              content: Text(l10n.userDeleteConfirmMessage),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.userDeleteConfirmButton),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionDeleteUserSuccess,
      action: () async {
        await _disableInternetRelayBeforeDeletingActiveSender(username);
        await _userApi.deleteUser(username: username, password: password);
      },
    );
  }

  Future<void> _disableInternetRelayBeforeDeletingActiveSender(
    String username,
  ) async {
    final String deletingUser = username.trim();
    final String senderUser = _mqttUser.text.trim();
    final bool shouldDisableRelay =
        _internetRelayEnabled &&
        deletingUser.isNotEmpty &&
        senderUser.isNotEmpty &&
        deletingUser == senderUser;
    if (!shouldDisableRelay) {
      return;
    }

    if (mounted) {
      setState(() {
        _internetRelayEnabled = false;
      });
    }

    final AppSettings relayDisabled = widget.initialSettings.copyWith(
      internetRelayEnabled: false,
      mqttUser: senderUser,
      mqttPassword: '',
      mqttChannel: '1',
    );
    await widget.onApply(relayDisabled);
  }

  Future<void> _forgotPassword() async {
    final l10n = context.l10n;
    final _ResendVerificationInput? input = await _askResendVerificationInput(
      title: l10n.userActionForgotPassword,
    );
    if (input == null) {
      return;
    }

    final String username = input.username;
    final String email = input.email;
    if (username.isEmpty || email.isEmpty) {
      await _showInternetResultDialog(l10n.userActionValidationRequiredFields);
      return;
    }
    if (!_simpleEmailPattern.hasMatch(email)) {
      await _showInternetResultDialog(l10n.userActionValidationInvalidEmail);
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionForgotPasswordSuccess,
      action: () =>
          _userApi.requestPasswordReset(username: username, email: email),
    );
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    final _ChangePasswordInput? input = await _askChangePasswordInput(
      title: l10n.userActionChangePassword,
      initialUsername: _mqttUser.text.trim(),
    );
    if (input == null) {
      return;
    }

    final String username = input.username;
    final String password = input.password;
    final String newPassword = input.newPassword;
    if (username.isEmpty || password.isEmpty || newPassword.isEmpty) {
      await _showInternetResultDialog(
        l10n.userActionValidationRequiredPasswordFields,
      );
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionChangePasswordSuccess,
      action: () => _userApi.changePassword(
        username: username,
        password: password,
        newPassword: newPassword,
      ),
    );
  }

  Future<void> _changeEmail() async {
    final l10n = context.l10n;
    final _ChangeEmailInput? input = await _askChangeEmailInput(
      title: l10n.userActionChangeEmail,
      initialValue: _mqttUser.text.trim(),
    );
    if (input == null) {
      return;
    }

    final String username = input.username;
    final String password = input.password;
    final String newEmail = input.newEmail;
    if (username.isEmpty || password.isEmpty || newEmail.isEmpty) {
      await _showInternetResultDialog(
        l10n.userActionValidationRequiredChangeEmailFields,
      );
      return;
    }

    if (!_simpleEmailPattern.hasMatch(newEmail)) {
      await _showInternetResultDialog(l10n.userActionValidationInvalidEmail);
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionChangeEmailSuccess,
      action: () => _userApi.changeEmail(
        username: username,
        password: password,
        newEmail: newEmail,
      ),
    );
  }

  Future<void> _changeUsername() async {
    final l10n = context.l10n;
    final _ChangeUsernameInput? input = await _askChangeUsernameInput(
      title: l10n.userActionChangeUsername,
      initialUsername: _mqttUser.text.trim(),
    );
    if (input == null) {
      return;
    }
    final String username = input.username;
    final String password = input.password;
    final String newUsername = input.newUsername;
    if (username.isEmpty || password.isEmpty || newUsername.isEmpty) {
      await _showInternetResultDialog(
        l10n.userActionValidationRequiredChangeUsernameFields,
      );
      return;
    }

    await _runUserApiAction(
      successMessage: l10n.userActionChangeUsernameSuccess,
      action: () => _userApi.changeUsername(
        username: username,
        password: password,
        newUsername: newUsername,
        newPassword: password,
      ),
    );
  }

  Future<_ChangeUsernameInput?> _askChangeUsernameInput({
    required String title,
    required String initialUsername,
  }) {
    return showDialog<_ChangeUsernameInput>(
      context: context,
      builder: (BuildContext context) {
        return _ChangeUsernameInputDialog(
          title: title,
          initialUsername: initialUsername,
        );
      },
    );
  }

  Future<_RegistrationInput?> _askRegistrationInput({
    required String title,
    required String initialUsername,
  }) {
    return showDialog<_RegistrationInput>(
      context: context,
      builder: (BuildContext context) {
        return _RegistrationInputDialog(
          title: title,
          initialUsername: initialUsername,
        );
      },
    );
  }

  Future<_ChangeEmailInput?> _askChangeEmailInput({
    required String title,
    required String initialValue,
  }) {
    return showDialog<_ChangeEmailInput>(
      context: context,
      builder: (BuildContext context) {
        return _ChangeEmailInputDialog(
          title: title,
          initialUsername: initialValue,
        );
      },
    );
  }

  Future<_ResendVerificationInput?> _askResendVerificationInput({
    required String title,
  }) {
    return showDialog<_ResendVerificationInput>(
      context: context,
      builder: (BuildContext context) {
        return _ResendVerificationInputDialog(title: title);
      },
    );
  }

  Future<_DeleteUserInput?> _askDeleteUserInput({
    required String title,
    required String initialUsername,
  }) {
    return showDialog<_DeleteUserInput>(
      context: context,
      builder: (BuildContext context) {
        return _DeleteUserInputDialog(
          title: title,
          initialUsername: initialUsername,
        );
      },
    );
  }

  Future<_ChangePasswordInput?> _askChangePasswordInput({
    required String title,
    required String initialUsername,
  }) {
    return showDialog<_ChangePasswordInput>(
      context: context,
      builder: (BuildContext context) {
        return _ChangePasswordInputDialog(
          title: title,
          initialUsername: initialUsername,
        );
      },
    );
  }

  Future<void> _showInternetResultDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.settingsInternetTitle),
          content: Text(message),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInternetQrDialog(BuildContext sectionContext) {
    final String url = _internetRelayUrl;
    final AppLocalizations l10n = sectionContext.l10n;
    return showModalBottomSheet<void>(
      context: sectionContext,
      isScrollControlled: true,
      useRootNavigator: false,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Theme.of(sectionContext).colorScheme.surface,
      builder: (BuildContext context) {
        final Size size = MediaQuery.sizeOf(context);
        final double maxQrWidth = (size.width - 56).clamp(140.0, 520.0);
        final double maxQrHeight = (size.height - 360).clamp(140.0, 520.0);
        final double qrSize = math.min(maxQrWidth, maxQrHeight);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.internetRelayQrTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: url,
                        version: QrVersions.auto,
                        size: qrSize,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.internetRelayQrHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.internetRelayLinkLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    url,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!mounted) {
                            return;
                          }
                          await _showInternetResultDialog(
                            l10n.internetRelayLinkCopied,
                          );
                        },
                        icon: const Icon(Icons.copy_all),
                        label: Text(l10n.internetRelayCopyLink),
                      ),
                      TextButton.icon(
                        onPressed: () => _saveInternetQrImage(sectionContext),
                        icon: const Icon(Icons.image_outlined),
                        label: Text(l10n.internetRelaySaveQrImage),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _buildInternetQrPng(String url, {double size = 1200}) {
    final QrPainter painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    return painter
        .toImageData(size, format: ui.ImageByteFormat.png)
        .then((ByteData? data) => data?.buffer.asUint8List());
  }

  String _internetQrFileName() {
    final String user = _mqttUser.text.trim();
    final String safeUser = user
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (safeUser.isEmpty) {
      return 'diavetito-qr.png';
    }
    return 'diavetito-$safeUser-qr.png';
  }

  Future<void> _saveInternetQrImage(BuildContext sectionContext) async {
    final AppLocalizations l10n = sectionContext.l10n;
    final String url = _internetRelayUrl;
    try {
      final Uint8List? png = await _buildInternetQrPng(url);
      if (png == null || png.isEmpty) {
        throw Exception('QR generation failed');
      }
      final String fileName = _internetQrFileName();
      final XFile imageFile = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: fileName,
      );
      String savedPath = fileName;

      if (kIsWeb) {
        await imageFile.saveTo(fileName);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final String? exported = await _saveInternetQrWithAndroidSystemDialog(
            fileName: fileName,
            bytes: png,
          );
          if (exported == null) {
            return;
          }
          savedPath = exported;
        } on MissingPluginException {
          savedPath = await _saveInternetQrToDocumentsDirectory(
            fileName: fileName,
            bytes: png,
          );
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        savedPath = await _saveInternetQrToDocumentsDirectory(
          fileName: fileName,
          bytes: png,
        );
      } else {
        final FileSaveLocation? location =
            await DesktopProjectorBridge.instance.runWithNativeDialog(
          () => showFileSavePanel(
            suggestedName: fileName,
            extensions: const <String>['png'],
          ),
        );
        if (location == null) {
          return;
        }
        await imageFile.saveTo(location.path);
        savedPath = location.path;
      }

      if (!sectionContext.mounted) {
        return;
      }
      await _showInternetResultDialog(
        l10n.savedPath(formatFriendlyPathLabel(savedPath, l10n)),
      );
    } catch (error) {
      if (!sectionContext.mounted) {
        return;
      }
      await _showInternetResultDialog(
        l10n.internetRelayQrSaveFailed(error.toString()),
      );
    }
  }

  Future<String?> _saveInternetQrWithAndroidSystemDialog({
    required String fileName,
    required Uint8List bytes,
  }) {
    return _androidBackupSaveChannel.invokeMethod<String>(
      'saveDiaFile',
      <String, Object?>{'fileName': fileName, 'bytes': bytes},
    );
  }

  Future<String> _saveInternetQrToDocumentsDirectory({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final String documentsPath = await PathHelper.getDocumentsDirectoryPath();
    final String exportPath = '$documentsPath/diatar/$fileName';
    final File exportFile = FileSystemProvider.instance.file(exportPath);
    await exportFile.parent.create(recursive: true);
    await exportFile.writeAsBytes(bytes, flush: true);
    return exportPath;
  }

  Future<void> _runUserApiAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_internetActionRunning) {
      return;
    }
    _setInternetActionRunning(true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      await _showInternetResultDialog(successMessage);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final AppLocalizations l10n = context.l10n;
      await _showInternetResultDialog(
        l10n.userApiError(_mapUserApiErrorMessage(error: e, l10n: l10n)),
      );
    } finally {
      _setInternetActionRunning(false);
    }
  }

  String _mapUserApiErrorMessage({
    required Object error,
    required AppLocalizations l10n,
  }) {
    if (error is MqttUserApiException) {
      if (error.statusCode == 401) {
        return l10n.userApiUnauthorized;
      }
      return error.message.trim().isEmpty
          ? l10n.userApiUnknownError
          : error.message;
    }

    final String message = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
    if (message.isEmpty) {
      return l10n.userApiUnknownError;
    }
    return message;
  }

  void _setInternetActionRunning(bool value) {
    final void Function(void Function())? setInternetSectionState =
        _setInternetSectionState;
    if (setInternetSectionState != null) {
      setInternetSectionState(() => _internetActionRunning = value);
      return;
    }
    if (mounted) {
      setState(() => _internetActionRunning = value);
    }
  }

  Future<void> _openLocalNetworkSettings() {
    final bool originalLocalNetworkEnabled = _localNetworkEnabled;
    final String originalTcpTargets = _tcpTargets.text;

    return _openSectionSheet(
      title: context.l10n.settingsLocalNetworkTitle,
      isDismissible: false,
      enableDrag: false,
      showCancelButton: true,
      onConfirmClose: _applyNetworkSettings,
      onCancel: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _localNetworkEnabled = originalLocalNetworkEnabled;
          _tcpTargets.text = originalTcpTargets;
        });
      },
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _localNetworkEnabled,
            onChanged: (bool v) => setBoth(() => _localNetworkEnabled = v),
            title: Text(l10n.localNetworkRelaySwitchTitle),
          ),
          TextField(
            controller: _tcpTargets,
            enabled: _localNetworkEnabled,
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.tcpTargetsLabel,
              hintText: l10n.tcpTargetsHint,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tcpTargetsHelp,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      },
    );
  }

  bool _applyNetworkSettings() {
    final String mqttUser = _mqttUser.text.trim();
    final String mqttPassword = _internetRelayEnabled ? _mqttPassword.text : '';
    final List<String> tcpTargets = kIsWeb
        ? const <String>[]
        : _parseTcpTargets(_tcpTargets.text);
    final bool localNetworkEnabled = kIsWeb ? false : _localNetworkEnabled;
    final String? tcpError = localNetworkEnabled
        ? _validateTcpTargets(tcpTargets)
        : null;
    if (tcpError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tcpError)));
      return false;
    }
    _tcpTargets.text = tcpTargets.join('\n');

    final int firstPort = localNetworkEnabled
        ? (_firstPortFromTargets(tcpTargets) ?? widget.initialSettings.port)
        : widget.initialSettings.port;

    final AppSettings updated = widget.initialSettings.copyWith(
      port: firstPort,
      tcpClientEnabled: localNetworkEnabled,
      tcpTargets: tcpTargets,
      internetRelayEnabled: _internetRelayEnabled,
      mqttUser: mqttUser,
      mqttPassword: mqttPassword,
      mqttChannel: '1',
    );

    unawaited(_applySettingsSafely(updated));
    return true;
  }

  Future<void> _openApiKeysSettings() {
    final String originalSzentirasApiKey = _szentirasApiKey.text;

    return _openSectionSheet(
      title: context.l10n.settingsApiKeysTitle,
      showCancelButton: true,
      onConfirmClose: _applyApiKeysSettings,
      onCancel: () {
        if (!mounted) {
          return;
        }
        setState(() {
          _szentirasApiKey.text = originalSzentirasApiKey;
        });
      },
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          TextField(
            controller: _szentirasApiKey,
            onChanged: (_) => setBoth(() {}),
            decoration: InputDecoration(
              labelText: l10n.settingsSzentirasApiKeyLabel,
              hintText: l10n.settingsSzentirasApiKeyHint,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.szentirasApiKeyHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      },
    );
  }

  bool _applyApiKeysSettings() {
    final AppSettings updated = widget.initialSettings.copyWith(
      szentirasApiKey: _szentirasApiKey.text.trim(),
    );

    unawaited(_applySettingsSafely(updated));
    return true;
  }

  Future<void> _openGeneralSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsGeneralTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          DropdownButtonFormField<int>(
            initialValue: _appThemeMode,
            decoration: InputDecoration(labelText: l10n.uiTheme),
            items: <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(value: 0, child: Text(l10n.themeDark)),
              DropdownMenuItem<int>(value: 1, child: Text(l10n.themeLight)),
            ],
            onChanged: (int? v) => setBoth(() => _appThemeMode = v ?? 0),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useSound,
            onChanged: (bool v) => setBoth(() => _useSound = v),
            title: Text(l10n.useSound),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: !_projAutoSize,
            onChanged: (bool v) => setBoth(() => _projAutoSize = !v),
            title: Text(l10n.scrollableProjection),
            subtitle: Text(l10n.scrollableProjectionHint),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projUseAkkord,
            onChanged: (bool v) => setBoth(() => _projUseAkkord = v),
            title: Text(l10n.showChords),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projUseKotta,
            onChanged: (bool v) => setBoth(() => _projUseKotta = v),
            title: Text(l10n.showKotta),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projShowBackgroundImage,
            onChanged: (bool v) => setBoth(() => _projShowBackgroundImage = v),
            title: Text(l10n.showBackgroundImage),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _homeShowHighlightControls,
            onChanged: (bool v) =>
                setBoth(() => _homeShowHighlightControls = v),
            title: Text(l10n.wordHighlight),
          ),
        ];
      },
    );
  }

  Future<void> _openSystemActions() {
    return _openSectionSheet(
      title: context.l10n.systemActionsTitle,
      closeButtonLabel: context.l10n.systemActionsBack,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: widget.onExitRequested,
                child: Text(l10n.localExit),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (mounted) {
                    Navigator.of(this.context).pop();
                  }
                  widget.onReloadBooksRequested();
                },
                child: Text(l10n.refreshTooltip),
              ),
              OutlinedButton(
                onPressed: widget.onRemoteStopRequested,
                child: Text(l10n.remoteProgramStop),
              ),
              OutlinedButton(
                onPressed: widget.onRemoteShutdownRequested,
                child: Text(l10n.remoteMachineStop),
              ),
            ],
          ),
        ];
      },
    );
  }

  Future<void> _openCastSettings() {
    return _openSectionSheet(
      title: context.l10n.castSettingsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _castEnabled,
            onChanged: (bool v) => setBoth(() => _castEnabled = v),
            title: Text(l10n.castEnabledTitle),
          ),
          if (_castEnabled) ...<Widget>[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text(l10n.castSelectDeviceTitle),
              subtitle: Text(
                _castDeviceId.isEmpty ? l10n.valueNotSet : 'ID: $_castDeviceId',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openCastDeviceSelector(setBoth),
            ),
            const Divider(height: 1),
            TextField(
              controller: TextEditingController(text: _castDeviceId),
              decoration: InputDecoration(labelText: l10n.castDeviceIdLabel),
              onChanged: (v) => setBoth(() => _castDeviceId = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _castPort.toString()),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.castPortLabel),
              onChanged: (v) =>
                  setBoth(() => _castPort = int.tryParse(v) ?? 1024),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _castAutoConnect,
              onChanged: (bool v) => setBoth(() => _castAutoConnect = v),
              title: Text(l10n.castAutoConnectTitle),
            ),
          ],
        ];
      },
    );
  }

  Future<void> _openCastDeviceSelector(
    void Function(void Function()) setBoth,
  ) async {
    final l10n = context.l10n;

    await _openSectionSheet(
      title: l10n.castSelectDeviceTitle,
      builder:
          (BuildContext context, void Function(void Function()) setModalState) {
            return [
              AnimatedBuilder(
                animation: _castService ?? ValueNotifier<bool>(false),
                builder: (context, _) {
                  final devices =
                      _castService?.discoveredDevices ?? <GoogleCastDevice>[];
                  if (devices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.castNoDevicesFound),
                          TextButton(
                            onPressed: () => _castService?.startDiscovery(),
                            child: Text(l10n.refreshTooltip),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        leading: const Icon(Icons.cast),
                        title: Text(device.friendlyName),
                        subtitle: Text(device.deviceID),
                        onTap: () async {
                          setBoth(() {}); // Update main sheet
                          try {
                            await _castService?.connectToDevice(device);
                            setBoth(() {
                              _castDeviceId = device.deviceID;
                            });
                            Navigator.of(context).pop(true);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connection failed: $e')),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ];
          },
    ).then((_) {
      _castService?.stopDiscovery();
    });

    // Start discovery when opening
    _castService?.startDiscovery();
  }

  Future<void> _openMicDeviceSelector(
    void Function(void Function()) setBoth,
  ) async {
    final l10n = context.l10n;
    final RecordAudioCapture capture = RecordAudioCapture();
    try {
      final bool hasPerm = await capture.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.liveSubtitlesError)),
          );
        }
        return;
      }
      final List<InputDevice> devices = await capture.listInputDevices();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return SimpleDialog(
            title: Text(l10n.liveSubtitlesMicDevice),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  setBoth(() => _liveSubtitleDeviceId = null);
                  Navigator.of(dialogContext).pop();
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      _liveSubtitleDeviceId == null
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.liveSubtitlesMicDeviceDefault)),
                  ],
                ),
              ),
              for (final InputDevice device in devices)
                SimpleDialogOption(
                  onPressed: () {
                    setBoth(() => _liveSubtitleDeviceId = device.id);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _liveSubtitleDeviceId == device.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(device.label)),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('[Settings] Failed to list mic devices: $e');
    } finally {
      await capture.dispose();
    }
  }

  Future<void> _openSpeechSettings() {
    return _openSectionSheet(
      title: context.l10n.speechSettingsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mic),
            title: Text(l10n.liveSubtitlesMicDevice),
            subtitle: Text(
              _liveSubtitleDeviceId == null
                  ? l10n.liveSubtitlesMicDeviceDefault
                  : _liveSubtitleDeviceId!,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openMicDeviceSelector(setBoth),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language),
            title: Text(l10n.speechLanguageTitle),
            subtitle: Text(_speechLanguageName(_liveSubtitleLanguage, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openLanguageSelector(setBoth),
          ),
          const Divider(height: 1),
        ];
      },
    );
  }

  static const _speechLanguageCodes = <String>[
    'auto', 'es-US', 'es-ES', 'it-IT', 'pt-BR', 'pt-PT', 'hi-IN', 'ko-KR',
    'en-US', 'en-GB', 'de-DE', 'fr-FR', 'fr-CA', 'ru-RU', 'tr-TR', 'vi-VN',
    'nl-NL', 'ja-JP', 'ar-AR', 'uk-UA', 'pl-PL', 'nb-NO', 'fi-FI', 'zh-CN',
    'cs-CZ', 'bg-BG', 'sk-SK', 'sv-SE', 'hr-HR', 'ro-RO', 'et-EE', 'da-DK',
    'hu-HU',
  ];

  String _speechLanguageName(String code, AppLocalizations l10n) {
    switch (code) {
      case 'auto': return l10n.speechLangAuto;
      case 'es-US': return l10n.speechLangEsUS;
      case 'es-ES': return l10n.speechLangEsES;
      case 'it-IT': return l10n.speechLangItIT;
      case 'pt-BR': return l10n.speechLangPtBR;
      case 'pt-PT': return l10n.speechLangPtPT;
      case 'hi-IN': return l10n.speechLangHiIN;
      case 'ko-KR': return l10n.speechLangKoKR;
      case 'en-US': return l10n.speechLangEnUS;
      case 'en-GB': return l10n.speechLangEnGB;
      case 'de-DE': return l10n.speechLangDeDE;
      case 'fr-FR': return l10n.speechLangFrFR;
      case 'fr-CA': return l10n.speechLangFrCA;
      case 'ru-RU': return l10n.speechLangRuRU;
      case 'tr-TR': return l10n.speechLangTrTR;
      case 'vi-VN': return l10n.speechLangViVN;
      case 'nl-NL': return l10n.speechLangNlNL;
      case 'ja-JP': return l10n.speechLangJaJP;
      case 'ar-AR': return l10n.speechLangArAR;
      case 'uk-UA': return l10n.speechLangUkUA;
      case 'pl-PL': return l10n.speechLangPlPL;
      case 'nb-NO': return l10n.speechLangNbNO;
      case 'fi-FI': return l10n.speechLangFiFI;
      case 'zh-CN': return l10n.speechLangZhCN;
      case 'cs-CZ': return l10n.speechLangCsCZ;
      case 'bg-BG': return l10n.speechLangBgBG;
      case 'sk-SK': return l10n.speechLangSkSK;
      case 'sv-SE': return l10n.speechLangSvSE;
      case 'hr-HR': return l10n.speechLangHrHR;
      case 'ro-RO': return l10n.speechLangRoRO;
      case 'et-EE': return l10n.speechLangEtEE;
      case 'da-DK': return l10n.speechLangDaDK;
      case 'hu-HU': return l10n.speechLangHuHU;
      default: return code;
    }
  }

  Future<void> _openLanguageSelector(
    void Function(void Function()) setBoth,
  ) {
    final l10n = context.l10n;
    return _openSectionSheet(
      title: l10n.speechLanguageTitle,
      builder: (BuildContext context, void Function(void Function()) setModalBoth) {
        return <Widget>[
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.speechLangAuto),
            value: 'auto',
            groupValue: _liveSubtitleLanguage,
            onChanged: (String? v) {
              if (v != null) {
                setBoth(() => _liveSubtitleLanguage = v);
                setModalBoth(() {});
              }
            },
          ),
          for (final code in _speechLanguageCodes)
            if (code != 'auto')
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: Text(_speechLanguageName(code, l10n)),
                value: code,
                groupValue: _liveSubtitleLanguage,
                onChanged: (String? v) {
                  if (v != null) {
                    setBoth(() => _liveSubtitleLanguage = v);
                    setModalBoth(() {});
                  }
                },
              ),
        ];
      },
    );
  }

  Future<void> _openImpresszumSheet() {
    final l10n = context.l10n;
    return _openSectionSheet(
      title: l10n.impresszumTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        return <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.asset(
                'assets/hackathon_logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _impresszumSection(
            l10n.impresszumDevelopers,
            l10n.impresszumDevelopersBody,
          ),
          _impresszumLink(
            label: l10n.impresszumHackathonTitle,
            subtitle: l10n.impresszumHackathonBody,
            url: 'https://szentjozsef.jezsuita.hu/szent-jozsef-hackathon/',
          ),
          const Divider(height: 1),
          _impresszumSection(
            l10n.impresszumDataSources,
            l10n.impresszumSzentiras,
          ),
          _impresszumLink(
            label: l10n.impresszumSzentirasLink,
            subtitle: 'szentiras.eu',
            url: 'https://szentiras.eu',
          ),
          const Divider(height: 1),
          _impresszumSection(
            l10n.impresszumLicenses,
            null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.impresszumNemotron),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.impresszumSherpaOnnx),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.impresszumFlutter),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.impresszumRecord),
          ),
          const Divider(height: 1),
          _impresszumSection(
            l10n.impresszumLinks,
            null,
          ),
          _impresszumLink(
            label: l10n.impresszumWebsite,
            subtitle: 'diatar.eu',
            url: 'https://www.diatar.eu',
          ),
          _impresszumLink(
            label: l10n.impresszumGitHub,
            subtitle: 'github.com/diatar-eu/diatar-flutter',
            url: 'https://github.com/diatar-eu/diatar-flutter',
          ),
          _impresszumLink(
            label: l10n.impresszumHackathonLink,
            subtitle: 'szentjozsef.jezsuita.hu',
            url: 'https://szentjozsef.jezsuita.hu/szent-jozsef-hackathon/',
          ),
        ];
      },
    );
  }

  Widget _impresszumSection(String title, String? body) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _impresszumLink({
    required String label,
    required String subtitle,
    required String url,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }

  Future<void> _openFileSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsFilesTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          _buildPathPickerRow(
            l10n: l10n,
            label: l10n.blankImagePath,
            rawPath: _blankPicPath.text.trim(),
            onPick: () async {
              await _pickBlankFile();
              setBoth(() {});
            },
            onClear: () {
              _clearBlankImage();
              setBoth(() {});
            },
          ),
          if (_isDesktopPlatform())
            _buildPathPickerRow(
              l10n: l10n,
              label: l10n.diaExportFolderPath,
              rawPath: _diaExportPath.text.trim(),
              onPick: () async {
                await _pickDiaExportFolder();
                setBoth(() {});
              },
            ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            l10n.diatarDataTransferTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.diatarDataTransferDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _fileTransferRunning
                    ? null
                    : () => _exportDiatarData(context, setBoth),
                icon: const Icon(Icons.archive_outlined),
                label: Text(l10n.diatarExportButton),
              ),
              OutlinedButton.icon(
                onPressed: _fileTransferRunning
                    ? null
                    : () => _importDiatarData(context, setBoth),
                icon: const Icon(Icons.unarchive_outlined),
                label: Text(l10n.diatarImportButton),
              ),
            ],
          ),
          if (_fileTransferRunning) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          if (_isDesktopPlatform())
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open),
              title: Text(l10n.openDtxFolder),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openDtxFolder,
            ),
        ];
      },
    );
  }

  Future<void> _exportDiatarData(
    BuildContext sectionContext,
    void Function(void Function()) setBoth,
  ) async {
    setBoth(() => _fileTransferRunning = true);
    String? tempExportDir;
    // A vezérlőablakot előrehozzuk, hogy a (macOS-on `runModal` alapú)
    // mentési panel megbízhatóan megjelenhessen; a vetítőablak jelenléte
    // nem zavarja, mivel a panel a fájlpárbeszédablak felett jelenik meg.
    await DesktopProjectorBridge.instance.prepareForNativeDialog();
    try {
      final String fileName = _backupFileName(DateTime.now());

      if (kIsWeb) {
        final Uint8List zipData = await _exportImportService.createExportArchive();
        final XFile exportFile = XFile.fromData(
          zipData,
          mimeType: 'application/zip',
          name: fileName,
        );
        await exportFile.saveTo(fileName);
      } else {
        final String zipPath =
            await _exportImportService.createExportArchiveFile();
        tempExportDir = FileSystemProvider.instance.file(zipPath).parent.path;
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            final String? savedPath =
                await _saveDiatarBackupWithAndroidSystemDialog(
                  fileName: fileName,
                  sourcePath: zipPath,
                );
            if (savedPath == null) {
              return;
            }
          } on MissingPluginException {
            await _saveDiatarBackupToDocumentsDirectory(
              fileName: fileName,
              sourcePath: zipPath,
            );
          }
        } else {
          final FileSaveLocation? location = await showFileSavePanel(
            suggestedName: fileName,
            extensions: const <String>['zip'],
          );
          if (location == null) {
            return;
          }
          await FileSystemProvider.instance.file(zipPath).copy(location.path);
        }
      }

      if (sectionContext.mounted) {
        ScaffoldMessenger.of(sectionContext).showSnackBar(
          SnackBar(
            content: Text(sectionContext.l10n.diatarExportSuccess(fileName)),
          ),
        );
      }
    } catch (error) {
      if (sectionContext.mounted) {
        await _showFileTransferError(sectionContext, error);
      }
    } finally {
      if (tempExportDir != null) {
        try {
          final Directory tempDir =
              FileSystemProvider.instance.directory(tempExportDir);
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {
          // Ignore temp cleanup failures.
        }
      }
      // A fájlművelet (mentési panel, másolás) végeztével visszaállítjuk
      // a vezérlőablak fókuszát és a vetítőablak megjelenését.
      await DesktopProjectorBridge.instance.releaseFromNativeDialog();
      _finishFileTransfer(sectionContext.mounted, setBoth);
    }
  }

  Future<String?> _saveDiatarBackupWithAndroidSystemDialog({
    required String fileName,
    required String sourcePath,
  }) {
    return _androidBackupSaveChannel.invokeMethod<String>(
      'saveBackupFile',
      <String, Object?>{'fileName': fileName, 'path': sourcePath},
    );
  }

  Future<void> _saveDiatarBackupToDocumentsDirectory({
    required String fileName,
    required String sourcePath,
  }) async {
    final String documentsPath = await PathHelper.getDocumentsDirectoryPath();
    final String exportPath = '$documentsPath/diatar/$fileName';
    final File exportFile = FileSystemProvider.instance.file(exportPath);
    await exportFile.parent.create(recursive: true);
    await FileSystemProvider.instance.file(sourcePath).copy(exportPath);
  }

  Future<void> _importDiatarData(
    BuildContext sectionContext,
    void Function(void Function()) setBoth,
  ) async {
    String? tempArchivePath;
    setBoth(() => _fileTransferRunning = true);
    try {
      final List<XFile> selectedFiles =
          await DesktopProjectorBridge.instance.runWithNativeDialog(
        () => showFileOpenPanel(
          extensions: const <String>['zip'],
        ),
      );
      final XFile? selectedFile =
          selectedFiles.isEmpty ? null : selectedFiles.first;
      if (selectedFile == null) {
        return;
      }

      final String selectedPath = selectedFile.path.trim();
      final bool hasDirectPath =
          !kIsWeb && selectedPath.isNotEmpty && !selectedPath.contains('://');

      Uint8List? zipData;
      final String? importPath;
      if (kIsWeb) {
        importPath = null;
        zipData = await selectedFile.readAsBytes();
      } else if (hasDirectPath) {
        importPath = selectedPath;
      } else {
        final File tempArchive = await _createTempImportArchive(selectedFile);
        tempArchivePath = tempArchive.path;
        importPath = tempArchive.path;
      }

      final DiatarImportPreview preview = importPath != null
          ? await _exportImportService.inspectImportArchiveFile(importPath)
          : await _exportImportService.inspectImportArchive(zipData!);
      ExistingFilePolicy policy = ExistingFilePolicy.skip;
      if (preview.conflictingFileCount > 0) {
        if (!sectionContext.mounted) {
          return;
        }
        final ExistingFilePolicy? selectedPolicy = await _askExistingFilePolicy(
          sectionContext,
          preview.conflictingFileCount,
        );
        if (selectedPolicy == null) {
          return;
        }
        policy = selectedPolicy;
      }

      final DiatarImportResult result = importPath != null
          ? await _exportImportService.importArchiveFile(
              importPath,
              existingFilePolicy: policy,
            )
          : await _exportImportService.importArchive(
              zipData!,
              existingFilePolicy: policy,
            );

      if (result.importedFileCount > 0) {
        widget.onReloadBooksRequested();
      }
      if (!sectionContext.mounted) {
        return;
      }

      if (result.isSuccess) {
        ScaffoldMessenger.of(sectionContext).showSnackBar(
          SnackBar(
            content: Text(
              sectionContext.l10n.diatarImportSuccess(
                result.importedFileCount,
                result.skippedFileCount,
              ),
            ),
          ),
        );
      } else {
        await _showFileTransferError(sectionContext, result.errors.join('\n'));
      }
    } catch (error) {
      if (sectionContext.mounted) {
        await _showFileTransferError(sectionContext, error);
      }
    } finally {
      if (tempArchivePath != null) {
        final File tempArchive = FileSystemProvider.instance.file(
          tempArchivePath,
        );
        if (await tempArchive.exists()) {
          await tempArchive.delete();
        }
      }
      _finishFileTransfer(sectionContext.mounted, setBoth);
    }
  }

  Future<File> _createTempImportArchive(XFile selectedFile) async {
    final FileSystem fs = FileSystemProvider.instance;
    final Directory tempDir = fs.systemTempDirectory;
    await tempDir.create(recursive: true);
    final String tempPath = fs.path.join(
      tempDir.path,
      'diatar-import-${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    final File tempFile = fs.file(tempPath);
    final sink = tempFile.openWrite();
    await for (final chunk in selectedFile.openRead()) {
      sink.add(chunk);
    }
    await sink.close();
    return tempFile;
  }

  Future<ExistingFilePolicy?> _askExistingFilePolicy(
    BuildContext sectionContext,
    int conflictCount,
  ) {
    final AppLocalizations l10n = sectionContext.l10n;
    return showDialog<ExistingFilePolicy>(
      context: sectionContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.diatarImportConflictTitle),
          content: Text(l10n.diatarImportConflictMessage(conflictCount)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ExistingFilePolicy.skip),
              child: Text(l10n.diatarImportSkipAll),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(ExistingFilePolicy.overwrite),
              child: Text(l10n.diatarImportOverwriteAll),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFileTransferError(
    BuildContext sectionContext,
    Object error,
  ) async {
    if (!sectionContext.mounted) {
      return;
    }
    final AppLocalizations l10n = sectionContext.l10n;
    final String message;
    if (error is DiatarArchiveException) {
      message = switch (error.code) {
        DiatarArchiveErrorCode.sourceDirectoryMissing =>
          l10n.diatarExportSourceMissing,
        DiatarArchiveErrorCode.invalidArchive =>
          l10n.diatarImportInvalidArchive,
      };
    } else {
      message = l10n.diatarTransferError(error.toString());
    }

    await showDialog<void>(
      context: sectionContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.diatarDataTransferTitle),
          content: SingleChildScrollView(child: Text(message)),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  void _finishFileTransfer(
    bool sectionMounted,
    void Function(void Function()) setBoth,
  ) {
    if (sectionMounted) {
      setBoth(() => _fileTransferRunning = false);
    } else if (mounted) {
      setState(() => _fileTransferRunning = false);
    } else {
      _fileTransferRunning = false;
    }
  }

  String _backupFileName(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'diatar-backup-'
        '${timestamp.year}${twoDigits(timestamp.month)}'
        '${twoDigits(timestamp.day)}-'
        '${twoDigits(timestamp.hour)}${twoDigits(timestamp.minute)}.zip';
  }

  Future<void> _openDtxFolder() async {
    if (kIsWeb) {
      // On web, we can't open the file system folder.
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.openDtxFolderTooltip)),
      );
      return;
    }
    final String docsPath = await PathHelper.getDocumentsDirectoryPath();
    final Directory diatarsDir = FileSystemProvider.instance.directory(
      '$docsPath/diatar',
    );
    if (!await diatarsDir.exists()) {
      await diatarsDir.create(recursive: true);
    }
    final Uri uri = Uri.file(diatarsDir.path);
    if (!await launchUrl(uri)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.openDtxFolderTooltip)),
      );
    }
  }

  Widget _buildPathPickerRow({
    required AppLocalizations l10n,
    required String label,
    required String rawPath,
    String? helperText,
    required Future<void> Function() onPick,
    VoidCallback? onClear,
  }) {
    final String trimmed = rawPath.trim();
    final String friendly = trimmed.isEmpty
        ? l10n.valueNotSet
        : formatFriendlyPathLabel(trimmed, l10n);
    return Row(
      children: <Widget>[
        Expanded(
          child: TextFormField(
            key: ValueKey<String>('path_$label|$trimmed'),
            initialValue: friendly,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              helperText: helperText,
            ),
          ),
        ),
        if (onClear != null && trimmed.isNotEmpty)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.blankImageDelete,
          ),
        IconButton(
          onPressed: () async {
            await onPick();
          },
          icon: const Icon(Icons.folder_open),
          tooltip: l10n.fileChoose,
        ),
      ],
    );
  }

  Future<void> _openDesktopHotkeySettings() {
    return _openSectionSheet(
      title: context.l10n.settingsDesktopHotkeysTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final AppLocalizations l10n = context.l10n;
        final List<MapEntry<String, String>> actions =
            <MapEntry<String, String>>[
              MapEntry<String, String>(
                'prevSong',
                l10n.settingsHotkeyActionPrevSong,
              ),
              MapEntry<String, String>(
                'prevVerse',
                l10n.settingsHotkeyActionPrevVerse,
              ),
              MapEntry<String, String>(
                'toggleProjection',
                l10n.settingsHotkeyActionToggleProjection,
              ),
              MapEntry<String, String>(
                'nextVerse',
                l10n.settingsHotkeyActionNextVerse,
              ),
              MapEntry<String, String>(
                'nextSong',
                l10n.settingsHotkeyActionNextSong,
              ),
              MapEntry<String, String>(
                'prevOrderSet',
                l10n.settingsHotkeyActionPrevOrderSet,
              ),
              MapEntry<String, String>(
                'nextOrderSet',
                l10n.settingsHotkeyActionNextOrderSet,
              ),
              MapEntry<String, String>(
                'highlightPrev',
                l10n.settingsHotkeyActionHighlightPrev,
              ),
              MapEntry<String, String>(
                'highlightNext',
                l10n.settingsHotkeyActionHighlightNext,
              ),
              MapEntry<String, String>(
                'togglePhoto',
                l10n.settingsHotkeyActionTogglePhoto,
              ),
              MapEntry<String, String>(
                'toggleChords',
                l10n.settingsHotkeyActionToggleChords,
              ),
              MapEntry<String, String>(
                'toggleBackground',
                l10n.settingsHotkeyActionToggleBackground,
              ),
              MapEntry<String, String>(
                'toggleSheetMusic',
                l10n.settingsHotkeyActionToggleSheetMusic,
              ),
            ];

        return <Widget>[
          Text(
            l10n.settingsHotkeysActionsSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...actions.map((MapEntry<String, String> entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            _desktopActionHotkeys[entry.key] ??
                                '(${l10n.valueNotSet})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final String? captured =
                              await _showHotkeyCaptureDialog(context);
                          if (captured != null) {
                            setBoth(() {
                              _desktopActionHotkeys[entry.key] = captured;
                            });
                          }
                        },
                        icon: const Icon(Icons.keyboard),
                        label: Text(l10n.settingsHotkeyCapture),
                      ),
                      const SizedBox(width: 8),
                      if (_desktopActionHotkeys[entry.key] != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.settingsHotkeyClear,
                          onPressed: () {
                            setBoth(() {
                              _desktopActionHotkeys.remove(entry.key);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          Text(
            l10n.settingsHotkeysSongsSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_availableSongsResolved && _availableSongs.isEmpty)
            Text(l10n.settingsHotkeysNoSongs),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_outlined),
            title: Text(l10n.songLabel),
            subtitle: Text(
              _selectedSongHotkeyOptionId.isEmpty
                  ? l10n.valueNotSet
                  : _songLabelForId(_selectedSongHotkeyOptionId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                final SongHotkeyOption? selected = await _pickSongHotkeyOption(
                  context,
                );
                if (selected == null) {
                  return;
                }
                setBoth(() {
                  _selectedSongHotkeyOptionId = selected.id;
                });
              },
              icon: const Icon(Icons.search),
              label: Text(l10n.fileChoose),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _selectedSongHotkeyOptionId.isEmpty
                  ? null
                  : () async {
                      final String? captured = await _showHotkeyCaptureDialog(
                        context,
                      );
                      if (captured != null) {
                        setBoth(() {
                          _desktopSongHotkeys[captured] =
                              _selectedSongHotkeyOptionId;
                        });
                      }
                    },
              icon: const Icon(Icons.keyboard),
              label: Text(l10n.settingsHotkeyCapture),
            ),
          ),
          if (_desktopSongHotkeys.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ..._desktopSongHotkeys.entries.map((
              MapEntry<String, String> entry,
            ) {
              final String label = _songLabelForId(entry.value);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Text(label),
                trailing: IconButton(
                  tooltip: l10n.settingsHotkeyDelete,
                  onPressed: () {
                    setBoth(() {
                      _desktopSongHotkeys.remove(entry.key);
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            }),
          ],
          const Divider(height: 20),
          Text(
            l10n.settingsDesktopOrderSetHotkeysTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_availableOrderSetsResolved && _availableOrderSets.isEmpty)
            Text(l10n.settingsHotkeysNoOrderSets),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.list),
            title: Text(l10n.settingsOrderSetLabel),
            subtitle: Text(
              _selectedOrderSetOptionId.isEmpty
                  ? l10n.valueNotSet
                  : _orderSetLabelForId(_selectedOrderSetOptionId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                final CustomOrderSetOption? selected =
                    await _pickOrderSetOption(context);
                if (selected == null) {
                  return;
                }
                setBoth(() {
                  _selectedOrderSetOptionId = selected.id;
                });
              },
              icon: const Icon(Icons.search),
              label: Text(l10n.fileChoose),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _selectedOrderSetOptionId.isEmpty
                  ? null
                  : () async {
                      final String? captured = await _showHotkeyCaptureDialog(
                        context,
                      );
                      if (captured != null) {
                        setBoth(() {
                          _desktopOrderSetHotkeys[captured] =
                              _selectedOrderSetOptionId;
                        });
                      }
                    },
              icon: const Icon(Icons.keyboard),
              label: Text(l10n.settingsHotkeyCapture),
            ),
          ),
          if (_desktopOrderSetHotkeys.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ..._desktopOrderSetHotkeys.entries.map((
              MapEntry<String, String> entry,
            ) {
              final String label = _orderSetLabelForId(entry.value);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: Text(label),
                trailing: IconButton(
                  tooltip: l10n.settingsHotkeyDelete,
                  onPressed: () {
                    setBoth(() {
                      _desktopOrderSetHotkeys.remove(entry.key);
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            }),
          ],
        ];
      },
    );
  }

  void _ensureAvailableSongsLoaded() {
    if (_availableSongsResolved) {
      return;
    }
    _availableSongsResolved = true;
    final List<SongHotkeyOption> loaded =
        widget.availableSongsLoader?.call() ?? const <SongHotkeyOption>[];
    _availableSongs = loaded;
    if (_selectedSongHotkeyOptionId.isEmpty && _availableSongs.isNotEmpty) {
      _selectedSongHotkeyOptionId = _availableSongs.first.id;
    }
  }

  Future<SongHotkeyOption?> _pickSongHotkeyOption(BuildContext context) async {
    _ensureAvailableSongsLoaded();
    if (_availableSongs.isEmpty) {
      return null;
    }

    final AppLocalizations l10n = context.l10n;
    final TextEditingController search = TextEditingController();
    final List<String> lowerLabels = _availableSongs
        .map((SongHotkeyOption option) => option.label.toLowerCase())
        .toList(growable: false);
    List<int> filteredIndexes = List<int>.generate(
      _availableSongs.length,
      (int i) => i,
      growable: true,
    );

    final SongHotkeyOption? selected = await showDialog<SongHotkeyOption>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setStateDialog,
              ) {
                void applyFilter(String query) {
                  final String normalized = query.trim().toLowerCase();
                  if (normalized.isEmpty) {
                    setStateDialog(() {
                      filteredIndexes = List<int>.generate(
                        _availableSongs.length,
                        (int i) => i,
                        growable: true,
                      );
                    });
                    return;
                  }
                  setStateDialog(() {
                    final List<int> matches = <int>[];
                    for (int i = 0; i < lowerLabels.length; i++) {
                      if (lowerLabels[i].contains(normalized)) {
                        matches.add(i);
                      }
                    }
                    filteredIndexes = matches;
                  });
                }

                return AlertDialog(
                  title: Text(l10n.songLabel),
                  content: SizedBox(
                    width: 520,
                    height: 420,
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: search,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l10n.settingsSearchLabel,
                          ),
                          onChanged: applyFilter,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemExtent: 40,
                            itemCount: filteredIndexes.length,
                            itemBuilder: (BuildContext context, int index) {
                              final SongHotkeyOption option =
                                  _availableSongs[filteredIndexes[index]];
                              return InkWell(
                                onTap: () => Navigator.of(context).pop(option),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      option.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                );
              },
        );
      },
    );

    search.dispose();
    return selected;
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  bool _supportsHotkeysPlatform() {
    return kIsWeb || _isDesktopPlatform();
  }

  String _eventToCombo(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (_isModifierKey(key)) {
      return '';
    }

    final List<String> parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) {
      parts.add('Ctrl');
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      parts.add('Alt');
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      parts.add('Shift');
    }
    if (HardwareKeyboard.instance.isMetaPressed) {
      parts.add('Meta');
    }

    final String keyPart = _normalizeKeyPart(key);
    if (keyPart.isEmpty) {
      return '';
    }
    parts.add(keyPart);
    return parts.join('+');
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String _normalizeKeyPart(LogicalKeyboardKey key) {
    final String label = key.keyLabel.trim();
    if (label.isNotEmpty) {
      if (label.length == 1) {
        return label.toUpperCase();
      }
      return _capitalize(label);
    }

    final String debugName = key.debugName ?? '';
    if (debugName.isEmpty) {
      return '';
    }
    if (debugName.startsWith('F')) {
      return debugName.toUpperCase();
    }
    return _capitalize(debugName.replaceAll(' ', ''));
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<String?> _showHotkeyCaptureDialog(BuildContext context) {
    final l10n = context.l10n;
    String capturedCombo = '';
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return Focus(
                  autofocus: true,
                  onKeyEvent: (FocusNode node, KeyEvent event) {
                    if (event is KeyDownEvent) {
                      final String combo = _eventToCombo(event);
                      if (combo.isNotEmpty) {
                        setState(() {
                          capturedCombo = combo;
                        });
                      }
                    }
                    return KeyEventResult.handled;
                  },
                  child: AlertDialog(
                    title: Text(l10n.settingsHotkeyDialogTitle),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.settingsHotkeyPressAnyKey,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        if (capturedCombo.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          Text(
                            capturedCombo,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: capturedCombo.isEmpty
                            ? null
                            : () => Navigator.pop(context, capturedCombo),
                        child: Text(l10n.settingsHotkeyConfirm),
                      ),
                    ],
                  ),
                );
              },
        );
      },
    );
  }

  Future<void> _openProjectionSettings() {
    return _openSectionSheet(
      title: context.l10n.projectionSettingsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _projectionNumberField(l10n.fontSize, _projFontSize),
              _projectionNumberField(l10n.titleSize, _projTitleSize),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _projLeftIndent,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.leftMargin),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.projectionMarginsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _projectionNumberField(l10n.projectionMarginLeft, _projBorderL),
              _projectionNumberField(l10n.projectionMarginRight, _projBorderR),
              _projectionNumberField(l10n.projectionMarginTop, _projBorderT),
              _projectionNumberField(l10n.projectionMarginBottom, _projBorderB),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue: _projSpacingStep,
            decoration: InputDecoration(labelText: l10n.lineSpacing),
            items: List<DropdownMenuItem<int>>.generate(
              11,
              (int i) => DropdownMenuItem<int>(
                value: i,
                child: Text('${100 + i * 10}%'),
              ),
            ),
            onChanged: (int? v) => setBoth(() => _projSpacingStep = v ?? 0),
          ),
          DropdownButtonFormField<int>(
            initialValue: _projKottaArany,
            decoration: InputDecoration(labelText: l10n.kottaScale),
            items: List<DropdownMenuItem<int>>.generate(20, (int i) {
              final int value = (i + 1) * 10;
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value%'),
              );
            }),
            onChanged: (int? v) => setBoth(() => _projKottaArany = v ?? 100),
          ),
          DropdownButtonFormField<int>(
            initialValue: _projAkkordArany,
            decoration: InputDecoration(labelText: l10n.chordScale),
            items: List<DropdownMenuItem<int>>.generate(20, (int i) {
              final int value = (i + 1) * 10;
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value%'),
              );
            }),
            onChanged: (int? v) => setBoth(() => _projAkkordArany = v ?? 100),
          ),
          DropdownButtonFormField<int>(
            initialValue: _projBgMode,
            decoration: InputDecoration(labelText: l10n.backgroundMode),
            items: <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(value: 0, child: Text(l10n.bgModeCenter)),
              DropdownMenuItem<int>(value: 1, child: Text(l10n.bgModeZoom)),
              DropdownMenuItem<int>(value: 2, child: Text(l10n.bgModeFull)),
              DropdownMenuItem<int>(value: 3, child: Text(l10n.bgModeCascade)),
              DropdownMenuItem<int>(value: 4, child: Text(l10n.bgModeMirror)),
            ],
            onChanged: (int? v) => setBoth(() => _projBgMode = v ?? 0),
          ),
          DropdownButtonFormField<int>(
            initialValue: _projBackTrans,
            decoration: InputDecoration(labelText: l10n.backgroundOpacity),
            items: List<DropdownMenuItem<int>>.generate(11, (int i) {
              final int value = i * 10;
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value%'),
              );
            }),
            onChanged: (int? v) => setBoth(() => _projBackTrans = v ?? 0),
          ),
          DropdownButtonFormField<int>(
            initialValue: _projBlankTrans,
            decoration: InputDecoration(labelText: l10n.blankOpacity),
            items: List<DropdownMenuItem<int>>.generate(11, (int i) {
              final int value = i * 10;
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value%'),
              );
            }),
            onChanged: (int? v) => setBoth(() => _projBlankTrans = v ?? 0),
          ),
          if (_isDesktopPlatform()) ...<Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _desktopProjectorEnabled,
              onChanged: (bool v) =>
                  setBoth(() => _desktopProjectorEnabled = v),
              title: Text(l10n.projectorEnabled),
              subtitle: Text(l10n.projectorEnabledHint),
            ),
            _MonitorSelector(
              value: _desktopProjectorMonitor,
              onChanged: (int v) => setBoth(() => _desktopProjectorMonitor = v),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projUseTitle,
            onChanged: (bool v) => setBoth(() => _projUseTitle = v),
            title: Text(l10n.showTitle),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projHCenter,
            onChanged: (bool v) => setBoth(() => _projHCenter = v),
            title: Text(l10n.hCenter),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projVCenter,
            onChanged: (bool v) => setBoth(() => _projVCenter = v),
            title: Text(l10n.vCenter),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _projBoldText,
            onChanged: (bool v) => setBoth(() => _projBoldText = v),
            title: Text(l10n.boldText),
          ),
          const SizedBox(height: 8),
          Text(l10n.colorsTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _colorButton(
                label: l10n.backgroundColor,
                color: _bkColor,
                onPressed: () async {
                  final Color? picked = await _pickColor(
                    context,
                    _bkColor,
                    title: l10n.backgroundColorTitle,
                  );
                  if (picked != null) {
                    setBoth(() => _bkColor = picked);
                  }
                },
              ),
              _colorButton(
                label: l10n.textColor,
                color: _txtColor,
                onPressed: () async {
                  final Color? picked = await _pickColor(
                    context,
                    _txtColor,
                    title: l10n.textColorTitle,
                  );
                  if (picked != null) {
                    setBoth(() => _txtColor = picked);
                  }
                },
              ),
              _colorButton(
                label: l10n.emptySlideColor,
                color: _blankColor,
                onPressed: () async {
                  final Color? picked = await _pickColor(
                    context,
                    _blankColor,
                    title: l10n.emptySlideColorTitle,
                  );
                  if (picked != null) {
                    setBoth(() => _blankColor = picked);
                  }
                },
              ),
              _colorButton(
                label: l10n.highlightColor,
                color: _hiColor,
                onPressed: () async {
                  final Color? picked = await _pickColor(
                    context,
                    _hiColor,
                    title: l10n.highlightColorTitle,
                  );
                  if (picked != null) {
                    setBoth(() => _hiColor = picked);
                  }
                },
              ),
            ],
          ),
        ];
      },
    );
  }

  Future<void> _openSectionSheet({
    required String title,
    String? closeButtonLabel,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showCancelButton = false,
    bool Function()? onConfirmClose,
    VoidCallback? onCancel,
    required List<Widget> Function(
      BuildContext context,
      void Function(void Function()) setBoth,
    )
    builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
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
                          Row(
                            children: <Widget>[
                              if (showCancelButton)
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(context.l10n.cancel),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () {
                                  final bool canClose =
                                      onConfirmClose?.call() ?? true;
                                  if (canClose) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                                child: Text(
                                  closeButtonLabel ?? context.l10n.ok,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
        );
      },
    ).then((bool? accepted) {
      if (accepted == true) {
        return;
      }
      onCancel?.call();
    });
  }

  Future<void> _save() async {
    final String mqttUser = _mqttUser.text.trim();
    final String mqttPassword = _internetRelayEnabled ? _mqttPassword.text : '';
    final List<String> tcpTargets = kIsWeb
        ? const <String>[]
        : _parseTcpTargets(_tcpTargets.text);
    final bool localNetworkEnabled = kIsWeb ? false : _localNetworkEnabled;
    final String? tcpError = localNetworkEnabled
        ? _validateTcpTargets(tcpTargets)
        : null;
    if (tcpError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tcpError)));
      return;
    }
    final int firstPort = localNetworkEnabled
        ? (_firstPortFromTargets(tcpTargets) ?? widget.initialSettings.port)
        : widget.initialSettings.port;

    final Set<String> usedHotkeys = <String>{};
    for (final String hotkey in _desktopActionHotkeys.values) {
      if (usedHotkeys.contains(hotkey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHotkeyConflict(hotkey))),
        );
        return;
      }
      usedHotkeys.add(hotkey);
    }
    for (final String hotkey in _desktopSongHotkeys.keys) {
      if (usedHotkeys.contains(hotkey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHotkeyConflict(hotkey))),
        );
        return;
      }
      usedHotkeys.add(hotkey);
    }
    for (final String hotkey in _desktopOrderSetHotkeys.keys) {
      if (usedHotkeys.contains(hotkey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHotkeyConflict(hotkey))),
        );
        return;
      }
      usedHotkeys.add(hotkey);
    }

    final AppSettings updated = widget.initialSettings.copyWith(
      port: firstPort,
      tcpClientEnabled: localNetworkEnabled,
      tcpTargets: tcpTargets,
      internetRelayEnabled: _internetRelayEnabled,
      mqttUser: mqttUser,
      mqttPassword: mqttPassword,
      mqttChannel: '1',
      dtxPath: '',
      blankPicPath: _blankPicPath.text.trim(),
      diaExportPath: _diaExportPath.text.trim(),
      projFontSize: _parseInt(
        _projFontSize.text,
        widget.initialSettings.projFontSize,
        min: 12,
        max: 128,
      ),
      projTitleSize: _parseInt(
        _projTitleSize.text,
        widget.initialSettings.projTitleSize,
        min: 12,
        max: 128,
      ),
      projLeftIndent: _parseInt(
        _projLeftIndent.text,
        widget.initialSettings.projLeftIndent,
        min: 0,
        max: 10,
      ),
      projBorderL: _parseInt(
        _projBorderL.text,
        widget.initialSettings.projBorderL,
        min: 0,
        max: 1000,
      ),
      projBorderT: _parseInt(
        _projBorderT.text,
        widget.initialSettings.projBorderT,
        min: 0,
        max: 1000,
      ),
      projBorderR: _parseInt(
        _projBorderR.text,
        widget.initialSettings.projBorderR,
        min: 0,
        max: 1000,
      ),
      projBorderB: _parseInt(
        _projBorderB.text,
        widget.initialSettings.projBorderB,
        min: 0,
        max: 1000,
      ),
      projSpacingStep: _projSpacingStep.clamp(0, 10),
      projAutoSize: _projAutoSize,
      projHCenter: _projHCenter,
      projVCenter: _projVCenter,
      projUseAkkord: _projUseAkkord,
      projUseKotta: _projUseKotta,
      projShowBackgroundImage: _projShowBackgroundImage,
      projUseTitle: _projUseTitle,
      projKottaArany: _projKottaArany.clamp(10, 200),
      projAkkordArany: _projAkkordArany.clamp(10, 200),
      projBgMode: _projBgMode.clamp(0, 4),
      projBackTrans: _projBackTrans.clamp(0, 100),
      projBlankTrans: _projBlankTrans.clamp(0, 100),
      homeShowHighlightControls: _homeShowHighlightControls,
      appThemeMode: _appThemeMode.clamp(0, 1),
      appLanguage: _appLanguage,
      desktopProjectorEnabled: _desktopProjectorEnabled,
      desktopProjectorMonitor: _desktopProjectorMonitor,
      desktopActionHotkeys: Map<String, String>.from(_desktopActionHotkeys),
      desktopSongHotkeys: Map<String, String>.from(_desktopSongHotkeys),
      desktopOrderSetHotkeys: Map<String, String>.from(_desktopOrderSetHotkeys),
      projBoldText: _projBoldText,
      useSound: _useSound,
      liveSubtitleDeviceId: _liveSubtitleDeviceId,
      liveSubtitleLanguage: _liveSubtitleLanguage,
      castEnabled: _castEnabled,
      castDeviceId: _castDeviceId,
      castPort: _castPort,
      castAutoConnect: _castAutoConnect,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    final bool applied = await _applySettingsSafely(updated);
    if (!applied || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<bool> _applySettingsSafely(AppSettings updated) async {
    try {
      await widget.onApply(updated);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Settings apply failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.statusCommandSendError('$error'))),
      );
      return false;
    }
  }

  List<String> _parseTcpTargets(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((String e) => _normalizeTcpTarget(e.trim()))
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  String _normalizeTcpTarget(String rawTarget) {
    if (rawTarget.isEmpty) {
      return rawTarget;
    }
    return rawTarget.contains(':') ? rawTarget : '$rawTarget:1024';
  }

  String? _validateTcpTargets(List<String> targets) {
    final l10n = context.l10n;
    for (final String target in targets) {
      final int split = target.lastIndexOf(':');
      if (split <= 0 || split >= target.length - 1) {
        return l10n.tcpInvalidTargetFormat(target);
      }
      final String host = target.substring(0, split).trim();
      final int? port = int.tryParse(target.substring(split + 1).trim());
      if (host.isEmpty || port == null || port < 0 || port > 65535) {
        return l10n.tcpInvalidTargetFormat(target);
      }
    }
    return null;
  }

  int? _firstPortFromTargets(List<String> targets) {
    if (targets.isEmpty) {
      return null;
    }
    final String first = targets.first;
    final int split = first.lastIndexOf(':');
    if (split <= 0 || split >= first.length - 1) {
      return null;
    }
    return int.tryParse(first.substring(split + 1).trim());
  }

  Widget _projectionNumberField(
    String label,
    TextEditingController controller,
  ) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  int _parseInt(
    String raw,
    int fallback, {
    required int min,
    required int max,
  }) {
    final int value = int.tryParse(raw.trim()) ?? fallback;
    return value.clamp(min, max);
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

  Future<void> _pickBlankFile() async {
    final List<XFile> files = await DesktopProjectorBridge.instance
        .runWithNativeDialog(
      () => showFileOpenPanel(
        extensions: const <String>['png', 'jpg', 'jpeg', 'bmp', 'webp'],
      ),
    );
    final XFile? file = files.isEmpty ? null : files.first;
    if (!mounted || file == null) {
      return;
    }
    if (_isDesktopPlatform()) {
      setState(() {
        _blankPicPath.text = file.path;
      });
      return;
    }
    // Weben és mobilon nincs megbízható külső elérési út (blob-URL, illetve
    // ideiglenes cache), ezért a képet a belső fájlrendszerbe importáljuk.
    final Uint8List bytes = await file.readAsBytes();
    final String internalPath = await _blankImageStore.import(
      bytes,
      BlankImageStore.resolveImageExtension(file),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _blankPicPath.text = internalPath;
    });
  }

  void _clearBlankImage() {
    _blankPicPath.text = '';
    if (!_isDesktopPlatform()) {
      unawaited(_blankImageStore.delete());
    }
  }

  Future<void> _pickDiaExportFolder() async {
    final String? folderPath =
        await DesktopProjectorBridge.instance.runWithNativeDialog(
      showDirectoryPicker,
    );
    if (!mounted || folderPath == null) {
      return;
    }
    setState(() {
      _diaExportPath.text = folderPath;
    });
  }

  Widget _colorButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final Color fg = color.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
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

  Future<Color?> _pickColor(
    BuildContext context,
    Color initial, {
    required String title,
  }) {
    final TextEditingController hex = TextEditingController(
      text: _colorToHex(initial),
    );
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
          builder:
              (BuildContext context, void Function(void Function()) setState) {
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
    String value = input
        .trim()
        .replaceAll('#', '')
        .replaceAll('0x', '')
        .replaceAll('0X', '');
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

  String _rgbHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String _songLabelForId(String id) {
    for (final SongHotkeyOption option in _availableSongs) {
      if (option.id == id) {
        return option.label;
      }
    }
    return id;
  }

  String _orderSetLabelForId(String id) {
    _ensureAvailableOrderSetsLoaded();
    for (final CustomOrderSetOption option in _availableOrderSets) {
      if (option.id == id) {
        return option.name;
      }
    }
    for (final CustomOrderSetOption option in widget.availableOrderSets) {
      if (option.id == id) {
        return option.name;
      }
    }
    return id;
  }

  void _ensureAvailableOrderSetsLoaded() {
    if (_availableOrderSetsResolved) {
      return;
    }
    _availableOrderSetsResolved = true;
    final List<CustomOrderSetOption> loaded =
        widget.availableOrderSetsLoader?.call() ??
        const <CustomOrderSetOption>[];
    _availableOrderSets = loaded;
    if (_selectedOrderSetOptionId.isEmpty && _availableOrderSets.isNotEmpty) {
      _selectedOrderSetOptionId = _availableOrderSets.first.id;
    }
  }

  Future<CustomOrderSetOption?> _pickOrderSetOption(
    BuildContext context,
  ) async {
    _ensureAvailableOrderSetsLoaded();
    if (_availableOrderSets.isEmpty) {
      return null;
    }

    final AppLocalizations l10n = context.l10n;
    final TextEditingController search = TextEditingController();
    final List<String> lowerLabels = _availableOrderSets
        .map((CustomOrderSetOption option) => option.name.toLowerCase())
        .toList(growable: false);
    List<int> filteredIndexes = List<int>.generate(
      _availableOrderSets.length,
      (int i) => i,
      growable: true,
    );

    final CustomOrderSetOption?
    selected = await showDialog<CustomOrderSetOption>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(l10n.settingsOrderSetPickerTitle),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: search,
                      onChanged: (String value) {
                        setState(() {
                          final String lowerValue = value.toLowerCase();
                          filteredIndexes =
                              List<int>.generate(
                                    _availableOrderSets.length,
                                    (int i) => i,
                                    growable: true,
                                  )
                                  .where((int i) {
                                    return lowerLabels[i].contains(lowerValue);
                                  })
                                  .toList(growable: false);
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: l10n.settingsSearchLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        itemCount: filteredIndexes.length,
                        itemBuilder: (BuildContext context, int index) {
                          final CustomOrderSetOption option =
                              _availableOrderSets[filteredIndexes[index]];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.name),
                            selected: option.id == _selectedOrderSetOptionId,
                            onTap: () {
                              Navigator.of(context).pop(option);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop<CustomOrderSetOption>(),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
    return selected;
  }
}

class _RegistrationInput {
  const _RegistrationInput({
    required this.username,
    required this.password,
    required this.email,
  });

  final String username;
  final String password;
  final String email;
}

class _ChangeEmailInput {
  const _ChangeEmailInput({
    required this.username,
    required this.password,
    required this.newEmail,
  });

  final String username;
  final String password;
  final String newEmail;
}

class _ResendVerificationInput {
  const _ResendVerificationInput({required this.username, required this.email});

  final String username;
  final String email;
}

class _DeleteUserInput {
  const _DeleteUserInput({required this.username, required this.password});

  final String username;
  final String password;
}

class _ChangePasswordInput {
  const _ChangePasswordInput({
    required this.username,
    required this.password,
    required this.newPassword,
  });

  final String username;
  final String password;
  final String newPassword;
}

class _ChangeUsernameInput {
  const _ChangeUsernameInput({
    required this.username,
    required this.password,
    required this.newUsername,
  });

  final String username;
  final String password;
  final String newUsername;
}

class _RegistrationInputDialog extends StatefulWidget {
  const _RegistrationInputDialog({
    required this.title,
    required this.initialUsername,
  });

  final String title;
  final String initialUsername;

  @override
  State<_RegistrationInputDialog> createState() =>
      _RegistrationInputDialogState();
}

class _RegistrationInputDialogState extends State<_RegistrationInputDialog> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    final String email = _emailController.text.trim();
    if (username.isEmpty || password.isEmpty || email.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _RegistrationInput(username: username, password: password, email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldPassword,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.userFieldEmail),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

/// A vetítőablak megjelenítendő kijelzőjének kiválasztója.
/// -1: automatikus (utolsó/jobb szélső kijelző), egyébként a kijelző indexe.
class _MonitorSelector extends StatefulWidget {
  const _MonitorSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_MonitorSelector> createState() => _MonitorSelectorState();
}

class _MonitorSelectorState extends State<_MonitorSelector> {
  List<Display> _displays = <Display>[];

  @override
  void initState() {
    super.initState();
    _loadDisplays();
  }

  Future<void> _loadDisplays() async {
    try {
      final List<Display> displays = await screenRetriever.getAllDisplays();
      if (!mounted) {
        return;
      }
      setState(() {
        _displays = displays;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _displays = <Display>[];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<DropdownMenuItem<int>> items = <DropdownMenuItem<int>>[
      DropdownMenuItem<int>(value: -1, child: Text(l10n.projectorMonitorAuto)),
    ];
    for (int i = 0; i < _displays.length; i++) {
      final Display d = _displays[i];
      final String size = d.size.width.round() > 0
          ? '${d.size.width.round()}x${d.size.height.round()}'
          : '';
      final String label = size.isNotEmpty
          ? l10n.projectorMonitorIndex(i + 1, size)
          : l10n.projectorMonitorIndexShort(i + 1);
      items.add(DropdownMenuItem<int>(value: i, child: Text(label)));
    }

    return DropdownButtonFormField<int>(
      initialValue: widget.value,
      decoration: InputDecoration(labelText: l10n.projectorMonitor),
      items: items,
      onChanged: (int? v) => widget.onChanged(v ?? -1),
    );
  }
}

class _ChangeEmailInputDialog extends StatefulWidget {
  const _ChangeEmailInputDialog({
    required this.title,
    required this.initialUsername,
  });

  final String title;
  final String initialUsername;

  @override
  State<_ChangeEmailInputDialog> createState() =>
      _ChangeEmailInputDialogState();
}

class _ChangeEmailInputDialogState extends State<_ChangeEmailInputDialog> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  void _submit() {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    final String newEmail = _newEmailController.text.trim();
    if (username.isEmpty || password.isEmpty || newEmail.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _ChangeEmailInput(
        username: username,
        password: password,
        newEmail: newEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.userFieldCurrentUsername,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldCurrentPassword,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.userFieldNewEmail),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

class _ChangeUsernameInputDialog extends StatefulWidget {
  const _ChangeUsernameInputDialog({
    required this.title,
    required this.initialUsername,
  });

  final String title;
  final String initialUsername;

  @override
  State<_ChangeUsernameInputDialog> createState() =>
      _ChangeUsernameInputDialogState();
}

class _ChangeUsernameInputDialogState
    extends State<_ChangeUsernameInputDialog> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newUsernameController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newUsernameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _ChangeUsernameInput(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        newUsername: _newUsernameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: l10n.userFieldCurrentUsername,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldCurrentPassword,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newUsernameController,
            decoration: InputDecoration(labelText: l10n.userFieldNewUsername),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

class _ResendVerificationInputDialog extends StatefulWidget {
  const _ResendVerificationInputDialog({required this.title});

  final String title;

  @override
  State<_ResendVerificationInputDialog> createState() =>
      _ResendVerificationInputDialogState();
}

class _ResendVerificationInputDialogState
    extends State<_ResendVerificationInputDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _ResendVerificationInput(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.userFieldEmail),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

class _DeleteUserInputDialog extends StatefulWidget {
  const _DeleteUserInputDialog({
    required this.title,
    required this.initialUsername,
  });

  final String title;
  final String initialUsername;

  @override
  State<_DeleteUserInputDialog> createState() => _DeleteUserInputDialogState();
}

class _DeleteUserInputDialogState extends State<_DeleteUserInputDialog> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _DeleteUserInput(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldPassword,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}

class _ChangePasswordInputDialog extends StatefulWidget {
  const _ChangePasswordInputDialog({
    required this.title,
    required this.initialUsername,
  });

  final String title;
  final String initialUsername;

  @override
  State<_ChangePasswordInputDialog> createState() =>
      _ChangePasswordInputDialogState();
}

class _ChangePasswordInputDialogState
    extends State<_ChangePasswordInputDialog> {
  late final TextEditingController _usernameController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showNewPassword = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _ChangePasswordInput(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldCurrentPassword,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              labelText: l10n.userFieldNewPassword,
              suffixIcon: IconButton(
                tooltip: _showNewPassword
                    ? l10n.passwordHideTooltip
                    : l10n.passwordShowTooltip,
                onPressed: () =>
                    setState(() => _showNewPassword = !_showNewPassword),
                icon: Icon(
                  _showNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.ok)),
      ],
    );
  }
}
