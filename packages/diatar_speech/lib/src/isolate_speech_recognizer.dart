import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'model_registry.dart';
import 'pcm_converter.dart';
import 'record_audio_capture.dart';
import 'speech_recognizer.dart';
import 'speech_recognizer_config.dart';
import 'speech_result.dart';

class IsolateSpeechRecognizer implements SpeechRecognizer {
  final SpeechRecognizerConfig config;
  final bool isStreaming;

  Isolate? _isolate;
  SendPort? _commandPort;
  final ReceivePort _mainPort = ReceivePort();
  final StreamController<SpeechResult> _controller =
      StreamController<SpeechResult>.broadcast();
  bool _isListening = false;
  final RecordAudioCapture _audioCapture = RecordAudioCapture();
  Completer<void>? _readyCompleter;

  IsolateSpeechRecognizer({required this.config, required this.isStreaming});

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

    _readyCompleter = Completer<void>();

    _isolate = await Isolate.spawn(
      _backgroundMain,
      _mainPort.sendPort,
      errorsAreFatal: false,
    );

    _mainPort.listen(_onEvent);

    await _readyCompleter!.future;

    _commandPort?.send({'type': 'start'});

    await _audioCapture.start(
      sampleRate: config.sampleRate,
      deviceId: config.audioDeviceId,
      callback: AudioCaptureCallback(
        onAudioData: (List<int> data) {
          _commandPort?.send({
            'type': 'audio',
            'data': Uint8List.fromList(data),
          });
        },
        onError: (Object error) {
          debugPrint('[IsolateRecognizer] Audio error: $error');
        },
      ),
    );

    _isListening = true;
    debugPrint('[IsolateRecognizer] Started');
  }

  void _onEvent(dynamic message) {
    if (message is SendPort) {
      _commandPort = message;
      _sendCreateCommand();
      return;
    }
    if (message is! Map) return;

    final String? type = message['type'] as String?;
    switch (type) {
      case 'result':
        _controller.add(SpeechResult(
          text: message['text'] as String,
          isFinal: message['isFinal'] as bool,
        ));
      case 'error':
        final String msg = message['message'] as String;
        debugPrint('[IsolateRecognizer] Background error: $msg');
        if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
          _readyCompleter!.completeError(msg);
        }
      case 'ready':
        if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
          _readyCompleter!.complete();
        }
    }
  }

  void _sendCreateCommand() {
    final SpeechModelInfo info = getSpeechModel(config.modelType);

    _commandPort!.send({
      'type': 'create',
      'isStreaming': isStreaming,
      'modelType': config.modelType.name,
      'sampleRate': config.sampleRate,
      'numThreads': config.numThreads,
      'whisperLanguage': config.whisperLanguage,
      'modelPath': config.modelPath,
      'vadModelPath': config.vadModelPath,
      'whisperPrefix': info.whisperPrefix,
    });
  }

  @override
  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioCapture.stop();
    _commandPort?.send({'type': 'dispose'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _isolate?.kill();
    _isolate = null;
    _commandPort = null;
    _mainPort.close();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _audioCapture.dispose();
    await _controller.close();
  }
}

