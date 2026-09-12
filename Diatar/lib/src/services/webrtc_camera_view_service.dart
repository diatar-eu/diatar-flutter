import 'dart:async';

import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef CameraSignalOut =
    Future<void> Function(CameraSignal signal, String? sourceKey);

class WebrtcCameraViewService {
  WebrtcCameraViewService({required this.sendSignal});

  final CameraSignalOut sendSignal;

  RTCVideoRenderer? _renderer;
  RTCPeerConnection? _peer;
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];

  bool _active = false;
  bool _remoteDescriptionSet = false;
  bool _negotiating = false;
  String? _currentPeerKey;

  bool get active => _active;
  bool get available => _available();
  RTCVideoRenderer get renderer {
    if (_renderer == null) {
      _renderer = RTCVideoRenderer();
      unawaited(_renderer!.initialize());
    }
    return _renderer!;
  }

  bool _available() {
    if (kIsWeb) {
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
    if (_active) {
      return;
    }
    if (_renderer != null) {
      await _renderer!.dispose();
    }
    final RTCVideoRenderer renderer = RTCVideoRenderer();
    _renderer = renderer;
    await renderer.initialize();
  }

  Future<void> requestStart() async {
    if (!available) {
      return;
    }
    unawaited(
      sendSignal(const CameraSignal(kind: CameraSignalKind.request), null),
    );
  }

  Future<void> handleSignal(CameraSignal signal, String sourceKey) async {
    if (!available) {
      return;
    }
    _currentPeerKey = sourceKey;
    debugPrint('CAM answerer in ${signal.kind.name}');
    switch (signal.kind) {
      case CameraSignalKind.offer:
        if (signal.sdp != null) {
          if (_negotiating) {
            return;
          }
          _negotiating = true;
          try {
            if (_peer == null) {
              await _ensurePeer();
            }
            debugPrint('CAM answerer offer.len=${signal.sdp!.length}');
            await _peer!.setRemoteDescription(
              RTCSessionDescription(signal.sdp!, 'offer'),
            );
            _remoteDescriptionSet = true;
            for (final RTCIceCandidate candidate in _pendingCandidates) {
              await _peer!.addCandidate(candidate);
            }
            _pendingCandidates.clear();
            final RTCSessionDescription answer = await _peer!.createAnswer();
            debugPrint('CAM answerer answer.len=${answer.sdp?.length}');
            await _peer!.setLocalDescription(answer);
            unawaited(sendSignal(CameraSignal(
              kind: CameraSignalKind.answer,
              sdp: answer.sdp,
            ), _currentPeerKey));
          } finally {
            _negotiating = false;
          }
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
        debugPrint('CAM answerer ice in buffered=${!_remoteDescriptionSet}');
        if (_remoteDescriptionSet && _peer != null) {
          await _peer!.addCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }
        break;
      case CameraSignalKind.request:
      case CameraSignalKind.answer:
      case CameraSignalKind.stop:
        break;
    }
  }

  Future<void> _ensurePeer() async {
    if (_peer != null) {
      return;
    }
    final Map<String, Object> config = <String, Object>{
      'iceServers': <Map<String, Object>>[
        <String, Object>{'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    final RTCPeerConnection peer = await createPeerConnection(config);
    _peer = peer;
    peer.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('CAM answerer ice out ${candidate.candidate}');
      unawaited(sendSignal(CameraSignal(
        kind: CameraSignalKind.ice,
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      ), _currentPeerKey));
    };
    peer.onTrack = (RTCTrackEvent event) {
      debugPrint('CAM answerer onTrack ${event.track.kind}');
      if (event.track.kind == 'video') {
        _renderer!.srcObject = event.streams.isNotEmpty
            ? event.streams.first
            : null;
        _active = true;
      }
    };
    peer.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('CAM answerer conn $state');
    };
    peer.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('CAM answerer iceConn $state');
    };
  }

  Future<void> stop({bool sendStop = true}) async {
    _active = false;
    _remoteDescriptionSet = false;
    _negotiating = false;
    _pendingCandidates.clear();
    if (_peer != null) {
      await _peer!.close();
      _peer = null;
    }
    if (sendStop) {
      unawaited(
        sendSignal(const CameraSignal(kind: CameraSignalKind.stop), _currentPeerKey),
      );
    }
  }

  Future<void> dispose() async {
    await stop(sendStop: false);
  }
}
