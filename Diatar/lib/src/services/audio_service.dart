import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../utils/file_system_provider.dart';

enum AudioPlaybackState { started, stopped, failed }

class AudioPlaybackResult {
  const AudioPlaybackResult(this.state, {this.path, this.error});

  final AudioPlaybackState state;
  final String? path;
  final Object? error;
}

/// Service for playing audio files associated with slides.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Plays the audio file at the given [path].
  /// If [path] is null or empty, it stops any current playback.
  Future<AudioPlaybackResult> playSound(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return stop();
    }

    try {
      final bool exists = await FileSystemProvider.instance.file(path).exists();
      if (!exists) {
        return AudioPlaybackResult(
          AudioPlaybackState.failed,
          path: path,
          error: StateError('File not found'),
        );
      }
      // Stop current playback before starting a new one
      await _player.stop();
      // Play the file from the local device storage
      await _player.play(DeviceFileSource(path));
      return AudioPlaybackResult(AudioPlaybackState.started, path: path);
    } catch (e) {
      // Log error but don't crash the app
      debugPrint('AudioService Error: Failed to play sound at $path - $e');
      return AudioPlaybackResult(
        AudioPlaybackState.failed,
        path: path,
        error: e,
      );
    }
  }

  /// Stops any current audio playback.
  Future<AudioPlaybackResult> stop() async {
    try {
      await _player.stop();
      return const AudioPlaybackResult(AudioPlaybackState.stopped);
    } catch (e) {
      debugPrint('AudioService Error: Failed to stop sound - $e');
      return AudioPlaybackResult(AudioPlaybackState.failed, error: e);
    }
  }

  /// Disposes the audio player resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
