import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/view_model/access_vm.dart';
import 'package:auto_route/auto_route.dart';

/// Lets a route open only while [AccessVM] grants access; otherwise sends the
/// user to [authorizationRoute].
///
/// The redirect waits for access (`redirectUntil`): once [AccessVM] notifies
/// a grant, the router re-evaluates the guard and resumes the original
/// navigation.
final class AuthenticationGuard implements AutoRouteGuard {
  ///
  AuthenticationGuard({required this.authorizationRoute});

  ///
  final PageRouteInfo<dynamic> authorizationRoute;

  ///
  @override
  void onNavigation(NavigationResolver resolver, _) {
    if (getIt<AccessVM>().isGranted) {
      resolver.next();
    } else {
      logInfo(info: 'Try to open ${resolver.routeName} without access');
      resolver.redirectUntil(authorizationRoute);
    }
  }
}
