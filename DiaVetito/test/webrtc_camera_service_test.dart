import 'package:diavetito/src/services/webrtc_camera_service.dart';
import 'package:diavetito/src/utils/system_platform.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WebrtcCameraService _service() =>
    WebrtcCameraService(sendSignal: (CameraSignal _) async {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SystemPlatform.debugSetTvOsOverride(null);
  });

  test(
    'camera capture and signalling work without a preview renderer',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const MethodChannel channel = MethodChannel('FlutterWebRTC.Method');
      const MethodChannel events = MethodChannel(
        'FlutterWebRTC/peerConnectionEventpeer-1',
      );
      final List<MethodCall> calls = <MethodCall>[];
      final List<CameraSignal> signals = <CameraSignal>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        switch (call.method) {
          case 'initialize':
          case 'setLocalDescription':
          case 'setRemoteDescription':
          case 'peerConnectionClose':
          case 'streamDispose':
            return null;
          case 'getUserMedia':
            return <String, Object>{
              'streamId': 'stream-1',
              'audioTracks': <Object>[],
              'videoTracks': <Object>[
                <String, Object>{
                  'id': 'video-1',
                  'label': 'Camera',
                  'kind': 'video',
                  'enabled': true,
                },
              ],
            };
          case 'createPeerConnection':
            return <String, Object>{'peerConnectionId': 'peer-1'};
          case 'addTrack':
            return <String, Object>{
              'senderId': 'sender-1',
              'track': <String, Object>{},
              'rtpParameters': <String, Object>{
                'encodings': <Object>[],
                'headerExtensions': <Object>[],
                'codecs': <Object>[],
                'rtcp': <String, Object>{'reducedSize': true},
              },
              'ownsTrack': false,
            };
          case 'createOffer':
            return <String, Object>{'sdp': 'v=0\r\n', 'type': 'offer'};
          default:
            fail('Unexpected WebRTC method: ${call.method}');
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(events, null);
      });

      final WebrtcCameraService service = WebrtcCameraService(
        sendSignal: (CameraSignal signal) async => signals.add(signal),
      );
      service.selectedDeviceId = 'camera-1';
      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.request),
      );

      expect(service.active, isTrue);
      expect(signals.single.kind, CameraSignalKind.offer);
      expect(signals.single.sdp, 'v=0\r\n');
      expect(
        calls
            .singleWhere((MethodCall call) => call.method == 'getUserMedia')
            .arguments,
        <String, Object>{
          'constraints': <String, Object>{
            'audio': false,
            'video': <String, Object>{
              'width': 1280,
              'height': 720,
              'frameRate': 30,
              'deviceId': 'camera-1',
            },
          },
        },
      );
      expect(
        calls
            .singleWhere((MethodCall call) => call.method == 'addTrack')
            .arguments,
        <String, Object>{
          'peerConnectionId': 'peer-1',
          'trackId': 'video-1',
          'streamIds': <String>['stream-1'],
        },
      );

      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.answer, sdp: 'v=0\r\n'),
      );
      await service.dispose();
      await service.dispose();

      expect(service.active, isFalse);
      expect(
        calls.map((MethodCall call) => call.method),
        containsAllInOrder(<String>[
          'setRemoteDescription',
          'peerConnectionClose',
          'streamDispose',
        ]),
      );
      expect(
        calls.where((MethodCall call) => call.method == 'streamDispose'),
        hasLength(1),
      );
    },
  );

  group('lifecycle without a camera stream', () {
    test('dispose without start does not throw', () async {
      await _service().dispose();
    });

    test('stop without start does not throw', () async {
      await _service().stop();
    });

    test('dispose is idempotent', () async {
      final WebrtcCameraService service = _service();

      await service.dispose();
      await service.dispose();
    });

    test('stop after dispose does not throw', () async {
      final WebrtcCameraService service = _service();
      await service.dispose();

      await service.stop();
    });
  });

  group('a signal that arrives after teardown', () {
    // The camera is stopped between an offer going out and the reply coming
    // back — an ordinary race on a machine the operator is closing. Applying an
    // answer with no peer left to apply it to used to be a null-check crash out
    // of a platform callback.
    test('an answer with no peer is dropped, not thrown', () async {
      final WebrtcCameraService service = _service();

      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.answer, sdp: 'v=0\r\n'),
      );
    });

    test('an ice candidate with no peer is buffered, not thrown', () async {
      final WebrtcCameraService service = _service();

      await service.handleSignal(
        const CameraSignal(
          kind: CameraSignalKind.ice,
          candidate: 'candidate:1 1 udp 1 10.0.0.1 1 typ host',
        ),
      );
    });

    test('a signal after dispose is ignored', () async {
      final WebrtcCameraService service = _service();
      await service.dispose();

      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.answer, sdp: 'v=0\r\n'),
      );
    });
  });

  group('availability', () {
    test('tvOS reports the camera as unavailable', () {
      SystemPlatform.debugSetTvOsOverride(true);

      expect(_service().available, isFalse);
    });

    test('an ordinary desktop platform reports it as available', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(_service().available, isTrue);
    });

    test('start on an unavailable platform is a no-op', () async {
      SystemPlatform.debugSetTvOsOverride(true);
      final WebrtcCameraService service = _service();

      await service.start();

      expect(service.active, isFalse);
    });
  });
}
