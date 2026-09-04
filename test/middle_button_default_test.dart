@TestOn('browser')
library;

import 'package:application_base/presentation/utility/middle_button_default_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart';

/// The hold on the browser's middle-button defaults must outlive the press
/// that ends the autoscroll mode: the mode ends inside the `pointerdown`,
/// and the `mousedown` and `auxclick` whose defaults open the link come after
/// it. The sequences below replay the browser's event order with the middle
/// button (`button == 1`) and read `defaultPrevented` off each event.
void main() {
  /// Fires one middle-button event through the window's capture listeners.
  bool fire(String type) {
    final MouseEvent event = MouseEvent(
      type,
      MouseEventInit(button: 1, bubbles: true, cancelable: true),
    );
    document.body!.dispatchEvent(event);

    return event.defaultPrevented;
  }

  /// The press that starts the mode, released without a drag: the mode is on
  /// and the press is over.
  void startMode() {
    holdMiddleButtonDefault(isHeld: true);
    fire('auxclick');
  }

  test('the click that ends the mode is held to its end', () {
    startMode();

    /// The exit click: the application stops the mode inside the pointerdown,
    /// before the browser fires the rest of the press.
    fire('pointerdown');
    holdMiddleButtonDefault(isHeld: false);

    expect(fire('mousedown'), isTrue, reason: 'browser autoscroll');
    expect(fire('auxclick'), isTrue, reason: 'link in a new tab');
  });

  test('a press outside the mode belongs to the browser', () {
    startMode();
    fire('pointerdown');
    holdMiddleButtonDefault(isHeld: false);
    fire('auxclick');

    fire('pointerdown');
    expect(fire('mousedown'), isFalse);
    expect(fire('auxclick'), isFalse);
  });

  test('the mode ended without a press lets go at once', () {
    startMode();
    holdMiddleButtonDefault(isHeld: false);

    fire('pointerdown');
    expect(fire('mousedown'), isFalse);
    expect(fire('auxclick'), isFalse);
  });

  test('a release the window never saw is repaired by the next press', () {
    holdMiddleButtonDefault(isHeld: true);
    holdMiddleButtonDefault(isHeld: false);

    fire('pointerdown');
    expect(fire('mousedown'), isFalse);
    expect(fire('auxclick'), isFalse);
  });

  test('the press that starts the mode is under the hold as well', () {
    holdMiddleButtonDefault(isHeld: true);

    expect(fire('mousedown'), isTrue);
    expect(fire('auxclick'), isTrue);

    holdMiddleButtonDefault(isHeld: false);
  });
}
