import 'dart:js_interop';

import 'package:web/web.dart';

/// Whether the mode is on.
bool _isModeOn = false;

/// Whether a middle press that began under the mode is still on its way.
///
/// The press that ends the mode outlives it: the engine hands the
/// application the `pointerdown`, the mode ends inside it — and only then
/// the browser fires the `mousedown` and, on the release, the `auxclick`,
/// the two whose defaults start its own autoscroll and open the link. A hold
/// that ended with the mode was let go before either of them, so the hold
/// follows the press to its end instead.
bool _isPressInProgress = false;

/// Whether the listeners are in place. They are attached once and left there:
/// the flags decide what they do, so a mode that starts and ends many times
/// does not add and remove listeners around every session.
bool _isListening = false;

/// Web branch of the autoscroll's hold on the middle button.
///
/// While the mode is on, a click ends it and does nothing else — but the
/// browser knows nothing of the mode. Over a link (an `<a>` element the app
/// renders over the widget) the middle button opens a new tab, and over the
/// page it may start the browser's own autoscroll, so the click meant to
/// leave the mode does two things at once.
///
/// Only the default action is prevented; propagation is left alone, so the
/// engine still delivers the click to the application and the mode ends on
/// it. The listeners sit in the capture phase, ahead of anything the page
/// itself does with the event.
void holdMiddleButtonDefault({required bool isHeld}) {
  _isModeOn = isHeld;

  /// The press flag lets go of itself with the press.
  if (!isHeld) return;

  /// The mode starts inside a press: that press is under the hold as well.
  _isPressInProgress = true;
  if (_isListening) return;

  _isListening = true;
  window
    ..addEventListener('pointerdown', _onPointerDown.toJS, true.toJS)
    ..addEventListener('mousedown', _onMouseDown.toJS, true.toJS)
    ..addEventListener('auxclick', _onAuxClick.toJS, true.toJS);
}

///
bool get _isHeld => _isModeOn || _isPressInProgress;

/// The middle button is button 1; every other one belongs to the page.
bool _isMiddle(MouseEvent event) => event.button == 1;

/// A press that begins under the mode is held to its end whatever the mode
/// does meanwhile; one that begins outside it is the browser's. The same
/// assignment replaces a flag left behind by a release the window never
/// saw — there are no middle-button events between two presses, so a stale
/// flag is harmless until then.
void _onPointerDown(MouseEvent event) {
  if (!_isMiddle(event)) return;

  _isPressInProgress = _isModeOn;
}

/// The default of the press: the browser's own autoscroll.
void _onMouseDown(MouseEvent event) {
  if (_isHeld && _isMiddle(event)) event.preventDefault();
}

/// The default of the click: a link opens in a new tab. It is the last event
/// of the press, so the press flag is let go here.
void _onAuxClick(MouseEvent event) {
  if (!_isMiddle(event)) return;

  if (_isHeld) event.preventDefault();
  _isPressInProgress = false;
}
