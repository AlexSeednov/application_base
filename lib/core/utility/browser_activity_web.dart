import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Retain the DOM handler across hot restarts so the next runtime can remove
/// it without invoking an obsolete Dart closure.
@JS('__applicationBaseBrowserActivityListener')
external JSFunction? get _storedListener;

///
@JS('__applicationBaseBrowserActivityListener')
external set _storedListener(JSFunction? value);

/// Visibility and focus of the page in which the application is running.
abstract final class BrowserActivity {
  /// Whether the browser considers the document visible.
  static bool get isVisible => web.document.visibilityState == 'visible';

  /// Whether the document is both visible and focused.
  static bool get hasFocus => isVisible && web.document.hasFocus();

  /// Signals that visibility or focus may have changed. Read the corresponding
  /// getter on each event. A visible page can still be waiting for focus.
  static Stream<void> get changes => _controller.stream;

  /// Attach DOM listeners only while the stream has subscribers.
  static final _controller = StreamController<void>.broadcast(
    onListen: _attach,
    onCancel: _detach,
  );

  ///
  static final JSFunction _listener = ((web.Event _) {
    _controller.add(null);
  }).toJS;

  ///
  static void _attach() {
    final previous = _storedListener;
    if (previous != null) _remove(previous);
    _storedListener = _listener;
    web.window.addEventListener('focus', _listener);
    web.window.addEventListener('blur', _listener);
    web.document.addEventListener('visibilitychange', _listener);
  }

  ///
  static void _detach() {
    _remove(_listener);
    if (_storedListener == _listener) _storedListener = null;
  }

  ///
  static void _remove(JSFunction listener) {
    web.window.removeEventListener('focus', listener);
    web.window.removeEventListener('blur', listener);
    web.document.removeEventListener('visibilitychange', listener);
  }
}
