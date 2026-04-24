import 'package:flutter/foundation.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../l10n/l10n.dart';
import '../services/mqtt_user_api_service.dart';

class SongHotkeyOption {
  const SongHotkeyOption({required this.id, required this.label});

  final String id;
  final String label;
}

class DiatarSettingsSheet extends StatefulWidget {
  const DiatarSettingsSheet({
    super.key,
    required this.initialSettings,
    required this.onApply,
    this.availableSongs = const <SongHotkeyOption>[],
    this.availableSongsLoader,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onApply;
  final List<SongHotkeyOption> availableSongs;
  final List<SongHotkeyOption> Function()? availableSongsLoader;

  @override
  State<DiatarSettingsSheet> createState() => _DiatarSettingsSheetState();
}

class _DiatarSettingsSheetState extends State<DiatarSettingsSheet> {
  late final TextEditingController _search;
  late final TextEditingController _tcpTargets;
  late final TextEditingController _mqttUser;
  late final TextEditingController _mqttPassword;
  late final TextEditingController _dtxPath;
  late final TextEditingController _blankPicPath;
  late final TextEditingController _diaExportPath;
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
  late bool _projAutoSize;
  late bool _projHCenter;
  late bool _projVCenter;
  late bool _projUseAkkord;
  late bool _projUseKotta;
  late bool _projUseTitle;
  late bool _projBoldText;
  late bool _internetRelayEnabled;
  late Map<String, String> _desktopActionHotkeys;
  late Map<String, String> _desktopSongHotkeys;
  late List<SongHotkeyOption> _availableSongs;
  bool _availableSongsResolved = false;
  String _selectedSongHotkeyOptionId = '';
  late final FocusNode _focusNodeForHotkey;
  String _capturedSongHotkey = '';
  bool _showInternetPassword = false;
  bool _internetActionRunning = false;
  final MqttUserApiService _userApi = MqttUserApiService();
  late Color _bkColor;
  late Color _txtColor;
  late Color _blankColor;
  late Color _hiColor;

  @override
  void initState() {
    super.initState();
    final AppSettings s = widget.initialSettings;
    _search = TextEditingController();
    _tcpTargets = TextEditingController(text: s.tcpTargets.join('\n'));
    _mqttUser = TextEditingController(text: s.mqttUser);
    _mqttPassword = TextEditingController(text: s.mqttPassword);
    _focusNodeForHotkey = FocusNode(debugLabel: 'hotkey-capture');
    _dtxPath = TextEditingController(text: s.dtxPath);
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
    _projAutoSize = s.projAutoSize;
    _projHCenter = s.projHCenter;
    _projVCenter = s.projVCenter;
    _projUseAkkord = s.projUseAkkord;
    _projUseKotta = s.projUseKotta;
    _projUseTitle = s.projUseTitle;
    _projBoldText = s.projBoldText;
    _internetRelayEnabled = s.mqttUser.trim().isNotEmpty;
    _desktopActionHotkeys = Map<String, String>.from(s.desktopActionHotkeys);
    _desktopSongHotkeys = Map<String, String>.from(s.desktopSongHotkeys);
    _availableSongs = List<SongHotkeyOption>.from(widget.availableSongs);
    _availableSongsResolved = widget.availableSongs.isNotEmpty;
    if (_availableSongs.isNotEmpty) {
      _selectedSongHotkeyOptionId = _availableSongs.first.id;
    }
    _bkColor = s.bkColor;
    _txtColor = s.txtColor;
    _blankColor = s.blankColor;
    _hiColor = s.hiColor;
  }

  @override
  void dispose() {
    _search.dispose();
    _tcpTargets.dispose();
    _mqttUser.dispose();
    _mqttPassword.dispose();
    _focusNodeForHotkey.dispose();
    _dtxPath.dispose();
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
    final String dtxSummary = _dtxPath.text.trim().isEmpty
      ? l10n.valueNotSet
        : _shortPath(_dtxPath.text.trim());
    final String blankSummary = _blankPicPath.text.trim().isEmpty
      ? l10n.valueNotSet
        : _shortPath(_blankPicPath.text.trim());
    final bool desktopHotkeysAvailable = _isDesktopPlatform();
    final bool showInternet = _matches(
      query,
      'internet mqtt kozvetites felhasznalo user',
    );
    final bool showLan = _matches(query, 'helyi halozat tcp ip port');
    final bool showColors = _matches(query, 'szinek hatter szoveg highlight');
    final bool showProjection = _matches(
      query,
      'vetites betu meret cim hatter opacity',
    );
    final bool showFiles = _matches(query, 'enektar fajlok dtx ures kep blank');
    final bool showGeneral = _matches(query, 'altalanos tema nyelv language');
    final bool showHotkeys =
      desktopHotkeysAvailable &&
      _matches(query, 'gyorsbillentyu hotkey billentyu shortcut vezerles enek');
    final bool anyVisible =
        showInternet ||
        showLan ||
        showColors ||
        showProjection ||
      showFiles ||
      showGeneral ||
      showHotkeys;
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
            Text(
              l10n.settingsTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                    ),
                  if (showInternet &&
                      (showLan ||
                          showColors ||
                          showProjection ||
                          showFiles ||
                          showGeneral))
                    const Divider(height: 1),
                  if (showLan)
                    _settingsTile(
                      leading: const Icon(Icons.lan),
                      title: Text(l10n.settingsLocalNetworkTitle),
                      subtitle: Text(l10n.settingsLocalNetworkSubtitle(tcpSummary)),
                      onTap: _openLocalNetworkSettings,
                    ),
                  if (showLan &&
                      (showColors ||
                          showProjection ||
                          showFiles ||
                          showGeneral))
                    const Divider(height: 1),
                  if (showColors)
                    _settingsTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(l10n.colorsTitle),
                      subtitle: Text(
                        l10n.settingsColorSummary(
                          _rgbHex(_bkColor),
                          _rgbHex(_txtColor),
                        ),
                      ),
                      onTap: _openColorSettings,
                    ),
                  if (showColors &&
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
                    ),
                  if (showProjection && (showFiles || showGeneral || showHotkeys))
                    const Divider(height: 1),
                  if (showFiles)
                    _settingsTile(
                      leading: const Icon(Icons.folder),
                      title: Text(l10n.settingsFilesTitle),
                      subtitle: Text(
                        l10n.settingsFilesSummary(dtxSummary, blankSummary),
                      ),
                      onTap: _openFileSettings,
                    ),
                  if (showFiles && (showGeneral || showHotkeys))
                    const Divider(height: 1),
                  if (showGeneral)
                    _settingsTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.settingsGeneralTitle),
                      subtitle: Text(
                        l10n.settingsGeneralSummary(themeLabel, languageLabel),
                      ),
                      onTap: _openGeneralSettings,
                    ),
                  if (showGeneral && showHotkeys) const Divider(height: 1),
                  if (showHotkeys)
                    _settingsTile(
                      leading: const Icon(Icons.keyboard_alt_outlined),
                      title: Text(l10n.settingsHotkeysTitle),
                      subtitle: Text(l10n.settingsHotkeysSummary),
                      onTap: _openDesktopHotkeySettings,
                    ),
                  if (!anyVisible)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.settingsNoResults),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

  Future<void> _openInternetSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsInternetTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
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
            decoration: InputDecoration(labelText: l10n.userFieldUsername),
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
              OutlinedButton.icon(
                onPressed: _internetActionRunning ? null : _changeUsername,
                icon: const Icon(Icons.manage_accounts),
                label: Text(l10n.userActionChangeUsername),
              ),
            ],
          ),
          if (_internetActionRunning) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ];
      },
    );
  }

  Future<void> _registerUser() async {
    final l10n = context.l10n;
    final String? email = await _askText(
      title: l10n.userActionRegister,
      label: l10n.userFieldEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) {
      return;
    }
    final String? username = await _askText(
      title: l10n.userActionRegister,
      label: l10n.userFieldUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? password = await _askText(
      title: l10n.userActionRegister,
      label: l10n.userFieldPassword,
      obscure: true,
    );
    if (password == null) {
      return;
    }
    await _runUserApiAction(
      successMessage: l10n.userActionRegisterSuccess,
      action: () => _userApi.createUser(
        username: username,
        password: password,
        email: email,
      ),
    );
  }

  Future<void> _resendVerification() async {
    final l10n = context.l10n;
    final String? username = await _askText(
      title: l10n.userActionResendVerification,
      label: l10n.userFieldUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? email = await _askText(
      title: l10n.userActionResendVerification,
      label: l10n.userFieldEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (email == null) {
      return;
    }
    await _runUserApiAction(
      successMessage: l10n.userActionResendVerificationSuccess,
      action: () => _userApi.resendVerification(username: username, email: email),
    );
  }

  Future<void> _deleteUser() async {
    final l10n = context.l10n;
    final String? username = await _askText(
      title: l10n.userActionDeleteUser,
      label: l10n.userFieldUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? password = await _askText(
      title: l10n.userActionDeleteUser,
      label: l10n.userFieldPassword,
      obscure: true,
    );
    if (password == null) {
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
      action: () => _userApi.deleteUser(username: username, password: password),
    );
  }

  Future<void> _changePassword() async {
    final l10n = context.l10n;
    final String? username = await _askText(
      title: l10n.userActionChangePassword,
      label: l10n.userFieldUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? password = await _askText(
      title: l10n.userActionChangePassword,
      label: l10n.userFieldCurrentPassword,
      obscure: true,
    );
    if (password == null) {
      return;
    }
    final String? newPassword = await _askText(
      title: l10n.userActionChangePassword,
      label: l10n.userFieldNewPassword,
      obscure: true,
    );
    if (newPassword == null) {
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
    final String? username = await _askText(
      title: l10n.userActionChangeEmail,
      label: l10n.userFieldUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? password = await _askText(
      title: l10n.userActionChangeEmail,
      label: l10n.userFieldPassword,
      obscure: true,
    );
    if (password == null) {
      return;
    }
    final String? newEmail = await _askText(
      title: l10n.userActionChangeEmail,
      label: l10n.userFieldNewEmail,
      keyboardType: TextInputType.emailAddress,
    );
    if (newEmail == null) {
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
    final String? username = await _askText(
      title: l10n.userActionChangeUsername,
      label: l10n.userFieldCurrentUsername,
      initialValue: _mqttUser.text.trim(),
    );
    if (username == null) {
      return;
    }
    final String? password = await _askText(
      title: l10n.userActionChangeUsername,
      label: l10n.userFieldCurrentPassword,
      obscure: true,
    );
    if (password == null) {
      return;
    }
    final String? newUsername = await _askText(
      title: l10n.userActionChangeUsername,
      label: l10n.userFieldNewUsername,
    );
    if (newUsername == null) {
      return;
    }
    final String? newPassword = await _askText(
      title: l10n.userActionChangeUsername,
      label: l10n.userFieldNewPassword,
      obscure: true,
    );
    if (newPassword == null) {
      return;
    }
    await _runUserApiAction(
      successMessage: l10n.userActionChangeUsernameSuccess,
      action: () => _userApi.changeUsername(
        username: username,
        password: password,
        newUsername: newUsername,
        newPassword: newPassword,
      ),
    );
  }

  Future<String?> _askText({
    required String title,
    required String label,
    String initialValue = '',
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(context.l10n.ok),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    return result.trim();
  }

  Future<void> _runUserApiAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_internetActionRunning) {
      return;
    }
    setState(() => _internetActionRunning = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(context.l10n.userApiError('$e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _internetActionRunning = false);
      }
    }
  }

  Future<void> _openLocalNetworkSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsLocalNetworkTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        return <Widget>[
          TextField(
            controller: _tcpTargets,
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: context.l10n.tcpTargetsLabel,
              hintText: context.l10n.tcpTargetsHint,
            ),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.tcpTargetsHelp),
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
        ];
      },
    );
  }

  Future<void> _openFileSettings() {
    return _openSectionSheet(
      title: context.l10n.settingsFilesTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _dtxPath,
                  decoration: InputDecoration(labelText: l10n.dtxFolderPath),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _pickDtxFolder();
                  setBoth(() {});
                },
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
                onPressed: () async {
                  await _pickBlankFile();
                  setBoth(() {});
                },
                icon: const Icon(Icons.folder_open),
                tooltip: l10n.fileChoose,
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _diaExportPath,
                  decoration: InputDecoration(
                    labelText: l10n.diaExportFolderPath,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _pickDiaExportFolder();
                  setBoth(() {});
                },
                icon: const Icon(Icons.folder_open),
                tooltip: l10n.fileChoose,
              ),
            ],
          ),
        ];
      },
    );
  }

  Future<void> _openDesktopHotkeySettings() {
    return _openSectionSheet(
      title: context.l10n.settingsDesktopHotkeysTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final AppLocalizations l10n = context.l10n;
        final List<MapEntry<String, String>> actions = <MapEntry<String, String>>[
          MapEntry<String, String>('prevSong', l10n.settingsHotkeyActionPrevSong),
          MapEntry<String, String>('prevVerse', l10n.settingsHotkeyActionPrevVerse),
          MapEntry<String, String>('toggleProjection', l10n.settingsHotkeyActionToggleProjection),
          MapEntry<String, String>('nextVerse', l10n.settingsHotkeyActionNextVerse),
          MapEntry<String, String>('nextSong', l10n.settingsHotkeyActionNextSong),
          MapEntry<String, String>('highlightPrev', l10n.settingsHotkeyActionHighlightPrev),
          MapEntry<String, String>('highlightNext', l10n.settingsHotkeyActionHighlightNext),
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
                            _desktopActionHotkeys[entry.key] ?? '(${l10n.valueNotSet})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final String? captured = await _showHotkeyCaptureDialog(context);
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
          ...<Widget>[
            if (_capturedSongHotkey.isEmpty) ...<Widget>[
              Focus(
                focusNode: _focusNodeForHotkey,
                autofocus: true,
                onKeyEvent: (FocusNode node, KeyEvent event) {
                  if (event is KeyDownEvent) {
                    final String combo = _eventToCombo(event);
                    if (combo.isNotEmpty) {
                      setBoth(() {
                        _capturedSongHotkey = combo;
                      });
                    }
                  }
                  return KeyEventResult.handled;
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).primaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        l10n.settingsHotkeyPressAnyKey,
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      if (_capturedSongHotkey.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _capturedSongHotkey,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...<Widget>[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _capturedSongHotkey,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setBoth(() {
                              _capturedSongHotkey = '';
                              _focusNodeForHotkey.requestFocus();
                            });
                          },
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            if (_selectedSongHotkeyOptionId.isNotEmpty) {
                              setBoth(() {
                                _desktopSongHotkeys[_capturedSongHotkey] = _selectedSongHotkeyOptionId;
                                _capturedSongHotkey = '';
                              });
                            }
                          },
                          child: Text(l10n.settingsHotkeyAssign),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  setBoth(() {
                    _capturedSongHotkey = '';
                  });
                  _focusNodeForHotkey.requestFocus();
                },
                icon: const Icon(Icons.clear),
                label: Text(l10n.settingsHotkeyClearCapture),
              ),
            ),
          ],
          if (_desktopSongHotkeys.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ..._desktopSongHotkeys.entries.map((MapEntry<String, String> entry) {
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
          builder: (
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
                      decoration: InputDecoration(labelText: l10n.settingsSearchLabel),
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
          builder: (BuildContext context, void Function(void Function()) setState) {
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
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
          Text(l10n.projectionMarginsTitle, style: Theme.of(context).textTheme.titleSmall),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: !_projAutoSize,
            onChanged: (bool v) => setBoth(() => _projAutoSize = !v),
            title: Text(l10n.scrollableProjection),
            subtitle: Text(l10n.scrollableProjectionHint),
          ),
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
            value: _projBoldText,
            onChanged: (bool v) => setBoth(() => _projBoldText = v),
            title: Text(l10n.boldText),
          ),
        ];
      },
    );
  }

  Future<void> _openColorSettings() {
    return _openSectionSheet(
      title: context.l10n.colorsTitle,
      builder: (BuildContext context, void Function(void Function()) setBoth) {
        final l10n = context.l10n;
        return <Widget>[
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

  void _save() {
    final String mqttUser = _internetRelayEnabled ? _mqttUser.text.trim() : '';
    final String mqttPassword = _internetRelayEnabled ? _mqttPassword.text : '';
    final List<String> tcpTargets = _parseTcpTargets(_tcpTargets.text);
    final String? tcpError = _validateTcpTargets(tcpTargets);
    if (tcpError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tcpError)));
      return;
    }
    final int firstPort =
        _firstPortFromTargets(tcpTargets) ?? widget.initialSettings.port;

    final Set<String> usedHotkeys = <String>{};
    for (final String hotkey in _desktopActionHotkeys.values) {
      if (usedHotkeys.contains(hotkey)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHotkeyConflict(hotkey))),
        );
        return;
      }
      usedHotkeys.add(hotkey);
    }
    for (final String hotkey in _desktopSongHotkeys.keys) {
      if (usedHotkeys.contains(hotkey)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHotkeyConflict(hotkey))),
        );
        return;
      }
      usedHotkeys.add(hotkey);
    }

    final AppSettings updated = widget.initialSettings.copyWith(
      port: firstPort,
      tcpClientEnabled: tcpTargets.isNotEmpty,
      tcpTargets: tcpTargets,
      mqttUser: mqttUser,
      mqttPassword: mqttPassword,
      mqttChannel: '1',
      dtxPath: _dtxPath.text.trim(),
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
      projUseTitle: _projUseTitle,
      projKottaArany: _projKottaArany.clamp(10, 200),
      projAkkordArany: _projAkkordArany.clamp(10, 200),
      projBgMode: _projBgMode.clamp(0, 4),
      projBackTrans: _projBackTrans.clamp(0, 100),
      projBlankTrans: _projBlankTrans.clamp(0, 100),
      appThemeMode: _appThemeMode.clamp(0, 1),
      appLanguage: _appLanguage,
      desktopActionHotkeys: Map<String, String>.from(_desktopActionHotkeys),
      desktopSongHotkeys: Map<String, String>.from(_desktopSongHotkeys),
      projBoldText: _projBoldText,
      bkColor: _bkColor,
      txtColor: _txtColor,
      blankColor: _blankColor,
      hiColor: _hiColor,
    );

    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  List<String> _parseTcpTargets(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
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
    final XTypeGroup images = XTypeGroup(
      label: context.l10n.imagesFileTypeLabel,
      extensions: <String>['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[images],
    );
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

  Future<void> _pickDiaExportFolder() async {
    final String? folderPath = await getDirectoryPath();
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

  String _shortPath(String path) {
    final List<String> normalized = path
        .replaceAll('\\', '/')
        .split('/')
        .where((String p) => p.isNotEmpty)
        .toList();
    if (normalized.length <= 2) {
      return path;
    }
    return '.../${normalized[normalized.length - 2]}/${normalized.last}';
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
}
