import 'dart:async';

import 'wireless_display_platform.dart';
import 'wireless_display_impl.dart';
import 'wireless_display_frame_capture.dart';
import 'wireless_display_encoder.dart';

class WirelessDisplayService {
  WirelessDisplayService._();

  static final WirelessDisplayService instance = WirelessDisplayService._();

  static WirelessDisplayPlatform get _platform => WirelessDisplayPlatformFactory.instance.platform;

  // Stream controllers
  final _devicesController = StreamController<List<WirelessDisplayDevice>>.broadcast();
  final _connectionStateController = StreamController<WirelessDisplayConnectionState>.broadcast();

  // Public streams
  Stream<List<WirelessDisplayDevice>> get devicesStream => _devicesController.stream;
  Stream<WirelessDisplayConnectionState> get connectionStateStream => _connectionStateController.stream;

  // State
  WirelessDisplayConnectionState _connectionState = WirelessDisplayConnectionState.disconnected;
  List<WirelessDisplayDevice> _devices = const [];
  String? _connectedDeviceId;
  bool _isStreaming = false;

  // Getters
  WirelessDisplayConnectionState get connectionState => _connectionState;
  List<WirelessDisplayDevice> get devices => _devices;
  bool get isConnected => _connectionState == WirelessDisplayConnectionState.connected ||
      _connectionState == WirelessDisplayConnectionState.streaming;
  String? get connectedDeviceId => _connectedDeviceId;
  bool get isStreaming => _isStreaming;

  Future<void> initialize() async {
    await _platform.initialize();
    _platform.connectionStateStream.listen(_onConnectionStateChanged);
    _platform.devicesStream.listen(_onDevicesChanged);
  }

  void _onConnectionStateChanged(WirelessDisplayConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _onDevicesChanged(List<WirelessDisplayDevice> devices) {
    _devices = devices;
    _devicesController.add(devices);
  }

  // Discovery
  Future<void> startDiscovery() async {
    if (_connectionState == WirelessDisplayConnectionState.discovering) return;
    _connectionState = WirelessDisplayConnectionState.discovering;
    _connectionStateController.add(_connectionState);
    await _platform.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    await _platform.stopDiscovery();
    if (_connectionState == WirelessDisplayConnectionState.discovering) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  // System picker
  Future<bool> showSystemPicker() async {
    return await _platform.showSystemPicker();
  }

  // RTSP URL
  Future<String?> getStreamUrl() async {
    return await _platform.getStreamUrl();
  }

  // Connection
  Future<void> connect(String deviceId) async {
    if (_connectionState == WirelessDisplayConnectionState.connecting ||
        _connectionState == WirelessDisplayConnectionState.connected ||
        _connectionState == WirelessDisplayConnectionState.streaming) {
      return;
    }
    _connectionState = WirelessDisplayConnectionState.connecting;
    _connectionStateController.add(_connectionState);
    await _platform.connect(deviceId);
    _connectedDeviceId = deviceId;
  }

  Future<void> disconnect() async {
    if (_isStreaming) {
      await stopStreaming();
    }
    await _platform.disconnect();
    _connectedDeviceId = null;
    if (_connectionState != WirelessDisplayConnectionState.disconnected) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  // Streaming
  Future<void> startStreaming({required int width, required int height, required int fps}) async {
    if (_isStreaming) return;

    _isStreaming = true;
    _connectionState = WirelessDisplayConnectionState.streaming;
    _connectionStateController.add(_connectionState);

    try {
      // Start frame capture from the projection widget
      await WirelessDisplayFrameCapture.instance.startCapture(fps: fps, width: width, height: height);

      // Encode frames and hand them to the native side
      await WirelessDisplayEncoder.instance.startEncoding(
        frameStream: WirelessDisplayFrameCapture.instance.frameStream,
        fps: fps,
      );

      // Start native streaming pipeline
      await _platform.startStreaming(
        width: width,
        height: height,
        fps: fps,
      );
    } catch (e) {
      _isStreaming = false;
      _connectionState = WirelessDisplayConnectionState.error;
      _connectionStateController.add(_connectionState);
      rethrow;
    }
  }

  Future<void> stopStreaming() async {
    if (!_isStreaming) return;

    _isStreaming = false;
    _connectionState = WirelessDisplayConnectionState.connected;
    _connectionStateController.add(_connectionState);

    await WirelessDisplayEncoder.instance.stopEncoding();
    await WirelessDisplayFrameCapture.instance.stopCapture();
    await _platform.stopStreaming();
  }

  Future<void> dispose() async {
    await stopStreaming();
    await stopDiscovery();
    await _platform.dispose();
    await _devicesController.close();
    await _connectionStateController.close();
  }
}