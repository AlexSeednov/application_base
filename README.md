<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Unified base for Flutter applications based on 
[special architecture](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014)

## Features

For now includes:
* [Analysis options](#analysis-options)
* [Flavor](#flavor)
* [GetIt](#getit)
* [Logger](#logger)
* [Navigation utilities](#navigation-utilities)
* [API interaction](#api-interaction)
* [Online / offline state change checker](#online--offline-state-change-checker)
* [Application lifecycle state change checker](#application-lifecycle-state-change-checker)
* [StorageService](#local-storage-service)
* [Url launcher](#url-launcher)
* [Share](#share)
* [Some useful widgets](#widgets)

## Supported platforms

* Android
* iOS
* Linux - not tested yet
* MacOS - not tested yet
* Web
* Windows - not tested yet

## Requirements 

Based on minimum requirements from all usage packages. 

Flutter & dart versions compatibility 
[information](https://docs.flutter.dev/release/archive)
test2
* Flutter >=3.35.4
* Dart >=3.9.2
* iOS >=12.0 - connectivity_plus ^5.0.0
* MacOS >=10.14 - connectivity_plus ^6.0.1
* Android compileSDK 36 - Flutter ^3.35.0
* Java 17 - connectivity_plus ^6.0.1
* Android Gradle Plugin >=8.12.1 - connectivity_plus ^7.0.0
* Gradle wrapper >=8.13 - connectivity_plus ^7.0.0
* Kotlin >=2.2.0 - connectivity_plus ^7.0.0

## Changelog

Refer to the 
[Changelog](https://github.com/AlexSeednov/application_base/blob/main/CHANGELOG.md) 
to get all release notes

## Usage

Add a line like this to your package's pubspec.yaml (and run an implicit 
flutter pub get):

```yaml
dependencies:
  # All platform supported
  application_base:
    git:
      url: https://github.com/AlexSeednov/application_base
      tag_pattern: v{{version}}
    version: 0.1.3
```

Now just call `ApplicationBase.prepare();` on application launching to 
initialize all necessary data.

Important: do not forget to call `WidgetsFlutterBinding.ensureInitialized();` 
before preparing.

## Analysis options

Create an `analysis_options.yaml` file at the root of the package (alongside 
the `pubspec.yaml` file) and `include: application_base/analysis_options.yaml` 
from it.

Example `analysis_options.yaml` file:

```yaml
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.
#
# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options
#
# Full list of rules can be fount at https://dart.dev/tools/linter-rules
#
# To get a preview of the proposed changes run
# dart fix --dry-run
#
# To apply the changes run
# dart fix --apply
include: package:application_base/analysis_options.yaml
```

## Flavor

Pre-created `Development` and `Production` flavors with public getter `flavor`.
You can set it directrly on package prepare flow:

```dart
import 'package:application_base/application_base.dart';
import 'package:application_base/core/const/flavor_type.dart';

ApplicationBase.prepare(currentFlavor: FlavorDevelopment());
```

or everythere you want by setter:

```dart
import 'package:application_base/application_base.dart';
import 'package:application_base/core/const/flavor_type.dart';

flavor = FlavorDevelopment();
```

Note: it's highly recommended not to change the flavor while the application is 
running. Just set it once when launching the application

## GetIt

Based on [get_it](https://pub.dev/packages/get_it)

1. Prepare GetIt:

```dart
import 'package:application_base/core/service/service_locator.dart';

getIt.registerLazySingleton<AwesomeService>(AwesomeService.new);
```

2. And use it:

```dart
import 'package:application_base/core/service/service_locator.dart';

getIt<AwesomeService>().makeMagic();
```

## Logger

Based on [Logger](https://pub.dev/packages/logger)

For logging in remote systems (such as Crashlytics, Sentry or smth else) just
set `logInfoRemote` and `logErrorRemote`:

```dart
///
void _logInfo({required String information}) => 
    SomeRemoteService.log(information);
///
void _logError({required String error}) => 
    SomeRemoteService.log(error);

void prepare(){
    logInfoRemote = _logInfo;
    logErrorRemote = _logError;
}
```

You can set User ID for local error logging:

```dart
///
void setUser() {
    /// Set user in logger
    loggerUserId = userId;
}
```

And use logger everywhere it need

```dart
logInfo(info: 'Interesting information');
logError(error: 'Some error happened');
```

Also created **LoggingMixin** for easier named logs in classes. Just mix it and
use:

```dart
final class SomeService with LoggingMixin {
  /// Name for logger
  @override
  String logName = 'Some Service';

  /// Example function
  Future<void> example() {

    /// Do some stuff
    
    logNamedInfo(info: 'done'); // Will log `Some Service: done`

    /// or

    logNamedError(error: 'broken'); // Will log `Some Service: broken`
  }
}
```

## Navigation utilities

Based on [AutoRoute](https://pub.dev/packages/auto_route)

On application preparing `RootStackRouter` based on `navigatorKey` must be 
created and set as `router`:

1. Create router instance

```dart
import 'package:application_base/presentation/navigation/guard/authentication_guard.dart';
import 'package:application_base/presentation/navigation/navigation_service.dart';

///
final routerInstance = RouterPro(
  authenticationGuard: AuthenticationGuard(
    authorizationRoute: const AuthRoute(),// Your default non-authorized route
  ),
  navigatorKey: navigatorKey,
);
```

2. Set created instance as `router`

Somewhere on application launching

```dart
import 'package:application_base/presentation/navigation/navigation_service.dart';

router = routerInstance;
```

Or set it directrly on package prepare flow

```dart
import 'package:application_base/application_base.dart';

ApplicationBase.prepare(routerInstance: routerInstance);
```

3. Also you can create `routerConfig` with existing `Access checker` and 
`Observer`:

```dart
///
final RouterConfig<UrlState> routerConfig = routerInstance.config(
    reevaluateListenable: getIt<AccessVM>(),
    navigatorObservers: () => [
        NavigatorObserverPro(),
    ],
);
```

and use it as Application `routerConfig`

```dart
MaterialApp.router(
    /// ...
    routerConfig: routerConfig,
    /// ...
)
```

Now you can use popular navigation functions directly from 
`navigation_service.dart`:

```dart
/// Pop all routes and push default '/' route
void openDefaultScreen();

/// Adds a new entry to the screens stack
Future<void> pushScreen({required PageRouteInfo<dynamic> route});

/// Adds a new entry to the screens stack by using path
Future<void> pushNamed({required String routeName});

/// Pops the last screen unless stack has one entry
Future<void> popScreen({bool? result});

/// Pop current route regardless if it's the last route in stack
/// or the result of it's
void popScreenForced({bool? result});

/// Keeps popping routes until route with provided path is found
void popUntilScreenWithName({required String routeName});

/// Pops until provided route, if it already exists in stack
/// else adds it to the stack (good for web Apps)
void navigateScreen({required PageRouteInfo<dynamic> route});

/// Removes last entry in stack and pushes provided route.
/// if last entry == provided route screen will just be updated
Future<void> replaceScreen({required PageRouteInfo<dynamic> route});

/// This's like providing a completely new stack as it rebuilds the stack
/// with the passed route.
/// Entry might just update if already exist
void replaceAllScreen({required PageRouteInfo<dynamic> route});
```

Also you've got special function for unfocus and getters for actual context
and router:

```dart
/// Router for direct usage of full auto_route functionality
RootStackRouter router;

/// Actual context for everywhere accessibility
BuildContext? actualContext;

/// Removes the focus on this node by moving the primary focus to another node
void unfocus();
```

Every screen and tab changes will be auto-loggied via `NavigatorObserverPro`

Navigator check screens accessibility automatically via `AuthenticationGuard` 
and `AccessVM`. For it you need to create `AuthenticationGuard` and add it
in `routes`:

```dart
import 'package:application_base/presentation/navigation/guard/authentication_guard.dart';
import 'package:auto_route/auto_route.dart';

class RouterPro extends RootStackRouter {
  ///
  RouterPro({
    required this.authenticationGuard,
    super.navigatorKey,
  });

  ///
  final AuthenticationGuard authenticationGuard;

  ///
  @override
  List<AutoRoute> get routes => [
        /// Authorization screen - accessible without authorization
        AdaptiveRoute<void>(
          path: 'authorization',
          page: AuthorizationRoute.page,
        ),

        /// Main screen - authorization required
        AdaptiveRoute<void>(
          initial: true,
          path: '/',
          page: MainRoute.page,
          guards: [authenticationGuard], // <--
        ),
  ];
}
```

Now you can **grant** or **revoke** access anytime:

```dart
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/view_model/access_vm.dart';

///
void login(){
    /// ... Do some login stuff ...

    /// Now grant an access
    getIt<AccessVM>().grantAccess();

    /// And pop for making magic
    popScreenForced();
}

///
void logout(){
    /// ... Do some logout stuff ...

    /// Now revoke access
    getIt<AccessVM>().revokeAccess();

    /// And that's all, navigator will open authorization route automatically
    /// and return to previously screen on successfully access restore

    /// If you don't need to return to previously screen, you can do next:    
    getIt<AccessVM>().revokeAccess(needNotify: false);

    /// In that case navigator will open default screen on successfully access 
    /// restore
}
```

## API interaction

TBD

Based on [http](https://pub.dev/packages/http).

Service for safe JSON parsing included.

## Online / offline state change checker

TBD

## Application lifecycle state change checker

Realised via `LifecycleService` singleton.

```dart
  /// Create onUpdate function
  void onUpdate(AppLifecycleState state){
    /// Do some stuff
  }

  /// And subscribe to changes
  getIt<LifecycleService>().listen(onUpdate);
```

## Local storage service

Registered via getIt singleton based on 
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) 
and [hive_ce](https://pub.dev/packages/hive_ce)

Set dependency in `pubspec.yaml`

```
dependencies:
  ...
  hive_ce: 2.10.1
  hive_ce_flutter: 1.2.0  
  ...
dev_dependencies:
  ...
  hive_ce_generator: 1.8.1
  ...
```

Generate all adapters (more information 
[here](https://pub.dev/packages/hive_ce#store-objects))
and prepare **StorageService**

```dart
await getIt<StorageService>().prepare(
  cipherKey: 'secret key',
  registerAdapters: hive.registerAdapters, // Generated by Hive CE Generator
);
```

## Url Launcher 

Two functions to try to launch a link and send an email based on 
[url_launcher](https://pub.dev/packages/url_launcher)

```dart
final bool linkResult = await UrlLauncher.launchLink('https://link');
final bool emailResult = await UrlLauncher.launchSendMail(
      to: 'smth@email.com',
      title: 'Awesome email',
      body: 'Strong email body!',
    );
```

## Share

**ShareService** based on [share_plus](https://pub.dev/packages/share_plus)

```dart
await ShareService.share(text: text);
```

## Widgets

```dart
EmptyButton(
  onClick: onClick,
  child: child,
),
```

```dart
UnfocusingTap(child: child),
```