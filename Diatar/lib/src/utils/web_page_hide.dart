import 'web_page_hide_stub.dart'
    if (dart.library.html) 'web_page_hide_web.dart';

void registerPageHideHandler(void Function() handler) =>
    registerPageHideHandlerImpl(handler);
