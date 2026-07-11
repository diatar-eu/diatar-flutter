import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing audio files associated with slides.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// Plays the audio file at the given [path].
  /// If [path] is null or empty, it stops any current playback.
  Future<void> playSound(String? path) async {
    if (path == null || path.trim().isEmpty) {
      await _player.stop();
      return;
    }

    try {
      // Stop current playback before starting a new one
      await _player.stop();
      // Play the file from the local device storage
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      // Log error but don't crash the app
      debugPrint('AudioService Error: Failed to play sound at $path - $e');
    }
  }

  /// Stops any current audio playback.
  Future<void> stop() async {
    await _player.stop();
  }

  /// Disposes the audio player resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}