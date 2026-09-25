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
  bool _disposed = false;

  /// Whether the texture came up. `RTCVideoRenderer.srcObject` says so only by
  /// throwing, and it is assigned to from a platform callback that has nowhere
  /// to report a failure — see [_setRendererStream].
  bool _rendererReady = false;

  /// The in-flight or finished [RTCVideoRenderer.initialize] call.
  ///
  /// One renderer may only be initialised once, here. The plugin's own
  /// `initialize()` awaits a completer that the first call completes only on
  /// success, so a second call after a failure waits on a completer nobody will
  /// ever complete — it hangs, rather than reporting the failure again. The
  /// getter and [init] both want the texture up, so they share this.
  Future<void>? _rendererInitializing;
  String? _currentPeerKey;

  bool get active => _active;
  bool get available => _available();

  /// The texture the camera picture is drawn into, built on first read.
  ///
  /// Created on demand because the camera view is only built when the setting is
  /// on. Assigned before initialising, so two reads in one build cannot produce
  /// two textures, and kept across [dispose] so a late read cannot conjure one
  /// that nobody will ever release.
  RTCVideoRenderer get renderer {
    final RTCVideoRenderer? existing = _renderer;
    if (existing != null) {
      return existing;
    }
    final RTCVideoRenderer renderer = RTCVideoRenderer();
    _renderer = renderer;
    unawaited(_ensureRendererInitialized(renderer));
    return renderer;
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

  /// Brings the texture up once, and records whether it made it.
  ///
  /// A texture that fails is reported and stepped over rather than thrown: the
  /// camera is a picture-in-picture overlay, and [init] is awaited on the
  /// startup path, so letting this escape would take the whole app down over an
  /// optional overlay on a platform that cannot give it a texture.
  Future<void> _ensureRendererInitialized(RTCVideoRenderer renderer) =>
      _rendererInitializing ??= _initializeRenderer(renderer);

  Future<void> _initializeRenderer(RTCVideoRenderer renderer) async {
    try {
      await renderer.initialize();
      // [dispose] may have run while the texture was coming up. A renderer
      // that is gone must not be marked ready.
      _rendererReady = !_disposed;
    } catch (error) {
      debugPrint('CAM answerer texture init failed: $error');
    }
  }

  /// Brings the texture up. Safe to call more than once: a texture that is
  /// already there is left alone rather than replaced, because the camera view
  /// is holding it and a swap would pull the picture out from under it.
  Future<void> init() async {
    if (_active || _disposed || _renderer != null) {
      return;
    }
    await _ensureRendererInitialized(renderer);
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
        _setRendererStream(
          event.streams.isNotEmpty ? event.streams.first : null,
        );
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

  /// Hands the incoming stream to the texture, if there is a texture to hand it
  /// to.
  ///
  /// This runs in a platform callback, which has nowhere to report a failure
  /// to, and `RTCVideoRenderer.srcObject` throws when the texture was never
  /// initialised — the renderer is built on demand, so the stream can land
  /// before its `initialize()` has finished. A texture that is not ready costs
  /// the picture-in-picture overlay and nothing else: the stream is received
  /// either way, and the next read of [renderer] or the next [init] brings the
  /// texture up.
  void _setRendererStream(MediaStream? stream) {
    final RTCVideoRenderer? renderer = _renderer;
    if (renderer == null || !_rendererReady) {
      return;
    }
    try {
      renderer.srcObject = stream;
    } catch (error) {
      debugPrint('CAM answerer texture not ready: $error');
    }
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

  /// Tears the connection down.
  ///
  /// The texture is deliberately left alone. [dispose] is called while the
  /// window is still being torn down, and `RTCVideoView` listens to the
  /// renderer through a `ValueListenableBuilder` — disposing it out from under
  /// a mounted view is a worse failure than the one being avoided. The
  /// platform frees the texture when the engine goes, which is what happens
  /// next either way.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop(sendStop: false);
  }
}
