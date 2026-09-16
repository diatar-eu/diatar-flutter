import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wireless_display_platform.dart';

class WirelessDisplayPlatformFactory {
  WirelessDisplayPlatformFactory._();

  static final WirelessDisplayPlatformFactory instance = WirelessDisplayPlatformFactory._();

  WirelessDisplayPlatform? _platform;

  WirelessDisplayPlatform _createPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _AndroidWirelessDisplay();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _IOSWirelessDisplay();
    }
    return _UnsupportedWirelessDisplay();
  }

  WirelessDisplayPlatform get platform {
    final WirelessDisplayPlatform? existing = _platform;
    if (existing != null) {
      return existing;
    }
    final WirelessDisplayPlatform created = _createPlatform();
    _platform = created;
    return created;
  }

  Future<WirelessDisplayPlatform> initialize() async {
    final WirelessDisplayPlatform platform = this.platform;
    await platform.initialize();
    return platform;
  }
}

abstract class _PlatformWirelessDisplay implements WirelessDisplayPlatform {
  final _devicesController = StreamController<List<WirelessDisplayDevice>>.broadcast();
  final _connectionStateController = StreamController<WirelessDisplayConnectionState>.broadcast();

  @override
  Stream<List<WirelessDisplayDevice>> get devicesStream => _devicesController.stream;

  @override
  Stream<WirelessDisplayConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  Future<void> initialize();

  @override
  Future<void> startDiscovery();

  @override
  Future<void> stopDiscovery();

  @override
  Future<void> connect(String deviceId);

  @override
  Future<void> disconnect();

  @override
  Future<void> startStreaming({required int width, required int height, required int fps});

  @override
  Future<void> stopStreaming();

  @override
  Future<bool> showSystemPicker();

  @override
  Future<String?> getStreamUrl();

  @override
  Future<void> dispose();

  @override
  WirelessDisplayConnectionState get connectionState;

  @override
  bool get isConnected;

  @override
  String? get connectedDeviceId;

  void _emitDevices(List<WirelessDisplayDevice> devices) {
    _devicesController.add(devices);
  }
}

class _AndroidWirelessDisplay extends _PlatformWirelessDisplay {
  static const MethodChannel _channel = MethodChannel('diatar/wireless_display');

  WirelessDisplayConnectionState _connectionState = WirelessDisplayConnectionState.disconnected;
  String? _connectedDeviceId;

