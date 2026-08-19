class SpeechRecognizerConfig {
  final String language;
  final String modelPath;
  final String? audioDeviceId;
  final int sampleRate;
  final int numThreads;
  final double endpointRule1;
  final double endpointRule2;
  final double endpointRule3;

  const SpeechRecognizerConfig({
    this.language = 'auto',
    required this.modelPath,
    this.audioDeviceId,
    this.sampleRate = 16000,
    this.numThreads = 2,
    this.endpointRule1 = 2.4,
    this.endpointRule2 = 1.2,
    this.endpointRule3 = 20,
  });
}
