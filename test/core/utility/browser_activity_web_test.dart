@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:application_base/core/utility/browser_activity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// A hot restart replaces the old callback when a new subscriber arrives.
void main() {
  test('the first subscription replaces the previous DOM listener', () async {
    int staleCalls = 0;
    int currentCalls = 0;
    final staleListener = ((web.Event _) => staleCalls++).toJS;
    web.window.addEventListener('focus', staleListener);
    web.window.addEventListener('blur', staleListener);
    web.document.addEventListener('visibilitychange', staleListener);
    web.window.setProperty(
      '__applicationBaseBrowserActivityListener'.toJS,
      staleListener,
    );

    final subscription = BrowserActivity.changes.listen((_) => currentCalls++);
    web.window.dispatchEvent(web.Event('focus'));
    web.window.dispatchEvent(web.Event('blur'));
    web.document.dispatchEvent(web.Event('visibilitychange'));
    await Future<void>.delayed(Duration.zero);
    expect(staleCalls, 0);
    expect(currentCalls, 3);

    await subscription.cancel();
    web.window.dispatchEvent(web.Event('focus'));
    await Future<void>.delayed(Duration.zero);
    expect(currentCalls, 3);

    /// Повторный вход в экран снова подключает обработчик и не теряет события.
    final next = BrowserActivity.changes.listen((_) => currentCalls++);
    web.window.dispatchEvent(web.Event('focus'));
    await Future<void>.delayed(Duration.zero);
    expect(currentCalls, 4);
    await next.cancel();
  });
}
