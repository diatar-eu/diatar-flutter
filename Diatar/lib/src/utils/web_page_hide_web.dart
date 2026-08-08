import 'dart:html' as html;

void registerPageHideHandlerImpl(void Function() handler) {
  html.window.onPageHide.listen((_) {
    handler();
  });
}
