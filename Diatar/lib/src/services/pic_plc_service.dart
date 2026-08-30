import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Background bridge for the PICPLC serial controller on desktop platforms.
///
/// The native implementation owns the serial port and polls it at 20 Hz, so
/// Flutter UI work cannot delay the protocol.
class PicPlcService {
  PicPlcService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'diatar/pic_plc';

  final MethodChannel _channel;

  Future<void> open(String port) async {
    _ensureDesktop();
    final String normalizedPort = port.trim();
    if (normalizedPort.isEmpty) {
      throw ArgumentError.value(port, 'port', 'must not be empty');
    }
    await _channel.invokeMethod<void>('open', <String, Object>{
      'port': normalizedPort,
    });
  }

  Future<void> close() async {
    _ensureDesktop();
    await _channel.invokeMethod<void>('close');
  }

  /// Updates the two PICPLC output LEDs. The change is sent by the native
  /// polling worker no later than its next 50 ms cycle.
  Future<void> setLeds({required bool led1, required bool led2}) async {
    _ensureDesktop();
    await _channel.invokeMethod<void>('setLeds', <String, Object>{
      'led1': led1,
      'led2': led2,
    });
  }

  /// Returns the latest valid PICPLC button bits (bit 0 through bit 7).
  ///
  /// A set bit represents a pressed button. Invalid or incomplete responses
  /// are discarded by the native worker, leaving the previous state intact.
  Future<int> buttonMask() async {
    _ensureDesktop();
    return (await _channel.invokeMethod<int>('buttonMask')) ?? 0;
  }

  @visibleForTesting
  static Uint8List ledCommand({required bool led1, required bool led2}) {
    final int states = (led1 ? 0x01 : 0) | (led2 ? 0x02 : 0);
    return Uint8List.fromList(<int>[0x21, 0, states, states]);
  }

  void _ensureDesktop() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.linux)) {
      throw UnsupportedError('PICPLC is available only on Windows and Linux.');
    }
  }
}
