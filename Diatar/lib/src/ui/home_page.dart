import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

import '../controllers/projection_controller.dart';
import 'settings_sheet.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final ProjectionController controller;

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
              final double canvasHeight = _estimateCanvasHeight(
                frame: controller.activeFrame,
                viewportWidth: constraints.maxWidth,
                viewportHeight: constraints.maxHeight,
              );
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      onLongPress: () => _openSettings(context),
                      child: SingleChildScrollView(
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
      ),
    );
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
    final double required = painter.measureRequiredHeight(
      Size(viewportWidth, viewportHeight),
    );
    return required > viewportHeight ? required : viewportHeight;
  }
}
