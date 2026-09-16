import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class WirelessDisplayEncoder {
  WirelessDisplayEncoder._();

  static final WirelessDisplayEncoder instance = WirelessDisplayEncoder._();

  static const MethodChannel _frameChannel = MethodChannel('diatar/wireless_display_frames');

  StreamSubscription<ui.Image>? _frameSubscription;
  bool _isEncoding = false;

  bool get isEncoding => _isEncoding;

  Future<void> startEncoding({
    required Stream<ui.Image> frameStream,
    int fps = 30,
  }) async {
    if (_isEncoding) {
      await stopEncoding();
    }
    _isEncoding = true;
    _frameSubscription = frameStream.listen((ui.Image image) {
      unawaited(_sendFrame(image));
    });
    await _frameChannel.invokeMethod<void>('startEncoding', {'fps': fps});
  }

  Future<void> stopEncoding() async {
    _isEncoding = false;
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    try {
      await _frameChannel.invokeMethod<void>('stopEncoding');
    } on PlatformException {
      // Native side may already be gone.
    }
  }

  Future<void> _sendFrame(ui.Image image) async {
    if (!_isEncoding) {
      image.dispose();
      return;
    }
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      return;
    }
    final Uint8List bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    try {
      await _frameChannel.invokeMethod<void>('sendFrame', bytes);
    } on PlatformException {
      // Drop frame if native side is busy or tearing down.
    }
  }

  Future<void> dispose() async {
    await stopEncoding();
  }
}