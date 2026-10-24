// Regression tests for the camera view service's lifecycle.
//
// The camera overlay is a picture-in-picture on top of the projection, fed by
// a WebRTC stream the projector sends. The renderer it draws into is created on
// demand and lives across teardown, which makes the places that touch it —
// the peer callbacks, in particular — places where a null check that cannot be
// proven, or a texture that has not finished initialising, becomes a crash
// rather than a missing overlay.

import 'package:diatar_common/diatar_common.dart';
import 'package:diatar_app/src/services/webrtc_camera_view_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

WebrtcCameraViewService _service() =>
    WebrtcCameraViewService(sendSignal: (CameraSignal _, String? _) async {});

void main() {
  // `flutter_webrtc` reaches a platform channel even to fail, so the binding
  // has to exist before any of this runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('lifecycle', () {
    test('init twice does not throw', () async {
      final WebrtcCameraViewService service = _service();

      await service.init();
      // The second call used to dispose the live renderer and build another,
      // which would have pulled the picture out from under a mounted
      // `RTCVideoView`.
      await service.init();
    });

    test('dispose is idempotent', () async {
      final WebrtcCameraViewService service = _service();
      await service.init();

      await service.dispose();
      await service.dispose();
    });

    test('dispose without init does not throw', () async {
      await _service().dispose();
    });

    test('dispose racing an in-flight init does not throw', () async {
      final WebrtcCameraViewService service = _service();

      final Future<void> init = service.init();
      await service.dispose();
      await init;
    });

    test('stop after dispose does not throw', () async {
      final WebrtcCameraViewService service = _service();
      await service.dispose();

      await service.stop();
    });

    test('init after dispose does not throw', () async {
      final WebrtcCameraViewService service = _service();
      await service.dispose();

      await service.init();
    });

    test('the renderer getter keeps returning one renderer', () {
      final WebrtcCameraViewService service = _service();

      // Held so the overlay and the service agree on a single texture; a
      // second one would be created and never disposed.
      expect(identical(service.renderer, service.renderer), isTrue);
    });
  });

  group('signals with no connection to apply them to', () {
    // An `offer` that cannot reach a peer needs no case here: the transport
    // callback in `DiatarMainController` already swallows that failure, and
    // what these pin is the null-unwrap that used to sit in the signal cases
    // themselves.
    test('an answer for a connection that is gone is ignored', () async {
      final WebrtcCameraViewService service = _service();

      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.answer),
        'sender-a',
      );
    });

    test('an ice candidate with no peer is buffered, not thrown', () async {
      final WebrtcCameraViewService service = _service();

      await service.handleSignal(
        const CameraSignal(
          kind: CameraSignalKind.ice,
          candidate: 'candidate:1 1 udp 1 10.0.0.1 1 typ host',
        ),
        'sender-a',
      );
    });

    test('a signal after dispose is ignored', () async {
      final WebrtcCameraViewService service = _service();
      await service.dispose();

      await service.handleSignal(
        const CameraSignal(kind: CameraSignalKind.answer),
        'sender-a',
      );
    });
  });
}
