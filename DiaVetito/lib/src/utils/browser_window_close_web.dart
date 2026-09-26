import 'package:web/web.dart' as web;

Future<bool> tryCloseBrowserWindowImpl() async {
  try {
    web.window.close();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (web.window.closed) {
      return true;
    }

    // Some browsers allow closing only script-opened windows.
    web.window.open('', '_self');
    web.window.close();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (web.window.closed) {
      return true;
    }

    final Uri launcherUri = Uri.base.resolve('../');
    web.window.location.assign(launcherUri.toString());
    return false;
  } catch (_) {
    final Uri launcherUri = Uri.base.resolve('../');
    web.window.location.assign(launcherUri.toString());
    return false;
  }
}
