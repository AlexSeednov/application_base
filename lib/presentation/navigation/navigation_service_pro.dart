import 'package:auto_route/auto_route.dart';

/// Injectable facade over the navigation helpers of `navigation_service.dart`.
///
/// The top-level navigation functions read the global `navigatorKey`, which
/// couples any view model that calls them to a mounted router. Depending on
/// this contract instead lets a project register a recording fake in tests and
/// assert navigation branches without pumping a widget tree.
///
/// Only route-object (type-safe) navigation is exposed; string-path helpers
/// (`pushNamed` / `navigatePath`) and low-level accessors (`actualContext` /
/// `actualRouter` / `unfocus`) stay in `navigation_service.dart`. The default
/// `NavigationServiceRouter` implementation ships in
/// `navigation_service_router.dart` but is not registered — bind it in the
/// consuming project's DI.
abstract interface class NavigationServicePro {
  /// Adds [route] to the screens stack (in-sector navigation).
  Future<void> push(PageRouteInfo<dynamic> route);

  /// Replaces the top screen with [route].
  Future<void> replace(PageRouteInfo<dynamic> route);

  /// Rebuilds the whole stack with [route] as its single entry.
  Future<void> replaceAll(PageRouteInfo<dynamic> route);

  /// Pops until [route] already exists in the stack, otherwise pushes it
  /// (cross-sector navigation).
  Future<void> navigate(PageRouteInfo<dynamic> route);

  /// Pops the top screen unless it is the only entry, returning [result].
  Future<void> pop({bool? result});

  /// Pops the top screen regardless of whether it is the last one in the stack.
  void popForced({bool? result});

  /// Keeps popping routes until a route named [routeName] is on top.
  void popUntilRouteName(String routeName);

  /// Name of the current (top) route, or `null` if the router is unavailable.
  String? get currentRouteName;
}
