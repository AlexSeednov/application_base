import 'package:application_base/core/service/logger_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Key for navigation without requiring context
final _navigatorKey = GlobalKey<NavigatorState>();

/// Key for navigation without requiring context
GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

/// Actual application router
StackRouter? get actualRouter => actualContext?.router;

///
String? get currentRouteName => actualRouter?.current.name;

/// Current context getter
///
/// **Important:** do not use for theming
/// because of it wouldn't be changed on theme changing
BuildContext? get actualContext {
  if (_navigatorKey.currentContext == null) {
    logError(error: 'Requested actual context is NULL');
  }
  return _navigatorKey.currentContext;
}

/// Drops the focus from the focused node by moving the primary focus to its
/// scope.
///
/// Does nothing when the primary focus already sits on a scope — a route with
/// no focused field. Unfocusing a scope moves the focus one scope up, and on
/// the web that is what killed keyboard scrolling after any tap on the page
/// background: Flutter's scroll action looks the scrollable up from the
/// focused node, and above the route there is nothing to scroll.
void unfocus() {
  final FocusNode? node = FocusManager.instance.primaryFocus;
  if (node == null || node is FocusScopeNode) return;

  node.unfocus();
}

/// Runs [action] against the live router, or reports and does nothing.
///
/// Every helper below used to force-unwrap [actualRouter], which turned the
/// "no mounted router" case into a crash right after [actualContext] had
/// already logged it. Navigation is a side effect: when there is nowhere to
/// navigate, skipping it and leaving a trace beats taking the app down.
T? _withRouter<T>(String action, T Function(StackRouter router) navigate) {
  final StackRouter? router = actualRouter;
  if (router == null) {
    logError(error: 'Navigation skipped, router is not available: $action');
    return null;
  }
  return navigate(router);
}

/// Same as [_withRouter], for helpers that must return a future.
Future<void> _withRouterAsync(
  String action,
  Future<void> Function(StackRouter router) navigate,
) => _withRouter(action, navigate) ?? Future<void>.value();

/// Adds a new entry to the screens stack.
///
/// Better to use for in-sector navigation.
/// Use [navigateScreen] for cross-sector navigation.
// Information(Alex): Can not return some value because of Future<smth>
// doesn't work with await...
Future<void> pushScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('push', (router) => router.push(route));

/// Adds a new entry to the screens stack by using [routeName].
///
/// Better to use for in-sector navigation.
/// Use [navigatePath] for cross-sector navigation.
Future<void> pushNamed({required String routeName}) =>
    _withRouterAsync('pushNamed', (router) => router.pushPath(routeName));

/// Pops the last screen unless stack has one entry
// Optimize(Alex): пометить как awaitNotRequired с выходом meta 1.17
Future<void> popScreen({bool? result}) =>
    _withRouterAsync('pop', (router) => router.maybePop(result));

/// Calls pop on the controller with the top-most visible page
void popTopScreen({bool? result}) =>
    _withRouter('popTop', (router) => router.maybePopTop(result));

/// Pop current route regardless if it's the last route in stack
/// or the result of it's
void popScreenForced({bool? result}) =>
    _withRouter('popForced', (router) => router.pop(result));

/// Keeps popping routes until route with provided [routeName] is found
void popUntilScreenWithName({required String routeName}) => _withRouter(
  'popUntilRouteWithName',
  (router) => router.popUntilRouteWithName(routeName),
);

/// Pops until provided [route], if it already exists in stack
/// else adds it to the stack (good for web Apps).
///
/// Better to use for cross-sector navigation.
/// Use [pushScreen] for in-sector navigation.
Future<void> navigateScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('navigate', (router) => router.navigate(route));

/// Pops until given [path], if it already exists in stack
/// otherwise adds it to the stack.
///
/// Wrong path will be redirected if redirection rull is set in router or
/// exception "Can not navigate to $path" will be thrown
///
/// Better to use for cross-sector navigation.
/// Use [pushNamed] for in-sector navigation.
Future<void> navigatePath({required String path}) =>
    _withRouterAsync('navigatePath', (router) => router.navigatePath(path));

/// Removes last entry in stack and pushes provided [route].
/// if last entry == provided route screen will just be updated
Future<void> replaceScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('replace', (router) => router.replace(route));

/// This's like providing a completely new stack as it rebuilds the stack
/// with the passed [route].
/// Entry might just update if already exist
Future<void> replaceAllScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('replaceAll', (router) => router.replaceAll([route]));
