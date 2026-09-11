import 'dart:js_interop';

import 'package:web/web.dart' as web;

void registerPageHideHandlerImpl(void Function() handler) {
  web.window.addEventListener(
    'pagehide',
    ((web.Event _) {
      handler();
    }).toJS,
  );
}
