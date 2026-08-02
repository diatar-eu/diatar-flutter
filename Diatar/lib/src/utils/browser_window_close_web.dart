import 'dart:html' as html;

Future<bool> tryCloseBrowserWindowImpl() async {
  try {
    html.window.close();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (html.window.closed == true) {
      return true;
    }

    // Some browsers allow closing only script-opened windows.
    html.window.open('', '_self');
    html.window.close();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (html.window.closed == true) {
      return true;
    }

    final Uri launcherUri = Uri.base.resolve('../');
    html.window.location.assign(launcherUri.toString());
    return false;
  } catch (_) {
    final Uri launcherUri = Uri.base.resolve('../');
    html.window.location.assign(launcherUri.toString());
    return false;
  }
}
