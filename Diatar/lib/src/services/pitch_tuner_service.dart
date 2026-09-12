import 'dart:async';
import 'dart:math' as math;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

const List<String> _hungarianNotes = <String>[
  'C',
  'Cis',
  'D',
  'Disz',
  'E',
  'F',
  'Fis',
  'G',
  'Gisz',
  'A',
  'Aisz',
  'H',
];

class PitchReading {
  const PitchReading({
    required this.frequencyHz,
    required this.midi,
    required this.cents,
    required this.noteName,
  });

  final double frequencyHz;
  final int midi;
  final double cents;
  final String noteName;
}

class PitchDetector {
  PitchDetector._();

  static double midiToFrequency(int midi) {
    return 440.0 * math.pow(2, (midi - 69) / 12.0);
  }

  static PitchReading? readingForFrequency(double frequencyHz) {
    final double midiValue = 69 + 12 * math.log(frequencyHz / 440.0) / math.ln2;
    final int midi = midiValue.round();
    final double cents =
        1200 * math.log(frequencyHz / midiToFrequency(midi)) / math.ln2;
    return PitchReading(
      frequencyHz: frequencyHz,
      midi: midi,
      cents: cents,
      noteName: _hungarianNoteName(midi),
    );
  }

  static String _hungarianNoteName(int midi) {
    final int octaveIndex = (midi ~/ 12) - 4;
    final String letter = _hungarianNotes[((midi % 12) + 12) % 12];
    if (octaveIndex >= 0) {
      return '${letter.toLowerCase()}${'\'' * octaveIndex}';
    }
    if (octaveIndex == -1) {
      return letter;
    }
    return '$letter${',' * (-octaveIndex - 1)}';
  }

  static PitchReading? detect(List<double> samples, int sampleRate) {
    final int n = samples.length;
    if (n < 32 || sampleRate <= 0) {
      return null;
    }
    double rms = 0;
    for (final double s in samples) {
      rms += s * s;
    }
    rms = math.sqrt(rms / n);
    if (rms < 0.001) {
      return null;
    }

    const int maxTau = 1024;
    if (maxTau >= n) {
      return null;
    }
    const double threshold = 0.10;
    final List<double> cmndf = List<double>.filled(maxTau + 1, 1.0);
    double runningSum = 0;
    for (int tau = 1; tau <= maxTau; ++tau) {
      double difference = 0;
      for (int i = 0; i < n - tau; ++i) {
        final double delta = samples[i] - samples[i + tau];
        difference += delta * delta;
      }
      runningSum += difference;
      if (runningSum > 0) {
        cmndf[tau] = difference * tau / runningSum;
      }
    }

    int? tauEstimate;
    for (int tau = 1; tau <= maxTau; ++tau) {
      if (cmndf[tau] < threshold) {
        while (tau + 1 <= maxTau && cmndf[tau + 1] < cmndf[tau]) {
          ++tau;
        }
        tauEstimate = tau;
        break;
      }
    }
    if (tauEstimate == null) {
      return null;
    }

    double betterTau = tauEstimate.toDouble();
    if (tauEstimate > 1 && tauEstimate < maxTau) {
      final double x0 = cmndf[tauEstimate - 1];
      final double x1 = cmndf[tauEstimate];
      final double x2 = cmndf[tauEstimate + 1];
      if (x1 < x0 && x1 < x2) {
        final double denominator = x0 - 2 * x1 + x2;
        if (denominator != 0) {
          betterTau += 0.5 * (x0 - x2) / denominator;
        }
      }
    }

    final double frequencyHz = sampleRate / betterTau;
    if (frequencyHz < 50 || frequencyHz > 1500) {
      return null;
    }
    return readingForFrequency(frequencyHz);
  }
}

class _WorkerCommand {
  final String type;
  final Map<String, dynamic> data;
  final SendPort replyTo;

  _WorkerCommand(this.type, this.data, this.replyTo);
}

