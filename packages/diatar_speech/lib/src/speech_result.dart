class SpeechResult {
  final String text;
  final bool isFinal;

  const SpeechResult({required this.text, required this.isFinal});

  @override
  String toString() => 'SpeechResult(text: $text, isFinal: $isFinal)';
}
