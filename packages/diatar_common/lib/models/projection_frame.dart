import 'dart:ui' as ui;

import 'records.dart';

sealed class ProjectionFrame {
  const ProjectionFrame();
}

class LogoFrame extends ProjectionFrame {
  const LogoFrame(this.phase);

  final int phase;
}

class TextFrame extends ProjectionFrame {
  const TextFrame({required this.record});

  final RecTextRecord record;
}

class ImageFrame extends ProjectionFrame {
  const ImageFrame({required this.image, required this.bgMode});

  final ui.Image image;
  final int bgMode;
}
