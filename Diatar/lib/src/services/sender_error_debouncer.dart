import 'package:flutter/foundation.dart';

class SenderErrorDebouncer {
  int _mqttSeq = 0;
  int _tcpSeq = 0;

  void invalidateAll() {
    _mqttSeq++;
    _tcpSeq++;
  }

  void scheduleTcp({
    required bool Function() isActive,
    required bool Function() isConnected,
    required VoidCallback onConfirmed,
  }) {
    _tcpSeq++;
    final int token = _tcpSeq;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (token != _tcpSeq || !isActive() || isConnected()) {
        return;
      }
      onConfirmed();
    });
  }

  void scheduleMqtt({
    required bool Function() isActive,
    required bool Function() isConnected,
    required VoidCallback onConfirmed,
  }) {
    _mqttSeq++;
    final int token = _mqttSeq;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (token != _mqttSeq || !isActive() || isConnected()) {
        return;
      }
      onConfirmed();
    });
  }
}