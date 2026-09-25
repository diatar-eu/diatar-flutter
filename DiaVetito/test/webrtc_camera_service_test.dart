// Regression tests for the camera service's lifecycle.
//
// `RTCVideoRenderer.srcObject` throws a bare string when the renderer was never
// initialised or is already disposed, and says so only by throwing. The service
// used to assign to it unconditionally, so tearing down a camera whose texture
// never came up — which is what happens on every platform that cannot create
// one, and on every run of a widget test — took the whole app down on the
// dispose path. These pin the guard that replaced that.

import 'package:diavetito/src/services/webrtc_camera_service.dart';
import 'package:diavetito/src/utils/system_platform.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

WebrtcCameraService _service() =>
    WebrtcCameraService(sendSignal: (CameraSignal _) async {});

void main() {
  // `flutter_webrtc` reaches a platform channel even to fail, so the binding
  // has to exist before any of this runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SystemPlatform.debugSetTvOsOverride(null);
  });

  group('teardown without a live renderer', () {
    // A platform texture cannot be created in a test host, so `initialize()`
    // cannot succeed here. That is precisely the state the old code reached
    // `srcObject` in and threw from.
    test('dispose after a failed init does not throw', () async {
      final WebrtcCameraService service = _service();

      await service.init();
      await service.dispose();
    });

    test('dispose without init does not throw', () async {
      await _service().dispose();
    });

    test('stop without init does not throw', () async {
      await _service().stop();
    });

    test('dispose is idempotent', () async {
      final WebrtcCameraService service = _service();
      await service.init();

      await service.dispose();
      // A second teardown has to be a no-op: the renderer is already gone, and
      // assigning to it again would throw.
      await service.dispose();
    });

    test('dispose while init is still in flight does not throw', () async {
      final WebrtcCameraService service = _service();

      // Deliberately not awaited first. The init is still outstanding when the
      // teardown starts, which is what closing the window during startup is.
      final Future<void> init = service.init();
      await service.dispose();
      await init;
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
        const CameraSignal(
          kind: CameraSignalKind.answer,
          sdp: 'v=0\r\n',
        ),
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
        const CameraSignal(
          kind: CameraSignalKind.answer,
          sdp: 'v=0\r\n',
        ),
      );
    });
  });

  group('availability', () {    test('tvOS reports the camera as unavailable', () {
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
