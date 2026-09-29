import 'dart:js_interop';

import 'package:application_base/core/service/logger_service.dart';
import 'package:web/web.dart' as web;

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
  web.window.addEventListener(
    'storage',
    ((web.StorageEvent event) {
      final String? changedKey = event.key;
      if (changedKey == null || changedKey == key) onChange();
    }).toJS,
  );

  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      if (web.document.visibilityState == 'visible') onChange();
    }).toJS,
  );
}
