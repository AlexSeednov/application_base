import 'package:flutter/widgets.dart';

/// Puts the keyboard focus on the topmost route of [navigator].
///
/// Route scopes are the direct children of the navigator's own focus node,
/// in stack order, so the last one is the top route. The scope itself takes
/// the focus, not its last focused descendant: otherwise a text field would
/// get the focus back on every return to the page. With nothing on the
/// navigator's stack, the scope enclosing the navigator takes it.
///
/// For a navigator inside an `IndexedStack` tab: Flutter excludes a hidden
/// tab from the focus, so the focus lands on the scope above the tabs, where
/// there is nothing to scroll. Call this after the frame in which the tab
/// becomes active: until the stack rebuilds, the tab is still excluded and
/// the request is silently dropped.
void focusTopRoute(NavigatorState navigator) {
  final FocusNode node = navigator.focusNode;
  FocusScopeNode? scope;
  for (final FocusNode child in node.children) {
    if (child is FocusScopeNode) scope = child;
  }

  (scope ?? node.enclosingScope)?.requestScopeFocus();
}