void _backgroundMain(SendPort mainSendPort) {
  final ReceivePort isolatePort = ReceivePort();
  mainSendPort.send(isolatePort.sendPort);

  sherpa_onnx.OnlineRecognizer? onlineRecognizer;
  sherpa_onnx.OnlineStream? onlineStream;
  sherpa_onnx.VoiceActivityDetector? vad;
  sherpa_onnx.CircularBuffer? buffer;
  sherpa_onnx.OfflineRecognizer? offlineRecognizer;
  int sampleRate = 16000;
  bool started = false;

  void sendResult(String text, bool isFinal) {
    mainSendPort.send({'type': 'result', 'text': text, 'isFinal': isFinal});
  }

  void sendError(String message) {
    mainSendPort.send({'type': 'error', 'message': message});
  }

  void processStreamingAudio(Uint8List data) {
    if (onlineRecognizer == null || onlineStream == null) return;

    final Float32List samples = convertPcm16ToFloat32(data);
    onlineStream!.acceptWaveform(samples: samples, sampleRate: sampleRate);

    while (onlineRecognizer!.isReady(onlineStream!)) {
      onlineRecognizer!.decode(onlineStream!);
    }

    final sherpa_onnx.OnlineRecognizerResult result =
        onlineRecognizer!.getResult(onlineStream!);

    if (onlineRecognizer!.isEndpoint(onlineStream!)) {
      onlineRecognizer!.reset(onlineStream!);
      if (result.text.isNotEmpty) {
        sendResult(result.text, true);
      }
    } else if (result.text.isNotEmpty) {
      sendResult(result.text, false);
    }
  }

  void processOfflineAudio(Uint8List data) {
    if (vad == null || buffer == null || offlineRecognizer == null) return;

    final Float32List samples = convertPcm16ToFloat32(data);
    buffer!.push(samples);

    final int windowSize = vad!.config.sileroVad.windowSize;
    while (buffer!.size > windowSize) {
      final Float32List window = buffer!.get(
        startIndex: buffer!.head,
        n: windowSize,
      );
      buffer!.pop(windowSize);

      try {
        vad!.acceptWaveform(window);
      } catch (e) {
        sendError('VAD error: $e');
        return;
      }

      while (!vad!.isEmpty()) {
        final sherpa_onnx.SpeechSegment segment = vad!.front();

        try {
          final sherpa_onnx.OfflineStream stream =
              offlineRecognizer!.createStream();
          stream.acceptWaveform(
            samples: segment.samples,
            sampleRate: sampleRate,
          );
          offlineRecognizer!.decode(stream);
          final sherpa_onnx.OfflineRecognizerResult result =
              offlineRecognizer!.getResult(stream);
          stream.free();

          if (result.text.isNotEmpty) {
            sendResult(result.text, true);
          }
        } catch (e) {
          sendError('Decode error: $e');
        }

        vad!.pop();
      }
    }
  }

  void flushOffline() {
    if (vad == null || offlineRecognizer == null) return;
    vad!.flush();
    while (vad != null && !vad!.isEmpty()) {
      final sherpa_onnx.SpeechSegment segment = vad!.front();
      try {
        final sherpa_onnx.OfflineStream stream =
            offlineRecognizer!.createStream();
        stream.acceptWaveform(
          samples: segment.samples,
          sampleRate: sampleRate,
        );
        offlineRecognizer!.decode(stream);
        final sherpa_onnx.OfflineRecognizerResult result =
            offlineRecognizer!.getResult(stream);
        stream.free();
        if (result.text.isNotEmpty) {
          sendResult(result.text, true);
        }
      } catch (e) {
        sendError('Flush decode error: $e');
      }
      vad!.pop();
    }
  }

  void createStreamingRecognizer(Map config) {
    final String modelPath = config['modelPath'] as String;

    final onlineConfig = sherpa_onnx.OnlineRecognizerConfig(
      model: sherpa_onnx.OnlineModelConfig(
        transducer: sherpa_onnx.OnlineTransducerModelConfig(
          encoder: '$modelPath/encoder.int8.onnx',
          decoder: '$modelPath/decoder.int8.onnx',
          joiner: '$modelPath/joiner.int8.onnx',
        ),
        tokens: '$modelPath/tokens.txt',
        numThreads: config['numThreads'] as int,
        provider: 'cpu',
      ),
      enableEndpoint: true,
      rule1MinTrailingSilence: 2.4,
      rule2MinTrailingSilence: 1.2,
      rule3MinUtteranceLength: 20,
    );

    onlineRecognizer = sherpa_onnx.OnlineRecognizer(onlineConfig);
    onlineStream = onlineRecognizer!.createStream();
    debugPrint('[IsolateBG] Streaming recognizer created');
  }

  void createOfflineRecognizer(Map config) {
    final String modelPath = config['modelPath'] as String;
    final String modelTypeName = config['modelType'] as String;
    final String whisperPrefix = config['whisperPrefix'] as String? ?? '';

    final vadConfig = sherpa_onnx.VadModelConfig(
      sileroVad: sherpa_onnx.SileroVadModelConfig(
        model: config['vadModelPath'] as String,
        threshold: 0.5,
        minSilenceDuration: 0.5,
        minSpeechDuration: 0.25,
        windowSize: 512,
        maxSpeechDuration: 5.0,
      ),
      sampleRate: sampleRate,
      numThreads: 1,
      provider: 'cpu',
      debug: false,
    );

    vad = sherpa_onnx.VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: 60,
    );
    buffer = sherpa_onnx.CircularBuffer(
      capacity: 60 * sampleRate,
    );

    final sherpa_onnx.OfflineModelConfig modelConfig;

    if (modelTypeName == 'qwen3Asr06b') {
      modelConfig = sherpa_onnx.OfflineModelConfig(
        qwen3Asr: sherpa_onnx.OfflineQwen3AsrModelConfig(
          convFrontend: '$modelPath/conv_frontend.onnx',
          encoder: '$modelPath/encoder.int8.onnx',
          decoder: '$modelPath/decoder.int8.onnx',
          tokenizer: '$modelPath/tokenizer',
          maxNewTokens: 512,
          maxTotalLen: 512,
        ),
        tokens: '',
        numThreads: config['numThreads'] as int,
        provider: 'cpu',
        debug: true,
        modelType: 'qwen3_asr',
      );
    } else {
      final String lang = config['whisperLanguage'] as String? ?? 'auto';
      final String normalizedLang =
          lang == 'auto' ? '' : lang.split('-').first;

      modelConfig = sherpa_onnx.OfflineModelConfig(
        whisper: sherpa_onnx.OfflineWhisperModelConfig(
          encoder: '$modelPath/${whisperPrefix}encoder.int8.onnx',
          decoder: '$modelPath/${whisperPrefix}decoder.int8.onnx',
          language: normalizedLang,
          task: 'transcribe',
        ),
        tokens: '$modelPath/${whisperPrefix}tokens.txt',
        numThreads: config['numThreads'] as int,
        provider: 'cpu',
        debug: true,
        modelType: 'whisper',
      );
    }

    offlineRecognizer = sherpa_onnx.OfflineRecognizer(
      sherpa_onnx.OfflineRecognizerConfig(
        model: modelConfig,
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
      ),
    );
    debugPrint('[IsolateBG] Offline recognizer created');
  }

  isolatePort.listen((dynamic message) {
    if (message is! Map) return;

    final String type = message['type'] as String;

    switch (type) {
      case 'create':
        try {
          sherpa_onnx.initBindings();
          sampleRate = message['sampleRate'] as int;

          if (message['isStreaming'] as bool) {
            createStreamingRecognizer(message);
          } else {
            createOfflineRecognizer(message);
          }

          mainSendPort.send({'type': 'ready'});
        } catch (e, st) {
          sendError('Init failed: $e\n$st');
        }
        break;

      case 'start':
        started = true;
        break;

      case 'audio':
        if (!started) break;
        try {
          final Uint8List data = message['data'] as Uint8List;
          if (onlineRecognizer != null) {
            processStreamingAudio(data);
          } else if (vad != null) {
            processOfflineAudio(data);
          }
        } catch (e) {
          sendError('Processing error: $e');
        }
        break;

      case 'dispose':
        try {
          if (vad != null) {
            flushOffline();
          }
          onlineStream?.free();
          onlineStream = null;
          onlineRecognizer?.free();
          onlineRecognizer = null;
          vad?.free();
          vad = null;
          buffer?.free();
          buffer = null;
          offlineRecognizer?.free();
          offlineRecognizer = null;
        } catch (_) {}
        isolatePort.close();
        break;
    }
  });
}
