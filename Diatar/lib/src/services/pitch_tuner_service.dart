import 'dart:math' as math;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:diatar_speech/diatar_speech.dart';

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
    if (rms < 0.004) {
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

class _DetectionRequest {
  final Float64List samples;
  final int sampleRate;
  final SendPort replyTo;

  _DetectionRequest(this.samples, this.sampleRate, this.replyTo);
}

void _detectionWorker(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort);

  port.listen((message) {
    if (message is _DetectionRequest) {
      final result = PitchDetector.detect(
        message.samples.toList(),
        message.sampleRate,
      );
      message.replyTo.send(result);
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

  final RecordAudioCapture _capture = RecordAudioCapture();
  final List<int> _pending = <int>[];
  final List<double> _recentFrequencies = <double>[];

  ValueChanged<PitchReading?>? onReading;
  ValueChanged<Object>? onError;

  bool _listening = false;
  bool _workerBusy = false;
  SendPort? _workerPort;
  ReceivePort? _workerReceivePort;

  bool get isListening => _listening;

  Future<void> start({String? deviceId}) async {
    if (_listening) {
      return;
    }
    _pending.clear();
    _recentFrequencies.clear();

    // Start background worker isolate
    final ReceivePort workerReceivePort = ReceivePort();
    _workerReceivePort = workerReceivePort;
    await Isolate.spawn(_detectionWorker, workerReceivePort.sendPort);
    final SendPort workerPort = await workerReceivePort.first as SendPort;
    _workerPort = workerPort;

    await _capture.start(
      sampleRate: sampleRate,
      deviceId: deviceId,
      callback: AudioCaptureCallback(
        onAudioData: _onAudioData,
        onError: (Object error) {
          _listening = false;
          onError?.call(error);
        },
      ),
    );
    _listening = true;
  }

  Future<void> stop() async {
    _listening = false;
    await _capture.stop();
    _workerReceivePort?.close();
    _workerReceivePort = null;
    _workerPort = null;
  }

  void _onAudioData(List<int> data) {
    if (!_listening || _workerPort == null) {
      return;
    }
    _pending.addAll(data);
    while (_pending.length >= windowSize) {
      if (_workerBusy) {
        // Skip this frame if worker is busy
        final int drop = math.min(hopSize, _pending.length - windowSize);
        if (drop > 0) {
          _pending.removeRange(0, drop);
        }
        continue;
      }
      _workerBusy = true;
      final Float64List window = Float64List(windowSize);
      final int start = _pending.length - windowSize;
      for (int i = 0; i < windowSize; ++i) {
        window[i] = _pending[start + i] / 32768.0;
      }
      final int drop = math.min(hopSize, _pending.length - windowSize);
      if (drop > 0) {
        _pending.removeRange(0, drop);
      }

      final responsePort = ReceivePort();
      _workerPort!.send(
        _DetectionRequest(window, sampleRate, responsePort.sendPort),
      );
      responsePort.listen((result) {
        _workerBusy = false;
        if (result != null && result is PitchReading) {
          _recentFrequencies.add(result.frequencyHz);
          while (_recentFrequencies.length > 5) {
            _recentFrequencies.removeAt(0);
          }
          final List<double> sorted = List<double>.of(_recentFrequencies)..sort();
          final double median = sorted[sorted.length ~/ 2];
          onReading?.call(PitchDetector.readingForFrequency(median));
        }
        responsePort.close();
      });
    }
  }

  Future<void> dispose() async {
    await stop();
    await _capture.dispose();
  }
}