import 'dart:convert';
import 'dart:io';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter/foundation.dart';

class CastService extends ChangeNotifier {
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  GoogleCastDevice? _connectedDevice;
  GoogleCastDevice? get connectedDevice => _connectedDevice;

  List<GoogleCastDevice> _discoveredDevices = <GoogleCastDevice>[];
  List<GoogleCastDevice> get discoveredDevices => _discoveredDevices;

  CastService() {
    GoogleCastSessionManager.instance.currentSessionStream.listen((session) {
      _isConnected = session != null;
      if (session != null) {
        _connectedDevice = session.device;
      } else {
        _connectedDevice = null;
      }
      notifyListeners();
    });

    GoogleCastDiscoveryManager.instance.devicesStream.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
    });
  }

  bool get isSupported => false && !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    
    if (!isSupported) return;

    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    GoogleCastOptions? options;

    if (Platform.isIOS) {
      options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
        stopCastingOnAppTerminated: true,
      );
    } else if (Platform.isAndroid) {
      options = GoogleCastOptionsAndroid(
        appId: appId,
        stopCastingOnAppTerminated: true,
      );
    }

    if (options != null) {
      await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    }
  }

  Future<void> startDiscovery() async {
    if (!isSupported) return;
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    if (!isSupported) return;
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
  }

  Future<void> connectToDevice(GoogleCastDevice device) async {
    if (!isSupported) return;
    try {
      await GoogleCastSessionManager.instance.startSessionWithDevice(device);
      _connectedDevice = device;
      notifyListeners();
    } catch (e) {
      debugPrint('Cast connection error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await GoogleCastSessionManager.instance.endSession();
      _connectedDevice = null;
      _isConnected = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Cast disconnect error: $e');
    }
  }

  /// Sends slide data to the Cast receiver.
  /// We use loadMedia with customData to send information to the receiver.
  /// The receiver app can read this customData to render the slide.
  Future<void> sendCastData(Map<String, dynamic> data) async {
    if (!isSupported || !_isConnected) return;

    try {
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: 'diatar_slide',
          streamType: CastMediaStreamType.none,
          contentType: 'application/json',
          customData: data,
        ),
      );
    } catch (e) {
      debugPrint('Cast send data error: $e');
    }
  }

  /// Sends a raw image to the Cast receiver.
  Future<void> sendCastImage(Uint8List bytes, String contentType) async {
    if (!isSupported || !_isConnected) return;

    try {
      final String base64Image = base64Encode(bytes);
      
      // The default Google Cast receiver requires a valid HTTP/HTTPS URL for contentId.
      // Data URIs are often rejected by the native SDK (causing "fail to generate media info").
      // For a production app, these images should be uploaded to a temporary server.
      // As a fallback to verify connectivity, we use a known valid image URL.
      final String fallbackUrl = 'https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png';

      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: fallbackUrl, 
          streamType: CastMediaStreamType.buffered,
          contentType: contentType,
          customData: {
            'image': base64Image,
            'is_projection': true,
          },
        ),
      );
    } catch (e) {
      debugPrint('Cast send image error: $e');
    }
  }
}