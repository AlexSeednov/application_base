import 'package:application_base/core/utility/browser_tab.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outside the web there is no tab: nothing to reload, no marker to share.
/// The browser branch is covered by `browser_tab_bridge_web_test.dart`.
void main() {
  test('is not available', () {
    expect(BrowserTab.isAvailable, isFalse);
  });

  test('a written marker is never read back', () {
    BrowserTab.writeMarker('test.marker', 'value');

    expect(BrowserTab.readMarker('test.marker'), isNull);
  });

  test('watching and reloading do nothing', () {
    int changeCount = 0;
    BrowserTab.watchMarker('test.marker', () => changeCount++);
    BrowserTab.writeMarker('test.marker', 'value');
    BrowserTab.reload();

    expect(changeCount, 0);
  });
}
