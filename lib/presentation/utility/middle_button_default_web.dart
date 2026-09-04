import 'dart:js_interop';

import 'package:web/web.dart';

/// Whether the browser's own answer to the middle button is held off.
bool _isHeld = false;

/// Whether the listeners are in place. They are attached once and left there:
/// the flag decides what they do, so a mode that starts and ends many times
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
  _isHeld = isHeld;
  if (!isHeld || _isListening) return;

  _isListening = true;

  /// The press starts the browser's own autoscroll, the click opens a link:
  /// both have to be answered.
  window
    ..addEventListener('mousedown', _onMouseEvent.toJS, true.toJS)
    ..addEventListener('auxclick', _onMouseEvent.toJS, true.toJS);
}

/// The middle button is button 1; every other one belongs to the page.
void _onMouseEvent(MouseEvent event) {
  if (!_isHeld || event.button != 1) return;

  event.preventDefault();
}