  @override
  WirelessDisplayConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => _connectedDeviceId != null;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> startDiscovery() async {
    if (_connectionState == WirelessDisplayConnectionState.discovering) return;
    _connectionState = WirelessDisplayConnectionState.discovering;
    _connectionStateController.add(_connectionState);
    await _channel.invokeMethod('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
    if (_connectionState == WirelessDisplayConnectionState.discovering) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    if (_connectionState == WirelessDisplayConnectionState.connecting || isConnected) return;
    _connectionState = WirelessDisplayConnectionState.connecting;
    _connectionStateController.add(_connectionState);
    await _channel.invokeMethod('connect', {'deviceId': deviceId});
    _connectedDeviceId = deviceId;
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
    _connectedDeviceId = null;
    if (_connectionState != WirelessDisplayConnectionState.disconnected) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  @override
  Future<void> startStreaming({required int width, required int height, required int fps}) async {
    // Android implementation will handle frame encoding in native code
    // We just signal the native side to start the streaming pipeline
    await _channel.invokeMethod('startStreaming', {
      'width': width,
      'height': height,
      'fps': fps,
    });
  }

  @override
  Future<void> stopStreaming() async {
    await _channel.invokeMethod('stopStreaming');
  }

  @override
  Future<bool> showSystemPicker() async {
    final result = await _channel.invokeMethod('showSystemPicker');
    return result as bool? ?? false;
  }

  @override
  Future<String?> getStreamUrl() async {
    return await _channel.invokeMethod<String>('getStreamUrl');
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
    await _devicesController.close();
    await _connectionStateController.close();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDevicesChanged':
        final List<dynamic> devices = call.arguments as List<dynamic>;
        final deviceList = devices
            .map((d) => WirelessDisplayDevice(
                  id: d['id'] as String,
                  name: d['name'] as String,
                  iconPath: d['iconPath'] as String?,
                ))
            .toList();
        _emitDevices(deviceList);
        break;
      case 'onConnectionStateChanged':
        final String state = call.arguments['state'] as String;
        _connectionState = _parseConnectionState(state);
        _connectedDeviceId = call.arguments['deviceId'] as String?;
        _connectionStateController.add(_connectionState);
        break;
      case 'onStreamingStateChanged':
        break;
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  WirelessDisplayConnectionState _parseConnectionState(String state) {
    switch (state) {
      case 'disconnected':
        return WirelessDisplayConnectionState.disconnected;
      case 'discovering':
        return WirelessDisplayConnectionState.discovering;
      case 'connecting':
        return WirelessDisplayConnectionState.connecting;
      case 'connected':
        return WirelessDisplayConnectionState.connected;
      case 'streaming':
        return WirelessDisplayConnectionState.streaming;
      case 'error':
        return WirelessDisplayConnectionState.error;
      default:
        return WirelessDisplayConnectionState.disconnected;
    }
  }
}

class _IOSWirelessDisplay extends _PlatformWirelessDisplay {
  static const MethodChannel _channel = MethodChannel('diatar/wireless_display');

  WirelessDisplayConnectionState _connectionState = WirelessDisplayConnectionState.disconnected;
  String? _connectedDeviceId;

  @override
  WirelessDisplayConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => _connectedDeviceId != null;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> startDiscovery() async {
    if (_connectionState == WirelessDisplayConnectionState.discovering) return;
    _connectionState = WirelessDisplayConnectionState.discovering;
    _connectionStateController.add(_connectionState);
    await _channel.invokeMethod('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
    if (_connectionState == WirelessDisplayConnectionState.discovering) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    if (_connectionState == WirelessDisplayConnectionState.connecting || isConnected) return;
    _connectionState = WirelessDisplayConnectionState.connecting;
    _connectionStateController.add(_connectionState);
    await _channel.invokeMethod('connect', {'deviceId': deviceId});
    _connectedDeviceId = deviceId;
  }

  @override
  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
    _connectedDeviceId = null;
    if (_connectionState != WirelessDisplayConnectionState.disconnected) {
      _connectionState = WirelessDisplayConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
    }
  }

  @override
  Future<void> startStreaming({required int width, required int height, required int fps}) async {
    // iOS implementation will handle frame encoding in native code
    await _channel.invokeMethod('startStreaming', {
      'width': width,
      'height': height,
      'fps': fps,
    });
  }

  @override
  Future<void> stopStreaming() async {
    await _channel.invokeMethod('stopStreaming');
  }

  @override
  Future<bool> showSystemPicker() async {
    final result = await _channel.invokeMethod('showSystemPicker');
    return result as bool? ?? false;
  }

  @override
  Future<String?> getStreamUrl() async {
    return await _channel.invokeMethod<String>('getStreamUrl');
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
    await _devicesController.close();
    await _connectionStateController.close();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDevicesChanged':
        final List<dynamic> devices = call.arguments as List<dynamic>;
        final deviceList = devices
            .map((d) => WirelessDisplayDevice(
                  id: d['id'] as String,
                  name: d['name'] as String,
                  iconPath: d['iconPath'] as String?,
                ))
            .toList();
        _emitDevices(deviceList);
        break;
      case 'onConnectionStateChanged':
        final String state = call.arguments['state'] as String;
        _connectionState = _parseConnectionState(state);
        _connectedDeviceId = call.arguments['deviceId'] as String?;
        _connectionStateController.add(_connectionState);
        break;
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  WirelessDisplayConnectionState _parseConnectionState(String state) {
    switch (state) {
      case 'disconnected':
        return WirelessDisplayConnectionState.disconnected;
      case 'discovering':
        return WirelessDisplayConnectionState.discovering;
      case 'connecting':
        return WirelessDisplayConnectionState.connecting;
      case 'connected':
        return WirelessDisplayConnectionState.connected;
      case 'streaming':
        return WirelessDisplayConnectionState.streaming;
      case 'error':
        return WirelessDisplayConnectionState.error;
      default:
        return WirelessDisplayConnectionState.disconnected;
    }
  }
}

class _UnsupportedWirelessDisplay extends _PlatformWirelessDisplay {
  final WirelessDisplayConnectionState _connectionState = WirelessDisplayConnectionState.disconnected;

  @override
  WirelessDisplayConnectionState get connectionState => _connectionState;

  @override
  bool get isConnected => false;

  @override
  String? get connectedDeviceId => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> startStreaming({required int width, required int height, required int fps}) async {}

  @override
  Future<void> stopStreaming() async {}

  @override
  Future<bool> showSystemPicker() async => false;

  @override
  Future<String?> getStreamUrl() async => null;

  @override
  Future<void> dispose() async {
    await _devicesController.close();
    await _connectionStateController.close();
  }
}