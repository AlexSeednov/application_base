import 'package:application_base/core/service/logger_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

///
final _navigatorKey = GlobalKey<NavigatorState>();

/// Key of the root navigator, to hand to the root router: every helper in
/// this file navigates through it, with no context of its own.
GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

/// The root router; `null` while no navigator is mounted.
StackRouter? get actualRouter => actualContext?.router;

/// Name of the screen on view: the current route of the top-most router.
///
/// [actualRouter] is the root, and with the screens in a nested router — a
/// shell route that holds a stack of its own — the root's own current route
/// is the shell, whatever screen is showing inside it.
String? get currentRouteName => actualRouter?.topRoute.name;

/// Context of the root navigator; `null`, and logged, while none is mounted.
///
/// Not for theming: a theme looked up through it ties the navigator, not the
/// caller, to the theme, so the caller is not rebuilt when the theme changes.
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
/// the web that kills keyboard scrolling after any tap on the page background:
/// Flutter's scroll action looks the scrollable up from the focused node, and
/// above the route there is nothing to scroll.
void unfocus() {
  final FocusNode? node = FocusManager.instance.primaryFocus;
  if (node == null || node is FocusScopeNode) return;

  node.unfocus();
}

/// Runs [navigate] against the live router, or logs [action] and does
/// nothing.
///
/// Navigation is a side effect: with no router mounted, skipping it and
/// leaving a trace beats crashing on a null router.
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

/// Pushes [route] onto the stack, for navigation within a section; use
/// [navigateScreen] to go to another section.
// Information(Alex): returns no value, since a typed `Future<T>` result does
// not work with `await` here.
Future<void> pushScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('push', (router) => router.push(route));

/// Pushes the route at [path] onto the stack, for navigation within a
/// section; use [navigatePath] to go to another section.
Future<void> pushPath({required String path}) =>
    _withRouterAsync('pushPath', (router) => router.pushPath(path));

/// The former name of [pushPath]: it has always taken a path, never a route
/// name.
@Deprecated('Use pushPath(path:) — it takes a path, not a route name')
Future<void> pushNamed({required String routeName}) =>
    pushPath(path: routeName);

/// Pops the last screen of the visible stack unless it is the only entry.
///
/// Through the top-most router, the way the system back button goes
/// (`AutoRouterDelegate.popRoute`): [actualRouter] is the root, and with the
/// screens in a nested router — a shell route that holds a stack of its own —
/// the root navigator holds that one shell page, so a pop aimed at the root
/// has nothing to pop and silently does nothing.
///
/// Awaiting is optional: the future only tells when the pop is done, and a
/// caller that just leaves the screen has nothing to wait for.
@awaitNotRequired
Future<void> popScreen({bool? result}) =>
    _withRouterAsync('pop', (router) => router.maybePopTop(result));

/// The same pop as [popScreen], without the future; kept so existing
/// callers compile.
void popTopScreen({bool? result}) =>
    _withRouter('popTop', (router) => router.maybePopTop(result));

/// Pops the current screen of the visible stack regardless of whether it is
/// the last one there or of what its `PopScope`s say.
///
/// Through the top-most router for the same reason as [popScreen]: on the
/// root a forced pop takes the shell page of a nested router off instead and
/// leaves an empty window. A nested stack down to its last page is not popped
/// to nothing either — the pop moves up to the page that holds it, the way
/// `maybePop` bubbles; only the root pops its last page, which is what the
/// caller asked for.
void popScreenForced({bool? result}) => _withRouter(
  'popForced',
  (router) => _forcedPopTarget(router).pop(result),
);

/// The router the forced pop lands on: the top-most one, or the nearest
/// ancestor with something of its own to pop.
///
/// Tabs routers have nothing of their own and are climbed through, so a
/// forced pop on a tabs page removes the page — not the tab.
RoutingController _forcedPopTarget(StackRouter root) {
  RoutingController target = root.topMostRouter();
  while (true) {
    final RoutingController? parent = target.parent<RoutingController>();
    if (parent == null) return target;
    if (target.canPop(ignoreParentRoutes: true, ignoreChildRoutes: true)) {
      return target;
    }
    target = parent;
  }
}

/// Keeps popping routes until the route named [routeName] is on top.
///
/// The name is looked for from the top-most router up to the root, and the
/// first stack that holds it pops to it — scoped, so no stack is ever emptied
/// on the way (auto_route's unscoped `popUntil` clears every stack the name
/// is not in). A name no stack holds pops nothing and is logged. Whatever an
/// ancestor shows over that stack — a sheet or a dialog on the root — goes as
/// well, since it sits above the target.
void popUntilScreenWithName({required String routeName}) =>
    _withRouter('popUntilRouteWithName', (router) {
      StackRouter? holder;
      RoutingController? candidate = router.topMostRouter(
        ignorePagelessRoutes: true,
      );
      while (candidate != null) {
        if (candidate is StackRouter &&
            candidate.stackData.any((data) => data.name == routeName)) {
          holder = candidate;
          break;
        }
        candidate = candidate.parent<RoutingController>();
      }
      if (holder == null) {
        logError(
          error: 'Navigation skipped, no stack holds the route: $routeName',
        );
        return;
      }

      for (
        RoutingController? ancestor = holder.parent<RoutingController>();
        ancestor != null;
        ancestor = ancestor.parent<RoutingController>()
      ) {
        if (ancestor is StackRouter) {
          ancestor.popUntil((route) => route.settings is Page);
        }
      }
      holder.popUntilRouteWithName(routeName);
    });

/// Pops back to [route] when the stack already holds it, otherwise pushes
/// it: no duplicate entries, which suits web apps.
///
/// For navigation to another section; within a section use [pushScreen].
Future<void> navigateScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('navigate', (router) => router.navigate(route));

/// Pops back to [path] when the stack already holds it, otherwise pushes it.
///
/// For navigation to another section; within a section use [pushPath]. A
/// path no route matches follows the router's redirect route if it has one,
/// and otherwise throws a `FlutterError` ("Can not navigate to …").
Future<void> navigatePath({required String path}) =>
    _withRouterAsync('navigatePath', (router) => router.navigatePath(path));

/// Replaces the top entry with [route]; when the top entry already is
/// [route], the screen is only updated.
Future<void> replaceScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('replace', (router) => router.replace(route));

/// Rebuilds the stack with [route] as its only entry; an entry already there
/// may be updated in place rather than recreated.
Future<void> replaceAllScreen({required PageRouteInfo<dynamic> route}) =>
    _withRouterAsync('replaceAll', (router) => router.replaceAll([route]));
