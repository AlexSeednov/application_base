import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/view_model/access_vm.dart';
import 'package:auto_route/auto_route.dart';

class AuthenticationGuard implements AutoRouteGuard {
  ///
  AuthenticationGuard({required this.authorizationRoute});

  ///
  final PageRouteInfo<dynamic> authorizationRoute;

  ///
  @override
  void onNavigation(NavigationResolver resolver, _) {
    if (getIt<AccessVM>().isGranted) {
      /// Account exist, continue navigation
      resolver.next();
    } else {
      /// Need to sign in or sign up before
      logInfo(info: 'Try to open ${resolver.routeName} without access');
      resolver.redirectUntil(authorizationRoute);
    }
  }
}
