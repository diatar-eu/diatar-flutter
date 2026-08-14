import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/projection_controller.dart';
import '../l10n/l10n.dart';
import '../utils/system_platform.dart';
import 'settings_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final ProjectionController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final RegExp _supportedReceiverLinkPattern = RegExp(
    r'^https://web\.diatar\.eu/diavetito/\?mqtt=([^&?#]+)$',
  );

  double? _canvasHeight;
  Size? _lastViewport;
  int _lastFrameSignature = 0;
  String _appVersion = '-';
  String _buildNumber = '-';
  Timer? _quickExitHideTimer;
  bool _showQuickExitButton = false;
  bool _isTv = false;

  ProjectionController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _detectTv();
  }

  Future<void> _detectTv() async {
    final bool tv = await SystemPlatform.isTv();
    if (!mounted || tv == _isTv) {
      return;
    }
    setState(() {
      _isTv = tv;
    });
  }

  @override
  void dispose() {
    _quickExitHideTimer?.cancel();
    super.dispose();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              controller.updateViewport(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
              final double viewportHeight = constraints.maxHeight;
              final bool fitToViewport = controller.settings.projAutoSize;

              if (!fitToViewport) {
                _scheduleHeightRefresh(
                  frame: controller.activeFrame,
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: viewportHeight,
                );
              }

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: _isTv
                        ? Focus(
                            autofocus: true,
                            onKeyEvent: _onBackgroundKeyEvent,
                            child: _buildBackground(context, constraints),
                          )
                        : _buildBackground(context, constraints),
                  ),
                  if ((defaultTargetPlatform == TargetPlatform.android ||
                          defaultTargetPlatform == TargetPlatform.iOS) &&
                      !_isTv &&
                      controller.settings.receiverKeepStartupLogo &&
                      controller.activeFrame is LogoFrame)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.icon(
                        onPressed: _scanQrAndConnect,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(context.l10n.qrScanButton),
                      ),
                    ),
                  if (_showQuickExitButton && _supportsQuickExitOverlay)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: controller.requestExit,
                        icon: const Icon(Icons.close),
                        label: Text(context.l10n.exit),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackground(BuildContext context, BoxConstraints constraints) {
    final double viewportHeight = constraints.maxHeight;
    final bool fitToViewport = controller.settings.projAutoSize;
    final double initialCanvasHeight = _canvasHeight ?? viewportHeight;
    final double canvasHeight = fitToViewport
        ? viewportHeight
        : (initialCanvasHeight > viewportHeight
              ? initialCanvasHeight
              : viewportHeight);
    final bool isLogoFrame = controller.activeFrame is LogoFrame;

    final Widget canvas = fitToViewport
        ? SizedBox(
            width: constraints.maxWidth,
            height: viewportHeight,
            child: CustomPaint(
              size: Size(
                constraints.maxWidth,
                viewportHeight,
              ),
              painter: ProjectorPainter(
                frame: controller.activeFrame,
                globals: controller.globals,
                settings: controller.settings,
                logoTitle: context.l10n.logoTitle,
                logoSubtitle: context.l10n.splashVersionSubtitle(
                  _appVersion,
                  _buildNumber,
                ),
              ),
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              width: constraints.maxWidth,
              height: canvasHeight,
              child: CustomPaint(
                size: Size(
                  constraints.maxWidth,
                  canvasHeight,
                ),
                painter: ProjectorPainter(
                  frame: controller.activeFrame,
                  globals: controller.globals,
                  settings: controller.settings,
                  logoTitle: context.l10n.logoTitle,
                  logoSubtitle: context.l10n.splashVersionSubtitle(
                    _appVersion,
                    _buildNumber,
                  ),
                ),
              ),
            ),
          );

    return GestureDetector(
      onTap: () => _showSettingsHint(context),
      onLongPress: () => _openSettings(context),
      child: Semantics(
        label: isLogoFrame ? context.l10n.startupLogoSemanticLabel : null,
        image: isLogoFrame,
        child: canvas,
      ),
    );
  }

  KeyEventResult _onBackgroundKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key != LogicalKeyboardKey.select &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter &&
        key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    unawaited(_openSettings(context));
    return KeyEventResult.handled;
  }

  void _scheduleHeightRefresh({
    required ProjectionFrame? frame,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final Size viewport = Size(viewportWidth, viewportHeight);
    final int frameSignature = Object.hash(
      frame.runtimeType,
      frame is TextFrame ? frame.record.title : null,
      frame is TextFrame ? frame.record.lines.length : 0,
      frame is TextFrame ? frame.record.lines.join('\n') : null,
      controller.globals,
      controller.settings,
    );

    if (_lastViewport == viewport && _lastFrameSignature == frameSignature) {
      return;
    }
    _lastViewport = viewport;
    _lastFrameSignature = frameSignature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final double estimated = _estimateCanvasHeight(
        frame: frame,
        viewportWidth: viewportWidth,
        viewportHeight: viewportHeight,
      );
      final double nextHeight = estimated > viewportHeight
          ? estimated
          : viewportHeight;
      final double current = _canvasHeight ?? viewportHeight;
      if ((nextHeight - current).abs() < 1) {
        return;
      }
      setState(() {
        _canvasHeight = nextHeight;
      });
    });
  }

  Future<void> _openSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SettingsSheet(
          initialSettings: controller.settings,
          senderSuggestions: controller.senderSuggestions,
          onApply: (settings) {
            controller.applySettings(settings);
          },
          onConnectInternetFromQr: controller.connectInternetFromQrUsername,
          onRefreshUsers: controller.refreshMqttUsers,
          onSenderFilterChanged: controller.updateSenderFilter,
          onExitRequested: controller.requestExit,
          onShutdownRequested: _handleShutdownRequested,
        );
      },
    );
  }

  void _showSettingsHint(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    _showQuickExitOverlay();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.settingsLongPressHint),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  bool get _supportsQuickExitOverlay {
    if (kIsWeb || _isTv) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _showQuickExitOverlay() {
    if (!_supportsQuickExitOverlay) {
      return;
    }
    _quickExitHideTimer?.cancel();
    if (!_showQuickExitButton && mounted) {
      setState(() {
        _showQuickExitButton = true;
      });
    }
    _quickExitHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_showQuickExitButton) {
        return;
      }
      setState(() {
        _showQuickExitButton = false;
      });
    });
  }

  void _handleShutdownRequested() {
    unawaited(_handleShutdownRequestedAsync());
  }

  Future<void> _handleShutdownRequestedAsync() async {
    final l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.shutdown),
          content: Text(l10n.shutdownConfirmDialogMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.shutdown),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final bool started = await controller.requestShutdown();
    if (started || !mounted) {
      return;
    }
    final String message = controller.statusCode == 'statusShutdownUnsupported'
        ? l10n.statusShutdownUnsupported
        : l10n.statusShutdownDenied;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.shutdown),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanQrAndConnect() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      await _showSimpleDialog(
        title: context.l10n.qrScanUnsupportedTitle,
        message: context.l10n.qrScanUnsupportedMessage,
      );
      return;
    }

    final String? scannedValue = await _scanQrCodeValue();
    if (!mounted || scannedValue == null) {
      return;
    }
    final String? mqttUser = _extractMqttUserFromReceiverLink(scannedValue);
    if (mqttUser == null) {
      await _showSimpleDialog(
        title: context.l10n.qrScanUnknownLinkTitle,
        message: context.l10n.qrScanUnknownLinkMessage,
      );
      return;
    }

    final bool connected = await controller.connectInternetFromQrUsername(
      mqttUser,
    );
    if (!mounted) {
      return;
    }
    await _showQrConnectionDialog(mqttUser: mqttUser, connected: connected);
  }

  String? _extractMqttUserFromReceiverLink(String value) {
    final String raw = value.trim();
    final RegExpMatch? match = _supportedReceiverLinkPattern.firstMatch(raw);
    if (match == null) {
      return null;
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.hasPort || uri.fragment.isNotEmpty) {
      return null;
    }
    if (uri.queryParameters.length != 1 ||
        !uri.queryParameters.containsKey('mqtt')) {
      return null;
    }
    final String user = uri.queryParameters['mqtt']?.trim() ?? '';
    return user.isEmpty ? null : user;
  }

  Future<String?> _scanQrCodeValue() async {
    final MobileScannerController scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    bool handled = false;

    try {
      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (BuildContext context) {
          final l10n = context.l10n;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.qrScanTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.qrScanHint),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: MobileScanner(
                        controller: scannerController,
                        onDetect: (BarcodeCapture capture) {
                          if (handled) {
                            return;
                          }
                          final String code = capture.barcodes
                              .map((Barcode b) => b.rawValue?.trim())
                              .whereType<String>()
                              .firstWhere(
                                (String s) => s.isNotEmpty,
                                orElse: () => '',
                              );
                          if (code.isEmpty) {
                            return;
                          }
                          handled = true;
                          Navigator.of(context).pop(code);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      unawaited(scannerController.dispose());
    }
  }

  Future<void> _showSimpleDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQrConnectionDialog({
    required String mqttUser,
    required bool connected,
  }) {
    final l10n = context.l10n;
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodyMedium;
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            connected
                ? l10n.qrScanConnectSuccessTitle
                : l10n.qrScanConnectFailedTitle,
          ),
          content: RichText(
            text: TextSpan(
              style: baseStyle,
              children: <InlineSpan>[
                TextSpan(text: l10n.qrScanConnectResultPrefix),
                TextSpan(
                  text: mqttUser,
                  style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: connected
                      ? l10n.qrScanConnectSuccessSuffix
                      : l10n.qrScanConnectFailedSuffix,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.ok),
            ),
          ],
        );
      },
    );
  }

  double _estimateCanvasHeight({
    required ProjectionFrame? frame,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final ProjectorPainter painter = ProjectorPainter(
      frame: frame,
      globals: controller.globals,
      settings: controller.settings,
      logoTitle: context.l10n.logoTitle,
      logoSubtitle: context.l10n.splashVersionSubtitle(
        _appVersion,
        _buildNumber,
      ),
    );
    final double required = painter.measureRequiredHeight(
      Size(viewportWidth, viewportHeight),
    );
    return required > viewportHeight ? required : viewportHeight;
  }
}
