import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'model_registry.dart';
import 'pcm_converter.dart';
import 'record_audio_capture.dart';
import 'speech_recognizer.dart';
import 'speech_recognizer_config.dart';
import 'speech_result.dart';

class SherpaOnnxOfflineRecognizer implements SpeechRecognizer {
  final SpeechRecognizerConfig config;

  sherpa_onnx.VoiceActivityDetector? _vad;
  sherpa_onnx.CircularBuffer? _buffer;
  sherpa_onnx.OfflineRecognizer? _recognizer;
  final RecordAudioCapture _audioCapture = RecordAudioCapture();
  final StreamController<SpeechResult> _controller =
      StreamController<SpeechResult>.broadcast();
  bool _isListening = false;
  bool _bindingsInitialized = false;

  SherpaOnnxOfflineRecognizer({required this.config});

  @override
  Stream<SpeechResult> get results => _controller.stream;

  @override
  bool get isListening => _isListening;

  @override
  Future<void> start() async {
    if (_isListening) return;

    debugPrint('[OfflineSpeech] === Starting offline recognizer ===');

    if (!await _audioCapture.hasPermission()) {
      throw StateError('Microphone permission denied');
    }

    debugPrint('[OfflineSpeech] Initializing sherpa-onnx bindings');
    if (!_bindingsInitialized) {
      sherpa_onnx.initBindings();
      _bindingsInitialized = true;
    }

    _validateModelFiles();

    try {
      _initVad();
    } catch (e, st) {
      debugPrint('[OfflineSpeech] VAD init FAILED: $e\n$st');
      rethrow;
    }

    try {
      _initRecognizer();
    } catch (e, st) {
      debugPrint('[OfflineSpeech] OfflineRecognizer init FAILED: $e\n$st');
      rethrow;
    }

    _isListening = true;

    try {
      final devices = await _audioCapture.listInputDevices();
      debugPrint('[OfflineSpeech] Available input devices: ${devices.length}');
      for (final d in devices) {
        debugPrint('  - ${d.label} (id=${d.id})');
      }
    } catch (e) {
      debugPrint('[OfflineSpeech] Failed to list devices: $e');
    }

    await _audioCapture.start(
      sampleRate: config.sampleRate,
      deviceId: config.audioDeviceId,
      callback: AudioCaptureCallback(
        onAudioData: _onAudioData,
        onError: _onAudioError,
      ),
    );

    debugPrint('[OfflineSpeech] Audio capture started successfully');
  }

  void _validateModelFiles() {
    debugPrint('[OfflineSpeech] Validating model files...');
    debugPrint('[OfflineSpeech]   VAD model path: ${config.vadModelPath}');
    debugPrint('[OfflineSpeech]   Model path: ${config.modelPath}');
    debugPrint('[OfflineSpeech]   Model type: ${config.modelType.name}');

    final File vadFile = File(config.vadModelPath);
    if (!vadFile.existsSync()) {
      throw StateError('VAD model file not found: ${config.vadModelPath}');
    }
    debugPrint(
      '[OfflineSpeech]   VAD model: ${vadFile.lengthSync()} bytes',
    );

    final SpeechModelInfo info = getSpeechModel(config.modelType);
    final Directory modelDir = Directory(config.modelPath);
    if (!modelDir.existsSync()) {
      throw StateError('Model directory not found: ${config.modelPath}');
    }

    debugPrint(
      '[OfflineSpeech]   Required files: ${info.requiredFiles.join(', ')}',
    );
    for (final String file in info.requiredFiles) {
      final String filePath = '${config.modelPath}/$file';
      final File f = File(filePath);
      if (f.existsSync()) {
        debugPrint(
          '[OfflineSpeech]   ✓ $file (${f.lengthSync()} bytes)',
        );
      } else {
        debugPrint('[OfflineSpeech]   ✗ $file NOT FOUND');
      }
    }
  }

