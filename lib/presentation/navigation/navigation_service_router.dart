import 'package:application_base/presentation/navigation/navigation_service.dart'
    as base;
import 'package:application_base/presentation/navigation/navigation_service_pro.dart';
import 'package:auto_route/auto_route.dart';

/// [NavigationServicePro] backed by the global `navigatorKey` via AutoRoute.
///
/// Thin adapter: every method delegates to the top-level helpers in
/// `navigation_service.dart`.
final class NavigationServiceRouter implements NavigationServicePro {
  ///
  NavigationServiceRouter();

  ///
  @override
  Future<void> push(PageRouteInfo<dynamic> route) =>
      base.pushScreen(route: route);

  ///
  @override
  Future<void> replace(PageRouteInfo<dynamic> route) =>
      base.replaceScreen(route: route);

  ///
  @override
  Future<void> replaceAll(PageRouteInfo<dynamic> route) =>
      base.replaceAllScreen(route: route);

  ///
  @override
  Future<void> navigate(PageRouteInfo<dynamic> route) =>
      base.navigateScreen(route: route);

  ///
  @override
  Future<void> pop({bool? result}) => base.popScreen(result: result);

  ///
  @override
  void popForced({bool? result}) => base.popScreenForced(result: result);

  ///
  @override
  void popUntilRouteName(String routeName) =>
      base.popUntilScreenWithName(routeName: routeName);

  ///
  @override
  String? get currentRouteName => base.currentRouteName;
}
