import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/system_platform.dart';

typedef CameraSignalOut = Future<void> Function(CameraSignal signal);

class WebrtcCameraService {
  WebrtcCameraService({required this.sendSignal});

  final CameraSignalOut sendSignal;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peer;
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  bool _active = false;
  bool _remoteDescriptionSet = false;
  String? selectedDeviceId;

  bool get active => _active;
  bool get available => _available();
  RTCVideoRenderer get localRenderer => _localRenderer;

  bool _available() {
    if (kIsWeb || SystemPlatform.isTvOs) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  Future<void> init() async {
    _localRenderer.initialize();
  }

  Future<List<MediaDeviceInfo>> listDevices() async {
    if (!available) {
      return const <MediaDeviceInfo>[];
    }
    try {
      final List<MediaDeviceInfo> all = await navigator.mediaDevices.enumerateDevices();
      return all.where((MediaDeviceInfo d) => d.kind == 'videoinput').toList();
    } catch (_) {
      return const <MediaDeviceInfo>[];
    }
  }

  Future<void> start({String? deviceId}) async {
    if (!available) {
      return;
    }
    await stop(sendStop: false);
    selectedDeviceId = deviceId;
    debugPrint('CAM offerer start device=$selectedDeviceId');
    try {
      final Map<String, Object> video = <String, Object>{
        'width': 1280,
        'height': 720,
        'frameRate': 30,
        if (selectedDeviceId != null && selectedDeviceId!.isNotEmpty)
          'deviceId': selectedDeviceId!,
      };
      final MediaStream stream =
          await navigator.mediaDevices.getUserMedia(<String, Object>{
        'audio': false,
        'video': video,
      });
      _localStream = stream;
      _localRenderer.srcObject = stream;

      final Map<String, Object> config = <String, Object>{
        'iceServers': <Map<String, Object>>[
          <String, Object>{'urls': 'stun:stun.l.google.com:19302'},
        ],
      };
      final RTCPeerConnection peer = await createPeerConnection(config);
      _peer = peer;
      stream.getTracks().forEach((MediaStreamTrack track) {
        peer.addTrack(track, stream);
      });
      peer.onIceCandidate = (RTCIceCandidate candidate) {
        debugPrint('CAM offerer ice out ${candidate.candidate}');
        unawaited(sendSignal(CameraSignal(
          kind: CameraSignalKind.ice,
          candidate: candidate.candidate,
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        )));
      };
      peer.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('CAM offerer conn $state');
      };
      peer.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('CAM offerer iceConn $state');
      };
      debugPrint('CAM offerer active');
      _active = true;
    } catch (_) {
      await stop(sendStop: false);
      rethrow;
    }
  }

  Future<void> handleSignal(CameraSignal signal) async {
    if (!available) {
      return;
    }
    debugPrint('CAM offerer in ${signal.kind.name}');
    switch (signal.kind) {
      case CameraSignalKind.request:
        if (_active && _peer != null) {
          debugPrint('CAM offerer reuse');
          await sendOffer();
        } else {
          await start(deviceId: selectedDeviceId);
          await sendOffer();
        }
        break;
      case CameraSignalKind.answer:
        if (signal.sdp != null) {
          debugPrint('CAM offerer answer.len=${signal.sdp!.length}');
          await _peer!.setRemoteDescription(
            RTCSessionDescription(signal.sdp!, 'answer'),
          );
          _remoteDescriptionSet = true;
          for (final RTCIceCandidate candidate in _pendingCandidates) {
            await _peer!.addCandidate(candidate);
          }
          _pendingCandidates.clear();
        }
        break;
      case CameraSignalKind.ice:
        if (signal.candidate == null) {
          break;
        }
        final RTCIceCandidate candidate = RTCIceCandidate(
          signal.candidate!,
          signal.sdpMid,
          signal.sdpMLineIndex ?? 0,
        );
        debugPrint('CAM offerer ice in buffered=${!_remoteDescriptionSet}');
        if (_remoteDescriptionSet && _peer != null) {
          await _peer!.addCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }
        break;
      case CameraSignalKind.offer:
        break;
      case CameraSignalKind.stop:
        debugPrint('CAM offerer stop received');
        await stop(sendStop: false);
        break;
    }
  }

  Future<void> sendOffer() async {
    if (!_active || _peer == null) {
      return;
    }
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    final RTCSessionDescription offer = await _peer!.createOffer();
    debugPrint('CAM offerer sdp.len=${offer.sdp?.length}');
    await _peer!.setLocalDescription(offer);
    unawaited(sendSignal(CameraSignal(
      kind: CameraSignalKind.offer,
      sdp: offer.sdp,
    )));
  }

  Future<void> stop({bool sendStop = true}) async {
    _active = false;
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    if (_peer != null) {
      await _peer!.close();
      _peer = null;
    }
    if (_localStream != null) {
      await _localStream!.dispose();
    }
    _localStream = null;
    _localRenderer.srcObject = null;
    if (sendStop) {
      unawaited(sendSignal(const CameraSignal(kind: CameraSignalKind.stop)));
    }
  }

  Future<void> dispose() async {
    await stop(sendStop: false);
    await _localRenderer.dispose();
  }
}
