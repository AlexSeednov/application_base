import 'package:web/web.dart' as web;

/// Whether the browser has left the focus of the page on its body — the state
/// a removed focused element leaves behind.
///
/// The document itself still holds the focus: the page was not left for the
/// address bar, another tab or another window. Nothing inside it holds the
/// focus either, so the Flutter view is not focused and no key reaches the
/// application until something is focused again. The same pair of checks the
/// engine reads a `focusout` by.
bool isPageFocusStranded() {
  final web.Element? active = web.document.activeElement;

  return web.document.hasFocus() &&
      (active == null || active == web.document.body);
}
