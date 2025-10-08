import 'package:application_base/core/service/logger_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Key for navigation without requiring context
final _navigatorKey = GlobalKey<NavigatorState>();

/// Key for navigation without requiring context
GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

/// Main application router
StackRouter? get actualRouter => actualContext?.router;

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

/// Removes the focus on this node by moving the primary focus to another node
void unfocus() => FocusManager.instance.primaryFocus?.unfocus();

/// Pop all routes and push default '/' route
void openDefaultScreen() => actualRouter!
  ..popUntilRoot()
  ..replacePath('/');

/// Adds a new entry to the screens stack
/// Can not return some value because of Future<smth> doesn't work with await...
Future<void> pushScreen({required PageRouteInfo<dynamic> route}) =>
    actualRouter!.push(route);

/// Adds a new entry to the screens stack by using path
Future<void> pushNamed({required String routeName}) =>
    actualRouter!.pushPath(routeName);

/// Pops the last screen unless stack has one entry
// Optimize(Alex): пометить как awaitNotRequired с выходом meta 1.17
Future<void> popScreen({bool? result}) => actualRouter!.maybePop(result);

/// Pop current route regardless if it's the last route in stack
/// or the result of it's
void popScreenForced({bool? result}) => actualRouter!.pop(result);

/// Keeps popping routes until route with provided path is found
void popUntilScreenWithName({required String routeName}) =>
    actualRouter!.popUntilRouteWithName(routeName);

/// Pops until provided route, if it already exists in stack
/// else adds it to the stack (good for web Apps)
void navigateScreen({required PageRouteInfo<dynamic> route}) =>
    actualRouter!.navigate(route);

/// Removes last entry in stack and pushes provided route.
/// if last entry == provided route screen will just be updated
Future<void> replaceScreen({required PageRouteInfo<dynamic> route}) =>
    actualRouter!.replace(route);

/// This's like providing a completely new stack as it rebuilds the stack
/// with the passed route.
/// Entry might just update if already exist
void replaceAllScreen({required PageRouteInfo<dynamic> route}) =>
    actualRouter!.replaceAll([route]);
