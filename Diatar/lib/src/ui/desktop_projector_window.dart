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
  const DesktopProjectorWindow({super.key, required this.monitor});

  /// A kiválasztott monitor indexe. -1 esetén az utolsó (jobb szélső) kijelző.
  final int monitor;

  @override
  State<DesktopProjectorWindow> createState() => _DesktopProjectorWindowState();
}

class _DesktopProjectorWindowState extends State<DesktopProjectorWindow>
    with WindowListener {
  static const String _channelName = 'diatar/desktop_projector';
  static const String _controlChannelName = 'diatar/desktop_projector_control';

  final WindowMethodChannel _channel = const WindowMethodChannel(
    _channelName,
    mode: ChannelMode.unidirectional,
  );
  final WindowMethodChannel _controlChannel = const WindowMethodChannel(
    _controlChannelName,
    mode: ChannelMode.bidirectional,
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
    final int requestedMonitor = (args['monitor'] as int?) ?? widget.monitor;
    final int mainMonitor = (args['mainMonitor'] as int?) ?? -1;
    _controller.applyMonitor(requestedMonitor);
    await _channel.setMethodCallHandler(_controller.handleMethodCall);
    // A vezérlő ablakkal való kommunikációhoz (vetítésbe kattintás ->
    // vezérlő visszahozása) egy bidirekcionális csatornán párba állunk a
    // főablakkal.
    await _controlChannel.setMethodCallHandler((MethodCall call) async {
      return null;
    });
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
        await windowManager.setPreventClose(true);
        final int targetIndex =
            await _positionOnSelectedDisplay(requestedMonitor);
        final bool sameMonitor =
            mainMonitor >= 0 && mainMonitor == targetIndex;
        // Ha a vetítő ablak a vezérlő ablakkal azonos monitoron van, akkor
        // ne legyen mindig felül, hogy a vezérlő ablak kerülhessen a tetejére.
        await windowManager.setAlwaysOnTop(!sameMonitor);
        await windowManager.setFullScreen(true);
        await windowManager.show(inactive: true);
        if (!sameMonitor) {
          await windowManager.focus();
        }
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

  /// A kért monitorra pozícionálja az ablakot.
  /// [monitor] >= 0 esetén az adott indexű kijelző, egyébként az utolsó
  /// (jobb szélső) kijelző. Visszaadja a ténylegesen kiválasztott indexet.
  Future<int> _positionOnSelectedDisplay(int monitor) async {
    final List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return 0;
    }
    final List<Display> sorted = List<Display>.from(displays)
      ..sort((Display a, Display b) {
        final double ax = a.visiblePosition?.dx ?? 0;
        final double bx = b.visiblePosition?.dx ?? 0;
        return ax.compareTo(bx);
      });
    final int index =
        (monitor >= 0 && monitor < sorted.length) ? monitor : sorted.length - 1;
    final Display selected = sorted[index];
    final ui.Offset position = selected.visiblePosition ?? ui.Offset.zero;
    final ui.Size size = selected.visibleSize ?? selected.size;
    await windowManager.setBounds(
      ui.Rect.fromLTWH(position.dx, position.dy, size.width, size.height),
    );
    return index;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(_channel.setMethodCallHandler(null));
    unawaited(_controlChannel.setMethodCallHandler(null));
    _controller.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// A vetítésbe való kattintáskor visszahozzuk a vezérlő (fő) ablakot.
  Future<void> _onProjectionTap() async {
    try {
      await _controlChannel.invokeMethod('showControl');
    } catch (_) {
      // nem kritikus
    }
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
            body: MouseRegion(
              cursor: SystemMouseCursors.none,
              child: GestureDetector(
                onTap: _onProjectionTap,
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
  int monitor = -1;
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
      case 'close':
        await windowManager.setPreventClose(false);
        await windowManager.close();
        return null;
      default:
        throw MissingPluginException('Unknown projector method: ${call.method}');
    }
  }

  void applyMonitor(int value) {
    monitor = value;
  }

  void _applySettings(AppSettings newSettings) {
    if (_disposed) {
      return;
    }
    settings = newSettings;
    monitor = newSettings.desktopProjectorMonitor;
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