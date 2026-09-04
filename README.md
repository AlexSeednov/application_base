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
* [Haptics](#haptics)
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

The package registers its services through an injectable micro-package module.
Wire it into your service locator by adding the module to your `@InjectableInit`:

```dart
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/core/service/service_locator.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(ApplicationBasePackageModule)],
)
Future<void> configureDependencies() => getIt.init();
```

`getIt.init()` is asynchronous when external package modules are wired, so
**await** it during launch. Call `ApplicationBase.prepare();` afterwards — it
runs a post-DI step (flavor + lifecycle) and resolves `getIt<LifecycleService>()`,
so it must run AFTER `getIt.init()` has completed.

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

### Package services

The package registers its own services through an injectable micro-package
module (`ApplicationBasePackageModule`, generated into
`service_locator.module.dart` — see [Usage](#usage) for wiring). Every service
is a getIt-owned singleton: annotate the class with `@lazySingleton`, or with
`@LazySingleton(as: Contract)` to bind a contract to its implementation.
Dependencies are passed through the constructor (constructor injection), which
is marked `@visibleForTesting` so a second instance can't be created outside
tests. Ownership is uniform, so individual classes don't repeat this note.

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

3. Check for cyclic getIt dependencies — `getit_check`:

`getit_check` is a static analyzer shipped as an executable with this package.
It scans `lib/` of your project, finds classes registered via `injectable`
annotations (`@lazySingleton`, `@singleton`, `@injectable` and their
constructor forms `@LazySingleton(as: X)`, `@Singleton(as: X)`,
`@Injectable(as: X)`), collects every `getIt<T>()` call inside them, builds
a directed graph and reports cyclic dependencies ranked by severity.

Run from your project root:

```bash
dart run application_base:getit_check
dart run application_base:getit_check --verbose   # dump every registered class
                                                  # and its outgoing edges
dart run application_base:getit_check --no-color  # disable ANSI colors
dart run application_base:getit_check --ascii     # ASCII-only glyphs (for
                                                  # terminals without UTF-8)
```

The report is grouped by severity (HIGH first, then LOW), each cycle is drawn
as a ladder with colored `eager` / `lazy` arrows, every cycle gets a one-line
fix hint and classes that participate in two or more cycles are tagged with
`[hot: N cycles]` so the worst offenders stand out. A summary box at the end
gives the totals at a glance. Colors are auto-disabled when stdout is not a
TTY and respect the `NO_COLOR` environment variable.

Edge classification:

* **eager** — `getIt<X>()` is reached during construction (field initializer,
  constructor body or constructor initializer list). A cycle with **at least
  one eager edge** = guaranteed stack overflow the moment the first
  participant is created.
* **lazy** — `getIt<X>()` is reached only from a method/getter/setter body
  (or from a static field initializer, which runs on first access). A cycle
  made only of lazy edges is still suspicious, but it bites only when the
  calls happen to overlap in time.

The tool also flags duplicate registrations (multiple classes claiming the
same `getIt` name) and reports parse errors per file. Exit code is `0` on a
clean graph, `1` if cycles are found and `2` if `lib/` cannot be located —
suitable as a CI guard:

```bash
dart run application_base:getit_check || exit 1
```

Limitations: `getIt<T>()` calls inside mixins are not attributed to the
classes that include them via `with`; the analysis is purely static, so
every `getIt<T>()` reached through the AST is counted as a potential
dependency regardless of control flow.

## Logger

Based on [Logger](https://pub.dev/packages/logger)

For logging in remote systems (such as Crashlytics, Sentry or smth else) just
set `logInfoRemote` and `logErrorRemote`:

```dart
///
void _logInfo({required String information}) => 
    SomeRemoteService.log(information);
///
void _logError({required String error, StackTrace? stack}) => 
    SomeRemoteService.report(error, stack);

void prepare(){
    logInfoRemote = _logInfo;
    logErrorRemote = _logError;
}
```

The error sink takes the stack trace as a separate argument: reporters group
issues by frames, so a sink that receives text only would have to synthesise a
trace at the reporting site and pile unrelated errors into a single issue.

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
logError(error: 'Some error happened', stack: stackTrace);
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
created:

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

2. Also you can create `routerConfig` with existing `Access checker` and 
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
StackRouter? actualRouter;

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
    
    /// And that's all, navigator will close authorization route automatically
    /// and return to necessary screen
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
}
```

### NavigationServicePro (injectable facade)

The top-level functions above read the global `navigatorKey`, which couples any
view model that calls them to a mounted router. For testable navigation depend
on the `NavigationServicePro` contract instead — in tests register a recording
fake and assert navigation branches without pumping a widget tree.

The contract (`push` / `replace` / `replaceAll` / `navigate` / `pop` /
`popForced` / `popUntilRouteName` / `currentRouteName`) lives in
`navigation_service_pro.dart`; the `NavigationServiceRouter` implementation in
`navigation_service_router.dart`. The package ships both but **does not register
them** — bind them in your project's DI. With `injectable`:

```dart
import 'package:application_base/data/remote/utility/url_launcher_pro.dart';
import 'package:application_base/data/remote/utility/url_launcher_router.dart';
import 'package:application_base/presentation/navigation/navigation_service_pro.dart';
import 'package:application_base/presentation/navigation/navigation_service_router.dart';
import 'package:injectable/injectable.dart';

@module
abstract class ServiceModule {
  @lazySingleton
  NavigationServicePro get navigation => NavigationServiceRouter();

  @lazySingleton
  UrlLauncherPro get urlLauncher => UrlLauncherRouter();
}
```

or manually:
`getIt.registerLazySingleton<NavigationServicePro>(NavigationServiceRouter.new)`.

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

For testable link opening from view models use the `UrlLauncherPro` contract
(`open` / `sendEmail` / `call` / `sendSms`) with its `UrlLauncherRouter`
implementation instead of the static `UrlLauncher` — see
[NavigationServicePro](#navigationservicepro-injectable-facade) for the DI
binding pattern.

## Share

**ShareService** based on [share_plus](https://pub.dev/packages/share_plus)

```dart
await ShareService.share(text: text);
```

## Haptics

**HapticService** — tactile feedback over Flutter's own `HapticFeedback`, with
a small semantic vocabulary instead of raw impact strengths: the caller says
what happened, and the feel of «a choice moved», «a thing landed» or «that
failed» stays the same across the whole application.

```dart
final HapticService _haptic;      // constructor-injected into a view model

unawaited(_haptic.selection());   // a choice moving under the finger
unawaited(_haptic.lightImpact()); // a small action landing
unawaited(_haptic.mediumImpact());// a mode changing
unawaited(_haptic.longPress());   // a context menu picking up (iOS only)
unawaited(_haptic.success());     // a job coming good  — two rising beats
unawaited(_haptic.failure());     // something refused  — three flat beats
```

A cue is feedback on something the user is already seeing, never a signal of
its own; pair it with the visible change rather than with the code path that
caused it. Restoring saved state on open is not a gesture — leave it silent.
Whether anything is felt at all is the system's call: both mobile platforms
honour their own haptics switch, so an app needs no setting of its own.

`longPress()` is iOS-only on purpose: Material's ink already fires the
platform long-press haptic on Android, and a second one on top of it doubles
up.

The contract is what callers take, so a test can hand a view model a fake and
assert the cues it asked for. A platform with no haptics channel (desktop, the
web) is remembered after its first refusal and never asked again — a cue as
frequent as `selection()` would otherwise write a log line per tick of a drag.

## Widgets

```dart
EmptyButton(
  onClick: onClick,
  child: child,
),
```

`EmptyButton` gives no visual feedback except a focus ring for keyboard-driven
focus (`FocusHighlightMode.traditional`) — with a transparent overlay a
keyboard user would otherwise not see where they are. Pass `focusBorderRadius`
to match the rounding of the child.

```dart
UnfocusingTap(child: child),
```

```dart
OpacityPro(
  isFullyOpaque: isEnabled,
  minOpacity: 0,
  child: child,
),
```

```dart
EnabledPro(
  isEnabled: isAvailable,
  disabledOpacity: 0,
  child: child,
),
```

## Web

Flutter on the web is a canvas with a keyboard, a mouse and a URL bar around
it: several things a browser page does for free have to be wired by hand. This
section collects what the package provides for that and the rules an app has to
follow for it to work.

### Keyboard scrolling

On the web Flutter maps the arrows, PageUp/PageDown and Space to `ScrollIntent`
by itself and handles them with the built-in `ScrollAction`. The action scrolls
the `Scrollable` around the focused widget, and when nothing inside a scrollable
is focused, it falls back to the route's `PrimaryScrollController`, which then
must have **exactly one** attached scroll position. That is where the web
differs from mobile: on desktop platforms (and the web in a desktop browser
reports the host OS) scroll views do **not** inherit the primary controller
automatically, so the controller has no clients and the keys do nothing.

Rules that make it work:

- **Exactly one root scrollable per route gets `primary: true`**: the page
  list, the sheet list, the dialog list. Nested lists (`shrinkWrap`,
  `NeverScrollableScrollPhysics`) must not be `primary`: a second position on
  the route controller fails the scroll action and the desktop scrollbar.
- A scroll view that **owns** the route controller (passes it as `controller`
  and reads `offset` from it) wraps its content in
  `PrimaryScrollController.none`: on mobile nested vertical lists inherit the
  primary controller and would attach to it as well.
- **Tabs (`IndexedStack`)**: Flutter excludes a hidden tab from focus, but the
  focus lands on the scope above the tabs, where there is nothing to scroll.
  When a tab becomes active, focus the scope of the top route of its navigator,
  and do it after the frame: until the stack rebuilds the tab is still
  excluded and the request is silently dropped.

  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final FocusNode navigatorNode = Navigator.of(context).focusNode;
    final FocusScopeNode? topRouteScope = navigatorNode.children
        .whereType<FocusScopeNode>()
        .lastOrNull;

    (topRouteScope ?? FocusScope.of(context)).requestScopeFocus();
  });
  ```

- `unfocus()` (and `UnfocusingTap` with it) leaves the focus alone when it
  already sits on a scope: unfocusing a scope moves the focus one scope up,
  and a tap on the page background would otherwise kill keyboard scrolling.
- A focused `TextField` keeps the keys, as it does in a browser.

`KeyboardShortcutsPro` adds what Flutter does not map: Home/End (also with
Ctrl) and Shift+Space. Its actions also replace the framework's own
`ScrollAction` with `ScrollActionPro`, which is what makes a **held** key
usable: the framework aims every press at the offset the page holds at that
moment and animates there over 100ms with an eased curve, while the OS repeats
a held key every 30–60ms — each repeat cancels the previous animation in its
slow opening and starts another from there, and the page crawls at a fraction
of a step per press. `ScrollActionPro` adds the step of a repeat to the target
the previous press aimed at and drives the animation at the pace of the
repeats, so a held key scrolls a whole step per repeat and stops with the key.
A single press is unchanged, and Home/End go the same way, aiming at a target
that does not move.

Pass both maps to the app; they extend the defaults, so the text-editing
shortcuts still win inside a field:

```dart
MaterialApp.router(
  shortcuts: KeyboardShortcutsPro.shortcuts,
  actions: KeyboardShortcutsPro.actions,
  ...
)
```

### Links

A tap target is not a link for the browser: no URL on hover, no Ctrl/Cmd+click
or middle click into a new tab. `RouteLink` makes a widget a real link on the
web (`url_launcher`'s `Link`, an `<a>` element over the widget) and stays a
plain `EmptyButton` elsewhere:

```dart
RouteLink(
  path: '/catalog/product/1', // absolute in-app path; null — no link, tap only
  onClick: viewModel.openDetails,
  child: card,
)
```

A plain click goes to `onClick`, the same in-app navigation as before, with
whatever data the view model already holds. Only a click with a modifier key is
handed to the link: the browser opens the new tab itself, and without a
`followLink` signal from the app the plugin cancels the in-tab navigation.
Build the path from the same route object the click pushes (auto_route's
`RouteMatcher.matchByRoute` + `UrlState.fromSegments`), so the URL on hover
matches the one the click produces. Pass the encoded form (`uri.toString()`),
not the decoded `UrlState.url`, and keep the query in the path string: the
widget parses it, a `Uri(path:)` would percent-encode the `?`.

An external URL (`https://…`) works the same way and gets `target="_blank"`:
the browser context menu recognises it as a link, and a modifier-click opens
it in a new tab; a plain click still goes to `onClick`, so the app keeps its
own way of opening such links.

### Middle-button autoscroll

A browser scrolls a page from a middle click: the press anchors it, the mouse
then sets the direction and the speed, and a click ends the mode. On the web
the browser cannot do it here — Flutter draws into a canvas, the document
holds no scrollable element of its own — so `AutoScrollPro` rebuilds the mode
over the application. Wrap the whole of it, above the navigator, and the
anchor mark and the pointer block cover the pages, the sheets and the dialogs
alike:

```dart
MaterialApp.router(
  builder: (_, child) => AutoScrollPro(child: child!),
  ...
)
```

The step goes out the way the wheel does — a synthesized `PointerScrollEvent`
aimed at the anchor — rather than as a write into a scroll position: the
framework then picks the scrollable itself, the one the user aimed at, keeps
its physics, and hands the movement to the parent when a nested list has
nowhere left to go. Only when nothing under the anchor scrolls at all (a fixed
header, a side menu) does the route's primary position take the step directly
— the same position the keyboard scrolls, so the *one root scrollable per
route* rule above serves this mode as well.

While the mode is on, the application stands behind a pointer block: the click
that ends the mode presses nothing and hovers nothing, as in a browser. The
block opens for the mode's own wheel events alone. The browser is held off as
well — the default of the middle button is prevented while the mode is on, or
the click that ends it would also open the link under the cursor in a new tab,
since a `RouteLink` is a real `<a>` element the browser acts on by itself. The mode also ends on the
wheel, on Escape, on the window losing the application, on the mouse leaving
it, and on the release of a button that was dragged rather than clicked.

Over a `RouteLink` the middle button belongs to the browser — it opens the
link in a new tab — so the link takes that click from the mode through
`AutoScrollScope`. Anything else that answers the middle button itself should
do the same.

Nothing is gated on the web: a platform without a middle button never starts
the mode, and on Windows the same gesture is a desktop convention.

### Browser context menu

Over the canvas the browser menu only offers "Back" and "Reload", but on a
`RouteLink` it is the native link menu — "Open in new tab", "Copy link
address" — so it is worth keeping. `BrowserContextMenu.disableContextMenu()`
(after the binding is initialised) removes it everywhere at once; text fields
then show Flutter's own menu instead.

### Keyboard focus

`EmptyButton` draws a focus ring for keyboard-driven focus so a keyboard user
can see where they are; Material buttons show their own focus overlay.
