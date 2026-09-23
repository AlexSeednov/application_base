import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:application_base/presentation/utility/page_focus_state.dart'
    if (dart.library.js_interop)
        'package:application_base/presentation/utility/page_focus_state_web.dart';
import 'package:flutter/widgets.dart';

/// Keeps the keyboard inside the application when the browser strands the
/// page focus on the document body.
///
/// An application link is a real `<a>` element laid over the widget
/// (`RouteLink`), and clicking it leaves the browser focus on that element.
/// When the element goes — the click navigated away from its page, or a lazy
/// list recycled it — the browser drops the focus onto the body, outside the
/// Flutter view. Flutter reads that as the view losing the focus and parks
/// its own focus on the root scope, where no widget takes a key: scrolling,
/// Escape and every other shortcut go dead until the next click.
///
/// The document still holds the browser focus, which tells this case apart
/// from the user going to the address bar or another tab. So the focus is put
/// back the way that next click would: the root scope descends its chain of
/// last-focused children to the scope of the top route, and the framework
/// then asks the browser to focus the view as well.
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

  /// Whether the browser has left the page focus on the body. A parameter for
  /// the tests: the state comes from a real browser, while the reaction to it
  /// is pure framework and is tested without one.
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

    /// In a microtask: another framework observer does the parking, and the
    /// focus must be put back after it whatever the order of the observers.
    scheduleMicrotask(_restore);
  }

  /// The parking leaves the chain of last-focused children intact, so walking
  /// down it lands the focus where it was: on the scope of the top route, not
  /// on the first focusable widget of the page.
  void _restore() {
    if (!mounted) return;

    FocusManager.instance.rootScope.requestFocus();
  }

  ///
  @override
  Widget build(BuildContext context) => widget.child;
}
