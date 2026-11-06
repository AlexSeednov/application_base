@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:application_base/core/utility/browser_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// Replaces DOM callbacks left by an earlier Dart runtime without invoking
/// them, while preserving multiple watchers registered by the current run.
void main() {
  test('a new runtime replaces old marker callbacks', () {
    int staleCalls = 0;
    int firstCalls = 0;
    int secondCalls = 0;
    int otherCalls = 0;
    final staleStorage = ((web.Event _) => staleCalls++).toJS;
    final staleVisibility = ((web.Event _) => staleCalls++).toJS;
    web.window.addEventListener('storage', staleStorage);
    web.document.addEventListener('visibilitychange', staleVisibility);
    final oldEntry = JSObject()
      ..setProperty('storage'.toJS, staleStorage)
      ..setProperty('visibility'.toJS, staleVisibility);
    web.window.setProperty(
      '__applicationBaseTabMarkerListeners'.toJS,
      [oldEntry].toJS,
    );

    BrowserTab.watchMarker('test.session', () => firstCalls++);
    BrowserTab.watchMarker('test.session', () => secondCalls++);
    BrowserTab.watchMarker('test.other', () => otherCalls++);

    web.window.dispatchEvent(
      web.StorageEvent('storage', web.StorageEventInit(key: 'test.session')),
    );
    expect(staleCalls, 0);
    expect(firstCalls, 1);
    expect(secondCalls, 1);
    expect(otherCalls, 0);

    /// Clearing site storage announces a null key to all watchers.
    web.window.dispatchEvent(web.StorageEvent('storage'));
    expect(firstCalls, 2);
    expect(secondCalls, 2);
    expect(otherCalls, 1);

    web.document.dispatchEvent(web.Event('visibilitychange'));
    expect(staleCalls, 0);
    final visibleIncrement = web.document.visibilityState == 'visible' ? 1 : 0;
    expect(firstCalls, 2 + visibleIncrement);
    expect(secondCalls, 2 + visibleIncrement);
    expect(otherCalls, 1 + visibleIncrement);
  });
}
