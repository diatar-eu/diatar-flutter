import 'dart:math' as math;
import 'dart:typed_data';

import 'package:diatar_app/src/services/pitch_tuner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PitchDetector.readingForFrequency', () {
    test('A4 = 440 Hz -> midi 69, note a\'', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(440.0);
      expect(reading, isNotNull);
      expect(reading!.midi, 69);
      expect(reading.cents, closeTo(0.0, 0.5));
      expect(reading.noteName, 'a\'');
    });

    test('A3 = 220 Hz -> midi 57, note a', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(220.0);
      expect(reading, isNotNull);
      expect(reading!.midi, 57);
      expect(reading.cents, closeTo(0.0, 0.5));
      expect(reading.noteName, 'a');
    });

    test('D4 = 293.66 Hz -> midi 62, note d\'', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(293.66);
      expect(reading, isNotNull);
      expect(reading!.midi, 62);
      expect(reading.noteName, 'd\'');
    });

    test('C4 = 261.63 Hz -> midi 60, note c\'', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(261.63);
      expect(reading, isNotNull);
      expect(reading!.midi, 60);
      expect(reading.noteName, 'c\'');
    });

    test('G4 = 392.00 Hz -> midi 67, note g\'', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(392.0);
      expect(reading, isNotNull);
      expect(reading!.midi, 67);
      expect(reading.noteName, 'g\'');
    });

    test('C3 = 130.81 Hz -> midi 48, note c', () {
      final PitchReading? reading = PitchDetector.readingForFrequency(130.81);
      expect(reading, isNotNull);
      expect(reading!.midi, 48);
      expect(reading.noteName, 'c');
    });
  });

  group('PitchDetector.detect with synthetic sine waves', () {
    // Helper to generate a sine wave at given frequency
    List<double> _generateSine(double frequencyHz, int sampleRate, int length) {
      final List<double> samples = List<double>.generate(length, (int i) {
        final double t = i / sampleRate;
        return math.sin(2 * math.pi * frequencyHz * t);
      });
      return samples;
    }

    test('detects 440 Hz sine wave', () {
      final List<double> samples = _generateSine(440.0, 16000, 4096);
      final PitchReading? result = PitchDetector.detect(samples, 16000);
      expect(result, isNotNull);
      expect(result!.frequencyHz, closeTo(440.0, 5.0));
      expect(result.midi, 69);
      expect(result.noteName, 'a\'');
    });

    test('detects 220 Hz sine wave', () {
      final List<double> samples = _generateSine(220.0, 16000, 4096);
      final PitchReading? result = PitchDetector.detect(samples, 16000);
      expect(result, isNotNull);
      expect(result!.frequencyHz, closeTo(220.0, 5.0));
      expect(result.midi, 57);
      expect(result.noteName, 'a');
    });

    test('detects 293.66 Hz sine wave', () {
      final List<double> samples = _generateSine(293.66, 16000, 4096);
      final PitchReading? result = PitchDetector.detect(samples, 16000);
      expect(result, isNotNull);
      expect(result!.frequencyHz, closeTo(293.66, 5.0));
      expect(result.midi, 62);
      expect(result.noteName, 'd\'');
    });

    test('returns null for silence', () {
      final List<double> samples = List<double>.filled(4096, 0.0);
      final PitchReading? result = PitchDetector.detect(samples, 16000);
      expect(result, isNull);
    });

    test('returns null for very low RMS', () {
      final List<double> samples = List<double>.filled(4096, 0.001);
      final PitchReading? result = PitchDetector.detect(samples, 16000);
      expect(result, isNull);
    });
  });
}