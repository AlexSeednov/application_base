import 'package:application_base/core/const/navigator_transaction.dart';
import 'package:application_base/core/service/logger_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Logs every screen change, tab switches included, so the log of a bug
/// report shows the path the user took.
class NavigatorObserverPro extends AutoRouterObserver {
  ///
  NavigatorObserverPro();

  ///
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    logScreenChanged(
      transaction: NavigatorTransaction.push,
      from: previousRoute?.settings.name,
      to: route.settings.name,
    );
  }

  ///
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    logScreenChanged(
      transaction: NavigatorTransaction.replace,
      from: oldRoute?.settings.name,
      to: newRoute?.settings.name,
    );
  }

  ///
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    logScreenChanged(
      transaction: NavigatorTransaction.pop,
      from: route.settings.name,
      to: previousRoute?.settings.name,
    );
  }

  ///
  @override
  void didInitTabRoute(TabPageRoute route, TabPageRoute? previousRoute) {
    logScreenChanged(
      transaction: NavigatorTransaction.tabChanged,
      from: previousRoute?.name,
      to: route.name,
    );
  }

  ///
  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) {
    logScreenChanged(
      transaction: NavigatorTransaction.tabChanged,
      from: previousRoute.name,
      to: route.name,
    );
  }
}
