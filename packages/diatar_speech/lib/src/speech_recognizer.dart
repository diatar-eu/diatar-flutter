import 'speech_result.dart';

abstract class SpeechRecognizer {
  Stream<SpeechResult> get results;
  bool get isListening;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
