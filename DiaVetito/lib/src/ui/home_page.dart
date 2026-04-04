import 'package:flutter/material.dart';

import '../controllers/projection_controller.dart';
import 'projector_painter.dart';
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
              controller.updateViewport(Size(constraints.maxWidth, constraints.maxHeight));
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      onLongPress: () => _openSettings(context),
                      child: CustomPaint(
                        painter: ProjectorPainter(
                          frame: controller.activeFrame,
                          globals: controller.globals,
                          settings: controller.settings,
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
}
