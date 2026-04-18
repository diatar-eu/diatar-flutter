import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

import '../controllers/projection_controller.dart';
import '../l10n/l10n.dart';
import 'settings_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final ProjectionController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double? _canvasHeight;
  Size? _lastViewport;
  int _lastFrameSignature = 0;

  ProjectionController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              controller.updateViewport(Size(constraints.maxWidth, constraints.maxHeight));
              final double viewportHeight = constraints.maxHeight;
              final bool fitToViewport = controller.settings.projAutoSize;
              final double initialCanvasHeight = _canvasHeight ?? viewportHeight;
              final double canvasHeight = fitToViewport
                  ? viewportHeight
                  : (initialCanvasHeight > viewportHeight ? initialCanvasHeight : viewportHeight);

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
                    child: GestureDetector(
                      onLongPress: () => _openSettings(context),
                      child: fitToViewport
                          ? SizedBox(
                              width: constraints.maxWidth,
                              height: viewportHeight,
                              child: CustomPaint(
                                size: Size(constraints.maxWidth, viewportHeight),
                                painter: ProjectorPainter(
                                  frame: controller.activeFrame,
                                  globals: controller.globals,
                                  settings: controller.settings,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: canvasHeight,
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, canvasHeight),
                                  painter: ProjectorPainter(
                                    frame: controller.activeFrame,
                                    globals: controller.globals,
                                    settings: controller.settings,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  
                ],
              );
            },
          );
        },
      )
    );
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
      final double nextHeight = estimated > viewportHeight ? estimated : viewportHeight;
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
          channelSuggestions: controller.channelSuggestions,
          onApply: (settings) {
            controller.applySettings(settings);
          },
          onRefreshUsers: controller.refreshMqttUsers,
          onSenderFilterChanged: controller.updateSenderFilter,
          onSenderChosen: controller.chooseSender,
          onExitRequested: controller.requestExit,
          onShutdownRequested: controller.requestShutdown,
          onRebootRequested: controller.requestReboot,
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
    );
    final double required = painter.measureRequiredHeight(Size(viewportWidth, viewportHeight));
    return required > viewportHeight ? required : viewportHeight;
  }

  int _portParam(String key, int fallback) {
    final Object? value = controller.statusParams[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  String _localizedStatus(BuildContext context) {
    final l10n = context.l10n;
    final Map<String, Object> p = controller.statusParams;
    switch (controller.statusCode) {
      case 'statusStarting':
        return l10n.statusStarting;
      case 'statusExitRequested':
        return l10n.statusExitRequested;
      case 'statusShutdownUnsupported':
        return l10n.statusShutdownUnsupported;
      case 'statusRebootUnsupported':
        return l10n.statusRebootUnsupported;
      case 'statusStopRequested':
        return l10n.statusStopRequested;
      case 'statusShutdownRequestedUnsupported':
        return l10n.statusShutdownRequestedUnsupported;
      case 'statusReceiverError':
        return l10n.statusReceiverError('${p['message'] ?? ''}');
      case 'statusMqttOff':
        return l10n.statusMqttOff;
      case 'statusMqttReceiving':
        return l10n.statusMqttReceiving('${p['user'] ?? ''}', '${p['channel'] ?? ''}');
      case 'statusConnected':
        return l10n.statusConnected(_portParam('port', controller.settings.port));
      case 'statusWaitingForClient':
        return l10n.statusWaitingForClient(_portParam('port', controller.settings.port));
      case 'statusTcpOff':
        return l10n.statusTcpOff;
      case 'statusTcpListening':
        return l10n.statusTcpListening(_portParam('port', controller.settings.port));
      case 'statusTcpServerError':
        return l10n.statusTcpServerError('${p['error'] ?? ''}');
      case 'statusTcpServerOpenPortFailed':
        return l10n.statusTcpServerOpenPortFailed(
          _portParam('port', controller.settings.port),
          '${p['error'] ?? ''}',
        );
      case 'statusTcpServerClientError':
        return l10n.statusTcpServerClientError('${p['error'] ?? ''}');
      case 'statusTcpServerPacketParseError':
        return l10n.statusTcpServerPacketParseError('${p['error'] ?? ''}');
      case 'statusTcpServerSendError':
        return l10n.statusTcpServerSendError('${p['error'] ?? ''}');
      default:
        return controller.statusCode;
    }
  }
}