void _pitchWorker(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort);

  // Audio capture state (inside the isolate)
  // We'll use record package directly here
  // Actually, we can't use record package easily in an isolate because of platform channels.
  // Alternative: keep audio capture on main thread but make it very lightweight.
  // Let's just do the detection in the isolate and keep audio capture on main thread.
  // But the issue was the main thread freeze. Let's try a different approach.
  // We'll use a simple approach: keep audio capture on main thread but make the callback
  // extremely fast - just push bytes to a send port.
  // The worker does YIN detection.

  bool listening = false;
  int sampleRate = 16000;
  int windowSize = 2048;
  int hopSize = 4096;
  List<double> pending = <double>[];
  final List<double> recentFrequencies = <double>[];

  void processAudioChunk(Uint8List data, SendPort replyTo) {
    if (!listening) return;
    debugPrint('PitchWorker: processAudioChunk ${data.length} bytes');
    final int len = data.length ~/ 2;
    for (int i = 0; i < len; i++) {
      final int idx = i * 2;
      final int sample = data[idx] | (data[idx + 1] << 8);
      final double normalized = (sample & 0x8000) != 0
          ? (sample - 0x10000) / 32768.0
          : sample / 32768.0;
      pending.add(normalized);
    }
    debugPrint('PitchWorker: pending ${pending.length} samples, windowSize $windowSize');

    while (pending.length >= windowSize) {
      if (pending.length < windowSize) break;
      final Float64List window = Float64List(windowSize);
      final int start = pending.length - windowSize;
      for (int i = 0; i < windowSize; ++i) {
        window[i] = pending[start + i];
      }
      final int drop = math.min(hopSize, pending.length - windowSize);
      if (drop > 0) {
        pending = pending.sublist(drop);
      }

      final result = PitchDetector.detect(window.toList(), sampleRate);
      debugPrint('PitchWorker: detect result = $result');
      if (result != null) {
        debugPrint('PitchWorker: sending result to controller');
        replyTo.send(result);
      } else {
        debugPrint('PitchWorker: detection returned null');
      }
    }
  }

  port.listen((message) {
    if (message is _WorkerCommand) {
      debugPrint('PitchWorker: received command ${message.type}');
      switch (message.type) {
        case 'start':
          listening = true;
          sampleRate = message.data['sampleRate'] as int;
          windowSize = message.data['windowSize'] as int;
          hopSize = message.data['hopSize'] as int;
          pending.clear();
          recentFrequencies.clear();
          debugPrint('PitchWorker: started, listening=$listening, sampleRate=$sampleRate');
          message.replyTo.send('started');
          break;
        case 'stop':
          listening = false;
          message.replyTo.send('stopped');
          break;
        case 'audio':
          debugPrint('PitchWorker: got audio command, ${(message.data['data'] as Uint8List).length} bytes');
          final Uint8List data = message.data['data'] as Uint8List;
          processAudioChunk(data, message.replyTo);
          debugPrint('PitchWorker: audio processed, sending ok');
          message.replyTo.send('ok');
          break;
        case 'dispose':
          listening = false;
          message.replyTo.send('disposed');
          break;
      }
    }
  });
}

class PitchTunerService {
  PitchTunerService({
    this.sampleRate = 16000,
    this.windowSize = 2048,
    this.hopSize = 4096,
  });

  final int sampleRate;
  final int windowSize;
  final int hopSize;

  ValueChanged<PitchReading?>? onReading;
  ValueChanged<Object>? onError;

  Isolate? _workerIsolate;
  SendPort? _workerPort;
  ReceivePort? _workerReceivePort;

  Future<void> start({String? deviceId}) async {
    if (_workerIsolate != null) {
      return;
    }

    final ReceivePort workerReceivePort = ReceivePort();
    _workerReceivePort = workerReceivePort;
    _workerIsolate = await Isolate.spawn(_pitchWorker, workerReceivePort.sendPort);
    final SendPort workerPort = await workerReceivePort.first as SendPort;
    _workerPort = workerPort;

    // Start the worker with config
    final configPort = ReceivePort();
    _workerPort!.send(
      _WorkerCommand(
        'start',
        {
          'sampleRate': sampleRate,
          'windowSize': windowSize,
          'hopSize': hopSize,
        },
        configPort.sendPort,
      ),
    );
    await configPort.first;
    configPort.close();
  }

  Future<void> sendAudio(Uint8List data) async {
    if (_workerPort == null) {
      debugPrint('PitchTunerService.sendAudio: workerPort is null!');
      return;
    }
    debugPrint('PitchTunerService.sendAudio: sending ${data.length} bytes');
    final responsePort = ReceivePort();
    _workerPort!.send(
      _WorkerCommand('audio', {'data': data}, responsePort.sendPort),
    );
    try {
      await responsePort.first.timeout(const Duration(milliseconds: 500));
      debugPrint('PitchTunerService.sendAudio: response received');
    } on TimeoutException {
      debugPrint('PitchTunerService.sendAudio: TIMEOUT - worker did not respond');
    }
    responsePort.close();
  }

  Future<void> stop() async {
    if (_workerPort == null) return;
    final responsePort = ReceivePort();
    _workerPort!.send(_WorkerCommand('stop', {}, responsePort.sendPort));
    await responsePort.first;
    responsePort.close();
  }

  Future<void> dispose() async {
    if (_workerPort != null) {
      final responsePort = ReceivePort();
      _workerPort!.send(_WorkerCommand('dispose', {}, responsePort.sendPort));
      await responsePort.first;
      responsePort.close();
    }
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerPort = null;
    _workerReceivePort?.close();
    _workerReceivePort = null;
  }
}