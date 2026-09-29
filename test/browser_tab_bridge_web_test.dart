@TestOn('browser')
library;

import 'package:application_base/core/utility/browser_tab_bridge_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

/// A second tab cannot be opened from a test, so its `storage` events are
/// dispatched by hand: the browser would deliver the same event to this tab
/// had another one written the marker.
void main() {
  const String key = 'test.browser_tab.marker';

  /// Fires a `storage` event as another tab's write would.
  void fireStorage(String? changedKey) => window.dispatchEvent(
    StorageEvent('storage', StorageEventInit(key: changedKey)),
  );

  setUp(() => window.localStorage.removeItem(key));

  test('a written marker is read back', () {
    writeTabMarker(key, 'value');

    expect(readTabMarker(key), 'value');
  });

  test('a missing marker reads as null', () {
    expect(readTabMarker(key), isNull);
  });

  test('another tab changing the marker or clearing the storage is heard', () {
    int changeCount = 0;
    watchTabMarker(key, () => changeCount++);

    fireStorage(key);
    fireStorage(null);
    fireStorage('test.browser_tab.other');

    expect(changeCount, 2);
  });
}
