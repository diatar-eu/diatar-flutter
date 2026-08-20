import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'pcm_converter.dart';
import 'record_audio_capture.dart';
import 'speech_recognizer.dart';
import 'speech_recognizer_config.dart';
import 'speech_result.dart';

class SherpaOnnxSpeechRecognizer implements SpeechRecognizer {
  final SpeechRecognizerConfig config;

  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  final RecordAudioCapture _audioCapture = RecordAudioCapture();
  final StreamController<SpeechResult> _controller =
      StreamController<SpeechResult>.broadcast();
  bool _isListening = false;
  bool _bindingsInitialized = false;

  SherpaOnnxSpeechRecognizer({required this.config});

  @override
  Stream<SpeechResult> get results => _controller.stream;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> start() async {
    if (_isListening) return;

    if (!await _audioCapture.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

    debugPrint('[Speech] Initializing sherpa-onnx bindings');
    if (!_bindingsInitialized) {
      await sherpa_onnx.initBindingsAsync();
      _bindingsInitialized = true;
    }

    debugPrint(
      '[Speech] Creating OnlineRecognizer (encoder=${config.modelPath}/encoder.int8.onnx)',
    );

    final sherpa_onnx.OnlineModelConfig modelConfig =
        sherpa_onnx.OnlineModelConfig(
      transducer: sherpa_onnx.OnlineTransducerModelConfig(
        encoder: '${config.modelPath}/encoder.int8.onnx',
        decoder: '${config.modelPath}/decoder.int8.onnx',
        joiner: '${config.modelPath}/joiner.int8.onnx',
      ),
      tokens: '${config.modelPath}/tokens.txt',
      numThreads: config.numThreads,
      provider: 'cpu',
    );

    final sherpa_onnx.OnlineRecognizerConfig recognizerConfig =
        sherpa_onnx.OnlineRecognizerConfig(
      feat: const sherpa_onnx.FeatureConfig(sampleRate: 16000, featureDim: 128),
      model: modelConfig,
      enableEndpoint: true,
      rule1MinTrailingSilence: config.endpointRule1,
      rule2MinTrailingSilence: config.endpointRule2,
      rule3MinUtteranceLength: config.endpointRule3,
      decodingMethod: 'greedy_search',
    );

    _recognizer = sherpa_onnx.OnlineRecognizer(recognizerConfig);
    _stream = _recognizer!.createStream();

    debugPrint('[Speech] Recognizer created, stream ptr=${_stream!.ptr.address}, recognizer ptr=${_recognizer!.ptr.address}');
    debugPrint('[Speech] Setting language=${config.language}');
    try {
      _stream!.setOption(key: 'language', value: config.language);
      debugPrint('[Speech] Language set successfully');
    } catch (e) {
      debugPrint('[Speech] Failed to set language: $e');
    }

    _isListening = true;

    try {
      final devices = await _audioCapture.listInputDevices();
      debugPrint('[Speech] Available input devices: ${devices.length}');
      for (final d in devices) {
        debugPrint('[Speech]   - ${d.label} (id=${d.id})');
      }
    } catch (e) {
      debugPrint('[Speech] Failed to list devices: $e');
    }

    await _audioCapture.start(
      sampleRate: config.sampleRate,
      deviceId: config.audioDeviceId,
      callback: AudioCaptureCallback(
        onAudioData: _onAudioData,
        onError: _onAudioError,
      ),
    );

    debugPrint('[Speech] Audio capture started');
  }

  int _audioChunkCount = 0;

  void _onAudioData(List<int> data) {
    if (_recognizer == null || _stream == null) return;

    _audioChunkCount++;

    final Float32List samples = convertPcm16ToFloat32(Uint8List.fromList(data));

    if (_audioChunkCount <= 3) {
      debugPrint(
        '[Speech] Audio chunk #$_audioChunkCount: ${data.length} bytes, '
        '${samples.length} samples, '
        'first5=[${samples[0].toStringAsFixed(4)}, ${samples[1].toStringAsFixed(4)}, '
        '${samples[2].toStringAsFixed(4)}, ${samples[3].toStringAsFixed(4)}, '
        '${samples[4].toStringAsFixed(4)}]',
      );
    }

    try {
      _stream!.acceptWaveform(samples: samples, sampleRate: config.sampleRate);
    } catch (e) {
      debugPrint('[Speech] acceptWaveform ERROR: $e');
      return;
    }

    final bool ready = _recognizer!.isReady(_stream!);
    if (_audioChunkCount <= 5 || _audioChunkCount % 50 == 0) {
      debugPrint('[Speech]   isReady=$ready');
    }

    if (ready) {
      int decodeCount = 0;
      while (_recognizer!.isReady(_stream!)) {
        _recognizer!.decode(_stream!);
        decodeCount++;
      }

      final sherpa_onnx.OnlineRecognizerResult result =
          _recognizer!.getResult(_stream!);

      debugPrint('[Speech]   decoded=$decodeCount, text="${result.text}", tokens=${result.tokens.length}');

      if (_recognizer!.isEndpoint(_stream!)) {
        _recognizer!.reset(_stream!);
        if (result.text.isNotEmpty) {
          debugPrint('[Speech] FINAL: "${result.text}"');
          _controller.add(SpeechResult(text: result.text, isFinal: true));
        }
      } else if (result.text.isNotEmpty) {
        debugPrint('[Speech] partial: "${result.text}"');
        _controller.add(SpeechResult(text: result.text, isFinal: false));
      }
    }
  }

  void _onAudioError(Object error) {
    debugPrint('[Speech] SpeechRecognizer audio error: $error');
    _isListening = false;
  }

  @override
  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioCapture.stop();
    _stream?.inputFinished();
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _audioCapture.dispose();
    await _controller.close();
  }
}
