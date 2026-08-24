import 'dart:convert';
import 'package:http/http.dart' as http;

enum SpeechModelType {
  nemotron35_80ms,
  nemotron35_160ms,
  nemotron35_560ms,
  nemotron35_1120ms,
  qwen3Asr06b,
  whisperTiny,
  whisperBase,
  whisperSmall,
  whisperMedium,
  whisperLargeV3,
  whisperTurbo,
}

class SpeechModelInfo {
  final SpeechModelType type;
  final String displayName;
  final String dirName;
  final String downloadUrl;
  final List<String> requiredFiles;
  final bool isStreaming;
  final int? latencyMs;
  final String category;
  final String whisperPrefix;

  const SpeechModelInfo({
    required this.type,
    required this.displayName,
    required this.dirName,
    required this.downloadUrl,
    required this.requiredFiles,
    required this.isStreaming,
    this.latencyMs,
    required this.category,
    this.whisperPrefix = '',
  });
}

const String _kReleaseUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';
const String _kApiUrl =
    'https://api.github.com/repos/k2-fsa/sherpa-onnx/releases/tags/asr-models';

const String kVadModelUrl =
    '$_kReleaseUrl/silero_vad.onnx';
const String kVadModelFileName = 'silero_vad.onnx';

const Map<SpeechModelType, SpeechModelInfo> kSpeechModels = {
  SpeechModelType.nemotron35_80ms: SpeechModelInfo(
    type: SpeechModelType.nemotron35_80ms,
    displayName: 'Nemotron 3.5 0.6B – 80ms',
    dirName: 'sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-80ms-int8-2026-06-11',
    downloadUrl:
        '$_kReleaseUrl/sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-80ms-int8-2026-06-11.tar.bz2',
    requiredFiles: ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'],
    isStreaming: true,
    latencyMs: 80,
    category: 'streaming',
  ),
  SpeechModelType.nemotron35_160ms: SpeechModelInfo(
    type: SpeechModelType.nemotron35_160ms,
    displayName: 'Nemotron 3.5 0.6B – 160ms',
    dirName: 'sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-160ms-int8-2026-06-11',
    downloadUrl:
        '$_kReleaseUrl/sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-160ms-int8-2026-06-11.tar.bz2',
    requiredFiles: ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'],
    isStreaming: true,
    latencyMs: 160,
    category: 'streaming',
  ),
  SpeechModelType.nemotron35_560ms: SpeechModelInfo(
    type: SpeechModelType.nemotron35_560ms,
    displayName: 'Nemotron 3.5 0.6B – 560ms',
    dirName: 'sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-560ms-int8-2026-06-11',
    downloadUrl:
        '$_kReleaseUrl/sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-560ms-int8-2026-06-11.tar.bz2',
    requiredFiles: ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'],
    isStreaming: true,
    latencyMs: 560,
    category: 'streaming',
  ),
  SpeechModelType.nemotron35_1120ms: SpeechModelInfo(
    type: SpeechModelType.nemotron35_1120ms,
    displayName: 'Nemotron 3.5 0.6B – 1120ms',
    dirName:
        'sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-1120ms-int8-2026-06-11',
    downloadUrl:
        '$_kReleaseUrl/sherpa-onnx-nemotron-3.5-asr-streaming-0.6b-1120ms-int8-2026-06-11.tar.bz2',
    requiredFiles: ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt'],
    isStreaming: true,
    latencyMs: 1120,
    category: 'streaming',
  ),
  SpeechModelType.qwen3Asr06b: SpeechModelInfo(
    type: SpeechModelType.qwen3Asr06b,
    displayName: 'Qwen3-ASR 0.6B',
    dirName: 'sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25',
    downloadUrl:
        '$_kReleaseUrl/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2',
    requiredFiles: [
      'conv_frontend.onnx',
      'encoder.int8.onnx',
      'decoder.int8.onnx',
      'tokenizer/vocab.json',
    ],
    isStreaming: false,
    category: 'offline',
  ),
  SpeechModelType.whisperTiny: SpeechModelInfo(
    type: SpeechModelType.whisperTiny,
    displayName: 'Whisper tiny',
    dirName: 'sherpa-onnx-whisper-tiny',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-tiny.tar.bz2',
    requiredFiles: ['tiny-encoder.int8.onnx', 'tiny-decoder.int8.onnx', 'tiny-tokens.txt'],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'tiny-',
  ),
  SpeechModelType.whisperBase: SpeechModelInfo(
    type: SpeechModelType.whisperBase,
    displayName: 'Whisper base',
    dirName: 'sherpa-onnx-whisper-base',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-base.tar.bz2',
    requiredFiles: ['base-encoder.int8.onnx', 'base-decoder.int8.onnx', 'base-tokens.txt'],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'base-',
  ),
  SpeechModelType.whisperSmall: SpeechModelInfo(
    type: SpeechModelType.whisperSmall,
    displayName: 'Whisper small',
    dirName: 'sherpa-onnx-whisper-small',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-small.tar.bz2',
    requiredFiles: ['small-encoder.int8.onnx', 'small-decoder.int8.onnx', 'small-tokens.txt'],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'small-',
  ),
  SpeechModelType.whisperMedium: SpeechModelInfo(
    type: SpeechModelType.whisperMedium,
    displayName: 'Whisper medium',
    dirName: 'sherpa-onnx-whisper-medium',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-medium.tar.bz2',
    requiredFiles: ['medium-encoder.int8.onnx', 'medium-decoder.int8.onnx', 'medium-tokens.txt'],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'medium-',
  ),
  SpeechModelType.whisperLargeV3: SpeechModelInfo(
    type: SpeechModelType.whisperLargeV3,
    displayName: 'Whisper large-v3',
    dirName: 'sherpa-onnx-whisper-large-v3',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-large-v3.tar.bz2',
    requiredFiles: [
      'large-v3-encoder.int8.onnx',
      'large-v3-decoder.int8.onnx',
      'large-v3-tokens.txt',
    ],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'large-v3-',
  ),
  SpeechModelType.whisperTurbo: SpeechModelInfo(
    type: SpeechModelType.whisperTurbo,
    displayName: 'Whisper large-v3-turbo',
    dirName: 'sherpa-onnx-whisper-large-v3-turbo',
    downloadUrl: '$_kReleaseUrl/sherpa-onnx-whisper-large-v3-turbo.tar.bz2',
    requiredFiles: [
      'large-v3-turbo-encoder.int8.onnx',
      'large-v3-turbo-decoder.int8.onnx',
      'large-v3-turbo-tokens.txt',
    ],
    isStreaming: false,
    category: 'whisper',
    whisperPrefix: 'large-v3-turbo-',
  ),
};

