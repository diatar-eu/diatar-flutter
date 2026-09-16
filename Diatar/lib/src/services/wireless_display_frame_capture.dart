import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class WirelessDisplayFrameCapture {
  WirelessDisplayFrameCapture._();

  static final WirelessDisplayFrameCapture instance = WirelessDisplayFrameCapture._();

  final GlobalKey projectionKey = GlobalKey();

  Timer? _captureTimer;
  StreamController<ui.Image>? _frameController;
  bool _isCapturing = false;

  Stream<ui.Image> get frameStream {
    _frameController ??= StreamController<ui.Image>.broadcast();
    return _frameController!.stream;
  }

  bool get isCapturing => _isCapturing;

  Future<void> startCapture({
    int fps = 30,
    int width = 1920,
    int height = 1080,
  }) async {
    if (_isCapturing) return;

    _isCapturing = true;
    _frameController = StreamController<ui.Image>.broadcast();

    final int intervalMs = (1000 / fps).round().clamp(16, 1000);
    _captureTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      unawaited(_captureFrame());
    });
  }

  Future<void> stopCapture() async {
    _isCapturing = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    final StreamController<ui.Image>? controller = _frameController;
    _frameController = null;
    await controller?.close();
  }

  Future<void> _captureFrame() async {
    if (!_isCapturing) {
      return;
    }
    final RenderRepaintBoundary? boundary =
        projectionKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }
    try {
      final RenderObject? child = boundary.child;
      if (child == null || !child.attached) {
        return;
      }
      final ui.Image image = await boundary.toImage(
        pixelRatio: 1.0,
      );
      if (_isCapturing && _frameController != null && !_frameController!.isClosed) {
        _frameController!.add(image);
      } else {
        image.dispose();
      }
    } catch (e) {
      debugPrint('WirelessDisplayFrameCapture: Failed to capture frame: $e');
    }
  }

  Future<void> dispose() async {
    await stopCapture();
  }
}