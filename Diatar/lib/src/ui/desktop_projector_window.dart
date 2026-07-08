import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:diatar_common/diatar_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class DesktopProjectorWindow extends StatefulWidget {
  const DesktopProjectorWindow({super.key, required this.side});

  final int side;

  @override
  State<DesktopProjectorWindow> createState() => _DesktopProjectorWindowState();
}

class _DesktopProjectorWindowState extends State<DesktopProjectorWindow>
    with WindowListener {
  static const String _channelName = 'diatar/desktop_projector';

  final WindowMethodChannel _channel = const WindowMethodChannel(
    _channelName,
    mode: ChannelMode.unidirectional,
  );
  final DesktopProjectorController _controller = DesktopProjectorController();

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final WindowController windowController =
        await WindowController.fromCurrentEngine();
    final Map<String, dynamic> args = _decodeArguments(windowController.arguments);
    _controller.applySide(args['side'] as int? ?? widget.side);
    await _channel.setMethodCallHandler(_controller.handleMethodCall);
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Colors.black,
        alwaysOnTop: true,
        skipTaskbar: true,
        windowButtonVisibility: false,
      ),
      () async {
        await windowManager.setAsFrameless();
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setPreventClose(true);
        await _positionOnSelectedDisplay(_controller.side);
        await windowManager.setFullScreen(true);
        await windowManager.show(inactive: true);
        await windowManager.focus();
      },
    );
  }

  Map<String, dynamic> _decodeArguments(String raw) {
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final Object decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  Future<void> _positionOnSelectedDisplay(int side) async {
    final List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return;
    }
    final List<Display> sorted = List<Display>.from(displays)
      ..sort((Display a, Display b) {
        final double ax = a.visiblePosition?.dx ?? 0;
        final double bx = b.visiblePosition?.dx ?? 0;
        return ax.compareTo(bx);
      });
    final Display selected = side <= 0 ? sorted.first : sorted.last;
    final ui.Offset position = selected.visiblePosition ?? ui.Offset.zero;
    final ui.Size size = selected.visibleSize ?? selected.size;
    await windowManager.setBounds(
      ui.Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(_channel.setMethodCallHandler(null));
    _controller.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: IgnorePointer(
              child: CustomPaint(
                painter: ProjectorPainter(
                  frame: _controller.activeFrame,
                  globals: _controller.globals,
                  settings: _controller.settings,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DesktopProjectorController extends ChangeNotifier {
  ProjectionGlobals globals = const ProjectionGlobals().copyWith(projecting: true);
  AppSettings settings = const AppSettings();
  ProjectionFrame? diaFrame = const LogoFrame(0);
  ProjectionFrame? blankFrame;
  int side = 1;
  Timer? _logoTimer;
  bool _disposed = false;

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'settings':
        _applySettings(AppSettings.fromMap(Map<String, dynamic>.from(call.arguments as Map)));
        return null;
      case 'state':
        _onState(Uint8List.fromList(List<int>.from(call.arguments as List<int>)));
        return null;
      case 'text':
        _onText(Uint8List.fromList(List<int>.from(call.arguments as List<int>)));
        return null;
      case 'pic':
        await _onPic(Uint8List.fromList(List<int>.from(call.arguments as List<int>)));
        return null;
      case 'blank':
        await _onBlank(Uint8List.fromList(List<int>.from(call.arguments as List<int>)));
        return null;
      case 'idle':
        return null;
      default:
        throw MissingPluginException('Unknown projector method: ${call.method}');
    }
  }

  void applySide(int value) {
    side = value <= 0 ? 0 : 1;
  }

  void _applySettings(AppSettings newSettings) {
    if (_disposed) {
      return;
    }
    settings = newSettings;
    side = newSettings.desktopProjectorSide.clamp(0, 1);
    notifyListeners();
  }

  void _onState(Uint8List bytes) {
    if (_disposed) {
      return;
    }
    final RecStateRecord record = RecStateRecord.fromBytes(bytes);
    globals = globals.fromState(record);
    notifyListeners();
  }

  void _onText(Uint8List bytes) {
    if (_disposed) {
      return;
    }
    diaFrame = TextFrame(record: RecTextRecord.fromBytes(bytes));
    notifyListeners();
  }

  Future<void> _onPic(Uint8List bytes) async {
    if (_disposed) {
      return;
    }
    final RecImageRecord record = RecImageRecord.fromBytes(bytes);
    final ui.Image? image = await _decodeImage(record.imageBytes);
    if (image == null) {
      return;
    }
    diaFrame = ImageFrame(image: image, bgMode: 1);
    notifyListeners();
  }

  Future<void> _onBlank(Uint8List bytes) async {
    if (_disposed) {
      return;
    }
    final RecImageRecord record = RecImageRecord.fromBytes(bytes);
    final ui.Image? image = await _decodeImage(record.imageBytes);
    if (image == null) {
      return;
    }
    blankFrame = ImageFrame(image: image, bgMode: globals.bgMode);
    notifyListeners();
  }

  ProjectionFrame? get activeFrame {
    if (globals.projecting) {
      return diaFrame;
    }
    if (globals.isBlankPic && globals.showBlankPic && blankFrame != null) {
      return blankFrame;
    }
    return null;
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return null;
    }
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _logoTimer?.cancel();
    super.dispose();
  }
}
