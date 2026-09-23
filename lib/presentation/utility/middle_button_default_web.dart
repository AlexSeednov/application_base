import 'dart:js_interop';

import 'package:web/web.dart';

/// Whether the autoscroll mode is on.
bool _isModeOn = false;

/// Whether a middle press that began under the mode is still in progress.
///
/// The press that ends the mode outlives it: the mode ends inside the
/// `pointerdown`, and only then does the browser fire `mousedown` and, on
/// release, `auxclick` — the events whose defaults start the browser's own
/// autoscroll and open the link. A hold that ended with the mode would miss
/// both, so it lasts until the press ends.
bool _isPressInProgress = false;

/// Whether the listeners are attached. They are attached once and never
/// removed: the flags decide what they do, so a mode that starts and ends
/// many times does not add and remove listeners around every session.
bool _isListening = false;

/// Web branch of the autoscroll's hold on the middle button: suppresses the
/// browser's own middle-button actions while the mode is on.
///
/// While the mode is on, a click should only end it, but the browser knows
/// nothing of the mode: over a link (an `<a>` element the app renders over
/// the widget) the middle button opens a new tab, and over the page it may
/// start the browser's own autoscroll.
///
/// Only the default action is prevented, not propagation, so the engine still
/// delivers the click to the application and the mode ends on it. The
/// listeners sit in the capture phase, ahead of anything the page itself does
/// with the event.
void holdMiddleButtonDefault({required bool isHeld}) {
  _isModeOn = isHeld;

  /// The press flag clears itself when the press ends.
  if (!isHeld) return;

  /// The mode starts inside a press, so that press is held as well.
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
/// assignment clears a flag left behind by a release the window never saw:
/// there are no middle-button events between two presses, so a stale flag is
/// harmless until then.
void _onPointerDown(MouseEvent event) {
  if (!_isMiddle(event)) return;

  _isPressInProgress = _isModeOn;
}

/// Prevents the default of the press: the browser's own autoscroll.
void _onMouseDown(MouseEvent event) {
  if (_isHeld && _isMiddle(event)) event.preventDefault();
}

/// Prevents the default of the click: opening a link in a new tab. It is the
/// last event of the press, so the press flag is cleared here.
void _onAuxClick(MouseEvent event) {
  if (!_isMiddle(event)) return;

  if (_isHeld) event.preventDefault();
  _isPressInProgress = false;
}