SpeechModelInfo getSpeechModel(SpeechModelType type) {
  return kSpeechModels[type]!;
}

List<SpeechModelInfo> getSpeechModelsByCategory(String category) {
  return kSpeechModels.values.where((m) => m.category == category).toList();
}

List<String> getSpeechModelCategories() {
  return kSpeechModels.values.map((m) => m.category).toSet().toList();
}

class GitHubReleaseSizeCache {
  static Map<String, int>? _cache;
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(hours: 24);

  static Future<int> getFileSize(String fileName) async {
    final Map<String, int> sizes = await _fetchSizes();
    return sizes[fileName] ?? 0;
  }

  static Future<Map<String, int>> getAllSizes() async {
    return _fetchSizes();
  }

  static Future<Map<String, int>> _fetchSizes() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cache!;
    }

    try {
      final response = await http.get(
        Uri.parse(_kApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        return _cache ?? {};
      }

      final dynamic json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return _cache ?? {};

      final List<dynamic>? assets = json['assets'] as List<dynamic>?;
      if (assets == null) return _cache ?? {};

      final Map<String, int> sizes = {};
      for (final dynamic asset in assets) {
        if (asset is Map<String, dynamic>) {
          final String? name = asset['name'] as String?;
          final int? size = asset['size'] as int?;
          if (name != null && size != null) {
            sizes[name] = size;
          }
        }
      }

      _cache = sizes;
      _cacheTime = DateTime.now();
      return sizes;
    } catch (e) {
      return _cache ?? {};
    }
  }

  static void clearCache() {
    _cache = null;
    _cacheTime = null;
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '?';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    final double mb = bytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(0)} MB';
    }
    final double gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }
}
