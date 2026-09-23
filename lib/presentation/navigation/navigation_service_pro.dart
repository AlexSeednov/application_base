import 'package:auto_route/auto_route.dart';

/// Injectable facade over the navigation helpers of `navigation_service.dart`.
///
/// The top-level navigation functions read the global `navigatorKey`, which
/// couples any view model that calls them to a mounted router. Depending on
/// this contract instead lets a project register a recording fake in tests and
/// assert navigation branches without pumping a widget tree.
///
/// Only route-object (type-safe) navigation is exposed; string-path helpers
/// (`pushPath` / `navigatePath`) and low-level accessors (`actualContext` /
/// `actualRouter` / `unfocus`) stay in `navigation_service.dart`. The default
/// `NavigationServiceRouter` implementation ships in
/// `navigation_service_router.dart` and is registered by the package's
/// injectable module — a project takes the contract from getIt or its
/// constructor and must not bind it a second time.
abstract interface class NavigationServicePro {
  /// Adds [route] to the screens stack (in-sector navigation).
  Future<void> push(PageRouteInfo<dynamic> route);

  /// Replaces the top screen with [route].
  Future<void> replace(PageRouteInfo<dynamic> route);

  /// Rebuilds the whole stack with [route] as its single entry.
  Future<void> replaceAll(PageRouteInfo<dynamic> route);

  /// Pops back to [route] when the stack already holds it, otherwise pushes
  /// it (cross-sector navigation).
  Future<void> navigate(PageRouteInfo<dynamic> route);

  /// Pops the top screen of the visible stack unless it is the only entry
  /// there, returning [result].
  ///
  /// The visible stack is the top-most router's — the nested one when the
  /// screens live inside a shell route — the way the system back button sees
  /// it.
  Future<void> pop({bool? result});

  /// Pops the top screen of the visible stack regardless of whether it is the
  /// last one there or of what its `PopScope`s say.
  ///
  /// A nested stack down to its last page hands the pop to the page that
  /// holds it rather than emptying itself.
  void popForced({bool? result});

  /// Keeps popping routes until a route named [routeName] is on top, in
  /// whichever stack holds it; a name no stack holds pops nothing.
  void popUntilRouteName(String routeName);

  /// Name of the screen on view — the top route of the top-most router — or
  /// `null` if the router is unavailable.
  String? get currentRouteName;
}
