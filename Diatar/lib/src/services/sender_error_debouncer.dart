import 'package:flutter/foundation.dart';

class SenderErrorDebouncer {
  /// Ennyi idő után erősíti meg a hibát, ha a kapcsolat még mindig nem áll
  /// helyre. Elég hosszú ahhoz, hogy a forgatáskor (Android Wi-Fi átmeneti
  /// megszakadásakor) ne riasszon, de a valódi kiesést így is jelzi.
  static const Duration _confirmDelay = Duration(seconds: 4);

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
    Future<void>.delayed(_confirmDelay, () {
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
    Future<void>.delayed(_confirmDelay, () {
      if (token != _mqttSeq || !isActive() || isConnected()) {
        return;
      }
      onConfirmed();
    });
  }
}