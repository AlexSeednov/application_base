import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:application_base/core/service/logger_service.dart';
import 'package:web/web.dart' as web;

/// DOM listeners outlive a Dart hot restart. Keep their JavaScript handles
/// outside the Dart runtime so the next launch can remove them without
/// calling a closure belonging to the previous runtime.
@JS('__applicationBaseTabMarkerListeners')
external JSArray<JSObject>? get _storedListeners;

///
@JS('__applicationBaseTabMarkerListeners')
external set _storedListeners(JSArray<JSObject>? value);

/// Initialized once per Dart runtime, before its first subscription.
final JSArray<JSObject> _listeners = _startRuntime();

///
JSArray<JSObject> _startRuntime() {
  final previous = _storedListeners;
  if (previous != null) {
    for (final entry in previous.toDart) {
      web.window.removeEventListener(
        'storage',
        entry.getProperty<JSFunction>('storage'.toJS),
      );
      web.document.removeEventListener(
        'visibilitychange',
        entry.getProperty<JSFunction>('visibility'.toJS),
      );
    }
  }
  return _storedListeners = <JSObject>[].toJS;
}

/// Web branch of `BrowserTab.reload`: a full reload, as with the browser
/// button.
void reloadTab() => web.window.location.reload();

/// Web branch of `BrowserTab.readMarker`.
///
/// Touching `localStorage` throws when the browser forbids the site to store
/// data: then there is no marker, and every tab lives on its own.
String? readTabMarker(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (exception) {
    logError(error: 'Browser tab marker "$key" read error: $exception');
    return null;
  }
}

/// Web branch of `BrowserTab.writeMarker`. See [readTabMarker] for the throw.
void writeTabMarker(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (exception) {
    logError(error: 'Browser tab marker "$key" write error: $exception');
  }
}

/// Web branch of `BrowserTab.watchMarker`.
///
/// The browser sends `storage` to the other tabs of the site only, never to
/// the one that wrote. A `null` key means the whole storage was cleared, and
/// the marker went with it.
void watchTabMarker(String key, void Function() onChange) {
  /// Resolve the runtime registry before attaching any new listener.
  final registry = _listeners;
  final storage = ((web.StorageEvent event) {
    final String? changedKey = event.key;
    if (changedKey == null || changedKey == key) onChange();
  }).toJS;
  final visibility = ((web.Event _) {
    if (web.document.visibilityState == 'visible') onChange();
  }).toJS;

  final entry = JSObject()
    ..setProperty('storage'.toJS, storage)
    ..setProperty('visibility'.toJS, visibility);
  registry.toDart.add(entry);
  web.window.addEventListener('storage', storage);
  web.document.addEventListener('visibilitychange', visibility);
}
