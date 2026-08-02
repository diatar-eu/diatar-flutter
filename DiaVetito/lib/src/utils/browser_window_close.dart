import 'browser_window_close_stub.dart'
    if (dart.library.html) 'browser_window_close_web.dart';

Future<bool> tryCloseBrowserWindow() => tryCloseBrowserWindowImpl();
