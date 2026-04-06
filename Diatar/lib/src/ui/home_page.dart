import 'package:flutter/material.dart';
import 'package:diatar_common/diatar_common.dart';

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

  double _estimateCanvasHeight({
    required ProjectionFrame? frame,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (frame is! TextFrame) {
      return viewportHeight;
    }

    final bool hasTitle = !controller.globals.hideTitle && frame.record.title.isNotEmpty;
    final int logicalLines = frame.record.lines.length + (hasTitle ? 1 : 0);
    if (logicalLines <= 0) {
      return viewportHeight;
    }

    final double fontSize = controller.globals.fontSize.toDouble();
    final double titleSize = (controller.globals.titleSize.toDouble() * 2.5).clamp(8.0, 72.0);
    final double lineSpacing = controller.globals.spacing100 / 100.0;

    final TextPainter normalProbe = TextPainter(
      text: TextSpan(text: 'Ag', style: TextStyle(fontSize: fontSize, fontWeight: controller.globals.boldText ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);
    final TextPainter titleProbe = TextPainter(
      text: TextSpan(text: 'Ag', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: viewportWidth);

    double estimated = 8;
    if (hasTitle) {
      estimated += titleProbe.height * lineSpacing;
    }
    estimated += normalProbe.height * lineSpacing * frame.record.lines.length;

    if (controller.globals.useKotta) {
      estimated += frame.record.lines.length * (fontSize * (controller.globals.kottaArany / 100.0) * 1.35);
    }

    // Keep enough headroom for wrapped kotta rows so vertical scrolling becomes available when needed.
    estimated *= 1.25;
    return estimated > viewportHeight ? estimated : viewportHeight;
  }
}