  void _initVad() {
    debugPrint(
      '[OfflineSpeech] Creating VAD with model: ${config.vadModelPath}',
    );
    final vadConfig = sherpa_onnx.VadModelConfig(
      sileroVad: sherpa_onnx.SileroVadModelConfig(
        model: config.vadModelPath,
        threshold: 0.5,
        minSilenceDuration: 0.5,
        minSpeechDuration: 0.25,
        windowSize: 512,
        maxSpeechDuration: 5.0,
      ),
      sampleRate: config.sampleRate,
      numThreads: 1,
      provider: 'cpu',
      debug: false,
    );

    _vad = sherpa_onnx.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 60,
    );
    _buffer = sherpa_onnx.CircularBuffer(
      capacity: 60 * config.sampleRate,
    );
    debugPrint('[OfflineSpeech] VAD + CircularBuffer created OK');
  }

  void _initRecognizer() {
    final SpeechModelInfo info = getSpeechModel(config.modelType);
    debugPrint('[OfflineSpeech] Initializing recognizer for: ${info.displayName}');

    final sherpa_onnx.OfflineModelConfig modelConfig;

    if (config.modelType == SpeechModelType.qwen3Asr06b) {
      final String encoderPath = '${config.modelPath}/encoder.int8.onnx';
      final String decoderPath = '${config.modelPath}/decoder.int8.onnx';
      final String convPath = '${config.modelPath}/conv_frontend.onnx';
      final String tokenizerPath = '${config.modelPath}/tokenizer';

      debugPrint('[OfflineSpeech]   encoder: $encoderPath');
      debugPrint('[OfflineSpeech]   decoder: $decoderPath');
      debugPrint('[OfflineSpeech]   convFrontend: $convPath');
      debugPrint('[OfflineSpeech]   tokenizer: $tokenizerPath');

      modelConfig = sherpa_onnx.OfflineModelConfig(
        qwen3Asr: sherpa_onnx.OfflineQwen3AsrModelConfig(
          convFrontend: convPath,
          encoder: encoderPath,
          decoder: decoderPath,
          tokenizer: tokenizerPath,
          maxNewTokens: 512,
          maxTotalLen: 512,
        ),
        tokens: '',
        numThreads: config.numThreads,
        provider: 'cpu',
        debug: true,
        modelType: 'qwen3_asr',
      );
    } else {
      final String prefix = info.whisperPrefix;
      final String encoderPath = '${config.modelPath}/${prefix}encoder.int8.onnx';
      final String decoderPath = '${config.modelPath}/${prefix}decoder.int8.onnx';
      final String tokensPath = '${config.modelPath}/${prefix}tokens.txt';

      debugPrint('[OfflineSpeech]   encoder: $encoderPath');
      debugPrint('[OfflineSpeech]   decoder: $decoderPath');
      debugPrint('[OfflineSpeech]   tokens: $tokensPath');

      modelConfig = sherpa_onnx.OfflineModelConfig(
        whisper: sherpa_onnx.OfflineWhisperModelConfig(
          encoder: encoderPath,
          decoder: decoderPath,
          language: _normalizeWhisperLanguage(config.whisperLanguage),
          task: 'transcribe',
        ),
        tokens: tokensPath,
        numThreads: config.numThreads,
        provider: 'cpu',
        debug: true,
        modelType: 'whisper',
      );
    }

    final recognizerConfig = sherpa_onnx.OfflineRecognizerConfig(
      model: modelConfig,
      decodingMethod: 'greedy_search',
      maxActivePaths: 4,
    );

    debugPrint('[OfflineSpeech] Creating OfflineRecognizer...');
    _recognizer = sherpa_onnx.OfflineRecognizer(recognizerConfig);
    debugPrint('[OfflineSpeech] OfflineRecognizer created OK');
  }

  int _audioChunkCount = 0;

  void _onAudioData(List<int> data) {
    if (_vad == null || _recognizer == null || _buffer == null) return;

    _audioChunkCount++;

    final Float32List samples = convertPcm16ToFloat32(Uint8List.fromList(data));

    if (_audioChunkCount <= 3) {
      debugPrint(
        '[OfflineSpeech] Audio chunk #$_audioChunkCount: ${data.length} bytes, '
        '${samples.length} samples',
      );
    }

    _buffer!.push(samples);

    final int windowSize = _vad!.config.sileroVad.windowSize;
    while (_buffer!.size > windowSize) {
      final Float32List window = _buffer!.get(
        startIndex: _buffer!.head,
        n: windowSize,
      );
      _buffer!.pop(windowSize);

      try {
        _vad!.acceptWaveform(window);
      } catch (e) {
        debugPrint('[OfflineSpeech] VAD acceptWaveform ERROR: $e');
        return;
      }

      while (!_vad!.isEmpty()) {
        final sherpa_onnx.SpeechSegment segment = _vad!.front();

        debugPrint(
          '[OfflineSpeech] Speech segment: ${segment.samples.length} samples',
        );

        _processSegment(segment.samples);

        _vad!.pop();
      }
    }
  }

  void _processSegment(Float32List samples) {
    if (_recognizer == null) return;

    try {
      final sherpa_onnx.OfflineStream stream = _recognizer!.createStream();

      stream.acceptWaveform(
        samples: samples,
        sampleRate: config.sampleRate,
      );

      _recognizer!.decode(stream);

      final sherpa_onnx.OfflineRecognizerResult result =
          _recognizer!.getResult(stream);

      stream.free();

      if (result.text.isNotEmpty) {
        debugPrint('[OfflineSpeech] RESULT: "${result.text}"');
        _controller.add(SpeechResult(text: result.text, isFinal: true));
      }
    } catch (e) {
      debugPrint('[OfflineSpeech] decode ERROR: $e');
    }
  }

  String _normalizeWhisperLanguage(String lang) {
    if (lang == 'auto') return '';
    final int dash = lang.indexOf('-');
    return dash > 0 ? lang.substring(0, dash) : lang;
  }

  void _onAudioError(Object error) {
    debugPrint('[OfflineSpeech] audio error: $error');
    _isListening = false;
  }

  @override
  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioCapture.stop();

    _vad?.flush();
    while (_vad != null && !_vad!.isEmpty()) {
      final sherpa_onnx.SpeechSegment segment = _vad!.front();
      _processSegment(segment.samples);
      _vad!.pop();
    }

    _buffer?.free();
    _buffer = null;
    _vad?.free();
    _vad = null;
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
