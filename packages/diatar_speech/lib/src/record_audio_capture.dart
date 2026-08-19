import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioCaptureCallback {
  final void Function(List<int> data) onAudioData;
  final void Function(Object error)? onError;

  AudioCaptureCallback({required this.onAudioData, this.onError});
}

class RecordAudioCapture {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async => _recorder.hasPermission();

  Future<List<InputDevice>> listInputDevices() => _recorder.listInputDevices();

  Future<void> start({
    required int sampleRate,
    String? deviceId,
    AudioCaptureCallback? callback,
  }) async {
    if (_isRecording) return;

    final RecordConfig config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      device: deviceId != null ? InputDevice(id: deviceId, label: '') : null,
    );

    debugPrint(
      '[Capture] Starting audio capture (sampleRate=$sampleRate)',
    );

    final Stream<Uint8List> stream = await _recorder.startStream(config);

    _isRecording = true;

    debugPrint('[Capture] Audio capture started, listening for data');

    _subscription = stream.listen(
      (Uint8List data) {
        callback?.onAudioData(data);
      },
      onError: (Object error) {
        debugPrint('[Capture] Audio capture error: $error');
        _isRecording = false;
        callback?.onError?.call(error);
      },
      onDone: () {
        debugPrint('[Capture] Audio capture stream done');
        _isRecording = false;
      },
    );
  }

  Future<void> stop() async {
    _isRecording = false;
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
