import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:application_base/presentation/utility/page_focus_state.dart'
    if (dart.library.js_interop)
        'package:application_base/presentation/utility/page_focus_state_web.dart';
import 'package:flutter/widgets.dart';

/// Keeps the keyboard inside the application when the browser strands the
/// focus of the page on its body.
///
/// A link of the application is a real `<a>` element laid over the widget
/// (`RouteLink`), and clicking one leaves the browser focus on that element.
/// When it then goes — the card was on the page the click navigated away
/// from, or a lazy list recycled it — the browser drops the focus onto the
/// body of the document, outside the Flutter view. Flutter reads that as the
/// view losing the focus and parks its own focus on the root scope, where no
/// widget can take a key: page scrolling, Escape and every other shortcut go
/// dead until the next click anywhere in the window.
///
/// Nothing has left the page, though — the document still holds the browser
/// focus, and that is what tells this case from the user going to the address
/// bar or to another tab. So the focus is put back the way that next click
/// would have put it back: the root scope descends the chain of its
/// last-focused children, which ends on the scope of the topmost route. The
/// framework then asks the browser for the focus of the view in turn, and the
/// pair is in step again.
///
/// Outside the web nothing is ever stranded and the widget is inert.
final class PageFocusKeeper extends StatefulWidget {
  ///
  const PageFocusKeeper({
    required this.child,
    this.isStranded = isPageFocusStranded,
    super.key,
  });

  /// The application whose focus is kept.
  final Widget child;

  /// Whether the browser has left the focus on the body of the page. Behind a
  /// parameter for the tests: the state belongs to a real browser, while what
  /// is done about it is the framework's own and is checked without one.
  @visibleForTesting
  final ValueGetter<bool> isStranded;

  ///
  @override
  State<PageFocusKeeper> createState() => _PageFocusKeeperState();
}

///
final class _PageFocusKeeperState extends State<PageFocusKeeper>
    with WidgetsBindingObserver {
  ///
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  ///
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  ///
  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state != ViewFocusState.unfocused) return;
    if (event.viewId != View.of(context).viewId) return;
    if (!widget.isStranded()) return;

    /// In a microtask: the parking is done by an observer of the framework,
    /// and the focus is put back on top of it whatever the order of the
    /// observers turns out to be.
    scheduleMicrotask(_restore);
  }

  /// The chain of last-focused children is left untouched by the parking, so
  /// walking down it lands the focus where it was — on the scope of the top
  /// route, and not on the first focusable widget of the page.
  void _restore() {
    if (!mounted) return;

    FocusManager.instance.rootScope.requestFocus();
  }

  ///
  @override
  Widget build(BuildContext context) => widget.child;
}
