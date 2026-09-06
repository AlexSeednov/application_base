import 'package:flutter/widgets.dart';

/// Puts the keyboard focus on the topmost route of [navigator].
///
/// The scopes of the routes are the direct children of the navigator's own
/// focus node, in stack order, so the last of them is the top route. The scope
/// itself takes the focus, not its last focused descendant: a text field would
/// otherwise get the focus back on every return to the page. Without a route
/// scope to take it — a navigator that has nothing on its stack — the scope
/// enclosing the navigator does.
///
/// For a navigator inside the tabs of an `IndexedStack`: Flutter excludes a
/// hidden tab from the focus, and the focus lands on the scope above the
/// tabs, where there is nothing to scroll. Call this after the frame in which
/// the tab becomes active — until the stack rebuilds the tab is still
/// excluded and the request is silently dropped.
void focusTopRoute(NavigatorState navigator) {
  final FocusNode node = navigator.focusNode;
  FocusScopeNode? scope;
  for (final FocusNode child in node.children) {
    if (child is FocusScopeNode) scope = child;
  }

  (scope ?? node.enclosingScope)?.requestScopeFocus();
}
