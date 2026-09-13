import 'package:web/web.dart' as web;

/// Whether the device the browser runs on accepts touch.
///
/// Needed where `defaultTargetPlatform` is too coarse: Safari on iPadOS
/// reports itself as macOS, and a tablet is told from a desktop Mac only by
/// the presence of touch input.
///
/// A signal, not a verdict. A Mac with a touch screen answers it the same way
/// an iPad does, so whatever a caller concludes from it has to degrade into
/// something harmless when the guess is wrong.
bool get isTouchInput => web.window.navigator.maxTouchPoints > 0;
