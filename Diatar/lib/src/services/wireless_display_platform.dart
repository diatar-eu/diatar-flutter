import 'dart:async';

enum WirelessDisplayConnectionState {
  disconnected,
  discovering,
  connecting,
  connected,
  streaming,
  error,
}

class WirelessDisplayDevice {
  const WirelessDisplayDevice({
    required this.id,
    required this.name,
    this.iconPath,
  });

  final String id;
  final String name;
  final String? iconPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WirelessDisplayDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'WirelessDisplayDevice(id: $id, name: $name)';
}

abstract class WirelessDisplayPlatform {
  Future<void> initialize();

  // Discovery
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Stream<List<WirelessDisplayDevice>> get devicesStream;

  // Connection
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Stream<WirelessDisplayConnectionState> get connectionStateStream;
  WirelessDisplayConnectionState get connectionState;

  // Streaming
  Future<void> startStreaming({required int width, required int height, required int fps});
  Future<void> stopStreaming();

  // Settings
  bool get isConnected;
  String? get connectedDeviceId;

  // System picker (Android: MediaRouter dialog, iOS: AVRoutePickerView)
  Future<bool> showSystemPicker();

  // RTSP URL of the running stream (null when no server is listening yet)
  Future<String?> getStreamUrl();

  Future<void> dispose();
}

class WirelessDisplayDeviceList {
  final List<WirelessDisplayDevice> devices;
  final bool isDiscovering;

  const WirelessDisplayDeviceList({required this.devices, required this.isDiscovering});
}