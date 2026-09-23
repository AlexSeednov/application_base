import 'package:web/web.dart' as web;

/// Whether the browser has left the page focus on the body — the state a
/// removed focused element leaves behind.
///
/// The document still holds the focus, so the user has not gone to the
/// address bar, another tab or another window. No element inside it holds
/// the focus either, so the Flutter view is unfocused and no key reaches the
/// application until something is focused again. The engine reads a
/// `focusout` by the same pair of checks.
bool isPageFocusStranded() {
  final web.Element? active = web.document.activeElement;

  return web.document.hasFocus() &&
      (active == null || active == web.document.body);
}
