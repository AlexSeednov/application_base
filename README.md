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

**English** | [Русский](README.ru.md)

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
* [Clipboard](#clipboard)
* [Store listing](#store-listing)
* [Identifiers](#identifiers)
* [Application locale](#application-locale)
* [Some useful widgets](#widgets)
* [Web](#web)

## Supported platforms

* Android
* iOS
* Linux - not tested yet
* MacOS - not tested yet
* Web
* Windows - not tested yet

## Requirements 

Based on minimum requirements from all the packages it uses. 

Flutter & dart versions compatibility 
[information](https://docs.flutter.dev/release/archive)

* Flutter >=3.44.4
* Dart >=3.12.2
* iOS >=13.0 - url_launcher_ios ^6.3.5
* MacOS >=10.15 - url_launcher_macos ^3.2.4
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
    version: 0.4.3
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
the `pubspec.yaml` file) and 
`include: package:application_base/analysis_options.yaml` from it.

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
# Full list of rules can be found at https://dart.dev/tools/linter-rules
#
# To get a preview of the proposed changes run
# dart fix --dry-run
#
# To apply the changes run
# dart fix --apply
include: package:application_base/analysis_options.yaml
```

## Flavor

Pre-created `Development`, `Stage` and `Production` flavors with public getter
`flavor`. Every flavor carries a short `name` (`Dev` / `Stage` / `Prod`) used
by the logger and by [`BannerPro`](#widgets) — short because the banner's
ribbon is narrow and clips a long word.

You can set it directly on package prepare flow:

```dart
import 'package:application_base/application_base.dart';
import 'package:application_base/core/const/flavor_type.dart';

ApplicationBase.prepare(currentFlavor: FlavorDevelopment());
```

or anywhere you want by the setter:

```dart
import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';

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

1. Register a service with an injectable annotation — the registration
itself is generated by `build_runner`, never written by hand:

```dart
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

@lazySingleton
final class AwesomeService {
  @visibleForTesting
  AwesomeService();

  void makeMagic() {}
}
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

For logging in remote systems (such as Crashlytics, Sentry or something else)
just set `logInfoRemote` and `logErrorRemote`:

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

And use the logger wherever you need it

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
  Future<void> example() async {

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
/// Adds a new entry to the screens stack
Future<void> pushScreen({required PageRouteInfo<dynamic> route});

/// Adds a new entry to the screens stack by using path
Future<void> pushNamed({required String routeName});

/// Pops the last screen of the visible stack unless it is the only entry
Future<void> popScreen({bool? result});

/// Calls pop on the controller with the top-most visible page — the same
/// call as popScreen, kept for existing callers
void popTopScreen({bool? result});

/// Pops the current screen of the visible stack regardless of whether it is
/// the last one there or of what its PopScopes say
void popScreenForced({bool? result});

/// Keeps popping routes until route with provided name is found,
/// in whichever stack holds it
void popUntilScreenWithName({required String routeName});

/// Pops until provided route, if it already exists in stack
/// else adds it to the stack (good for web Apps)
Future<void> navigateScreen({required PageRouteInfo<dynamic> route});

/// Pops until provided path, if it already exists in stack
/// else adds it to the stack
Future<void> navigatePath({required String path});

/// Removes last entry in stack and pushes provided route.
/// if last entry == provided route screen will just be updated
Future<void> replaceScreen({required PageRouteInfo<dynamic> route});

/// This's like providing a completely new stack as it rebuilds the stack
/// with the passed route.
/// Entry might just update if already exist
Future<void> replaceAllScreen({required PageRouteInfo<dynamic> route});
```

Also you've got a special function for unfocus and getters for the navigator
key, the actual context and router, and the name of the screen on view:

```dart
/// Key for navigation without requiring context
GlobalKey<NavigatorState> get navigatorKey;

/// Router for direct usage of full auto_route functionality
StackRouter? get actualRouter;

/// Actual context for everywhere accessibility
BuildContext? get actualContext;

/// Name of the screen on view: the current route of the top-most router
String? get currentRouteName;

/// Drops the focus from the focused node by moving the primary focus to its
/// scope
void unfocus();
```

Every screen and tab change is logged automatically via `NavigatorObserverPro`

The navigator checks screen accessibility automatically via 
`AuthenticationGuard` and `AccessVM`. For it you need to create
`AuthenticationGuard` and add it in `routes`:

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
    /// and return to the previous screen once access is restored

    /// If you don't need to return to the previous screen, you can do next:    
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
`navigation_service_router.dart`. The implementation is annotated
`@LazySingleton(as: NavigationServicePro)`, so `ApplicationBasePackageModule`
registers it together with the other package services; the same goes for
`UrlLauncherRouter` behind [`UrlLauncherPro`](#url-launcher). With the module
wired as in [Usage](#usage) there is nothing to bind: **do not register them
again** in your project's DI — getIt rejects a second registration of the same
type. Take the contract through the constructor of an injectable class, or
from `getIt<NavigationServicePro>()`:

```dart
import 'package:application_base/presentation/navigation/navigation_service_pro.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

@lazySingleton
final class SettingsVM {
  @visibleForTesting
  SettingsVM(this._navigation);

  final NavigationServicePro _navigation;

  Future<void> openProfile() => _navigation.push(const ProfileRoute());
}
```

## API interaction

Based on [http](https://pub.dev/packages/http). An application has one request
service — a singleton extending `RequestServiceBase` — and every call to the
backend goes through it:

```text
typed request → sendBase → ResponseEntity → Entity.parse → null on error
```

### Request service

The application extends `RequestServiceBase` once. The one thing it must
provide is `prepareUri` — how a path becomes an address. Headers (tokens and
the like) are its business too: they are handed to `sendBase` on every call.

```dart
@lazySingleton
final class RequestService extends RequestServiceBase {
  @visibleForTesting
  RequestService();

  @override
  Uri prepareUri({required String path}) =>
      Uri.parse('https://api.example.com/api/v1/$path');

  @disposeMethod
  @override
  void dispose() => super.dispose();

  Future<ResponseEntity?> send(RequestType request) =>
      sendBase(request: request, headers: {'Accept': 'application/json'});
}
```

`@disposeMethod` on the override is required: the base class is abstract and
not registered itself, so only the concrete registration lets getIt close the
HTTP client with its keep-alive connections on reset. The timeouts are getters
— `shortTimeout` (3 s), `normalTimeout` (20 s), `longTimeout` (30 s) — to
override where they do not fit. The `client` setter replaces the HTTP client
(with a wrapper that intercepts a status for every request, say) and closes the
previous one.

### Requests

A request is a value describing one call: `RequestGet`, `RequestPost`,
`RequestPut`, `RequestPatch`, `RequestDelete`, and two uploads —
`RequestPostFormData` (multipart fields plus `XFile`s) and `RequestPostFile`
(one file streamed as `application/octet-stream`). `path` is the part after the
base address, a body is a ready JSON string:

```dart
final ResponseEntity? response = await getIt<RequestService>().send(
  RequestPost(
    path: 'projects',
    body: jsonEncode(project.toJson()),
    expectedErrorMap: {HttpStatus.conflict: NetworkCustomEvent(data: 'duplicate')},
  ),
);
```

What a request can say about itself:

* `expectedStatusList` — empty by default, which means any 2xx is a success.
  Fill it in only when the exact status carries meaning, to take over a `404`
  for instance; a non-empty list is matched exactly.
* `expectedErrorMap` — `status → NetworkEvent`: the event a failure is reported
  with instead of the generic `NetworkUnexpectedResponse`. An event can carry
  `data` — which of several messages to show, say.
* `silence` — the request reports neither its success nor its errors: a
  background ping, a prefetch whose failure the user should not see. What
  concerns the whole application still goes out — a lost connection, a `401`.
* `durationType` — `short` / `normal` / `long`, the timeout the request runs
  with. `normal` by default; the two uploads default to `long`, since an
  upload is exactly the heavy request `longTimeout` is there for.

### The result

`sendBase` never throws. It returns a `ResponseEntity` (`body`, `statusCode`,
`isOk`, and `request` for the logs) when the status was expected, and `null`
otherwise. By then the failure is already reported to `NetworkSubject`, so the
caller shows no error of its own — it just returns its own "no result":

| What happened | Event |
| --- | --- |
| an expected status | `NetworkSuccess` |
| `401` | `NetworkUnauthorized` |
| `504`, a timeout, no socket, a failed SSL handshake, `ClientException` on the web | `NetworkConnectionLost` |
| a status from `expectedErrorMap` | that event |
| any other status | `NetworkUnexpectedResponse` |
| any other exception | `NetworkUnexpectedError` |

Two parameters of `sendBase` widen a single call without touching the request:

* `extraExpectedStatusList` — accept more statuses this once: a `401` the
  service wants to answer with a token refresh instead of the unified path. It
  only ever adds.
* `extraExpectedErrorMap` — a handler every request of the service gets
  without each call site declaring it (an outdated-client status, say). It wins
  over the request's own entry for the same status.

`catchRedirect(uri:, headers:)` returns the `Location` of a redirect without
following it — `null` when there is no redirect or the call failed.

### Parsing

`SafeService` turns a body into entities without letting a malformed payload
escape as an exception:

```dart
static ProjectEntity? parse(ResponseEntity data) =>
    SafeService.parse<ProjectEntity>(data, ProjectEntity.fromJson);

static List<ProjectEntity> parseList(ResponseEntity data) =>
    SafeService.parseList<ProjectEntity>(data, ProjectEntity.fromJson);
```

`parse` returns `null` on an empty or malformed body. `parseList` returns an
empty list when the body is not a list, and skips a single element that fails
to parse — one bad record costs itself, not the whole page. Every failure is
logged.

Every request and response is logged as well: the method and path, the
status, and the bodies only while `canLogSensitiveData` is on (by default — in
debug builds only).

## Online / offline state change checker

Whether the application is online is decided from two sources: the network
interface (`connectivity_plus`) and the backend itself. A link the system
reports proves nothing — Wi-Fi without Internet, a captive portal, a backend
that is down — so the last word is the backend's: the offline mode turns on
when requests stop reaching it and off when one gets through again.

### Network service

The application extends `NetworkServiceBase` once, telling it how to ping the
backend. The same class is the one place that reacts to the events of every
request:

```dart
@lazySingleton
final class NetworkService extends NetworkServiceBase {
  @visibleForTesting
  NetworkService();

  @override
  Future<bool> sendPingRequest() async {
    final ResponseEntity? response = await getIt<RequestService>().send(
      RequestGet(
        path: 'ping',
        silence: true,
        durationType: RequestDurationType.short,
      ),
    );
    return response != null;
  }

  @override
  void onUpdate(NetworkEvent event) {
    super.onUpdate(event);

    if (event is NetworkUnauthorized) unawaited(signOut());
  }

  @disposeMethod
  @override
  void dispose() => super.dispose();
}
```

Call `prepare()` once on start, when the request service is ready: it
subscribes to `NetworkSubject`, starts watching the interface and pings the
backend once. From then on:

* **Offline** comes with `NetworkConnectionLost`: the interface reports no link
  (a link that disappears is re-checked after 3 s — right after a reconnect iOS
  briefly reports none), a request failed to reach the backend (a timeout, no
  socket, SSL, a `504`), or the ping on start failed.
* **While offline** the service pings every `pingPeriod` (30 s by default;
  override the getter), and at once when the interface reports a link again.
* **Online** returns with the first successful ping or with any request that
  gets an expected response; `NetworkRestore` then goes out to every listener.
  A silent request reports nothing, so it does not count.

`isOnlineNotifier` (`ValueNotifier<bool>`) carries the state to the UI — an
offline banner, disabled actions — next to `isOnline` / `isOffline`, and
`isWiFi` serves a choice like "download over Wi-Fi only". `LifecycleService`
re-reads the interface every time the application returns to the foreground:
since Android 8.0 a background app receives no connectivity changes.

### Reloading on restore

A screen whose data did not load while offline reloads it once the connection
is back, with `ConnectionRestoreMixin`:

```dart
final class ProjectListVM with ConnectionRestoreMixin {
  void init() => prepareConnection();

  Future<void> dispose() => disposeConnection();

  @override
  void onConnectionRestore() => unawaited(refresh());
}
```

Both calls are safe to repeat: `prepareConnection` keeps the subscription it
already has, and `disposeConnection` works even when `prepareConnection` never
ran. Anything else can listen to `NetworkSubject` directly — `listen` for every
event, `listenConnectionRestore` for the restore alone.

## Application lifecycle state change checker

Implemented via `LifecycleService` singleton.

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
  hive_ce: 2.19.3
  hive_ce_flutter: 2.3.4
  ...
dev_dependencies:
  ...
  hive_ce_generator: 1.11.2
  ...
```

`hive_ce_generator` 1.11.2 still caps `analyzer` at `^12.0.0`, while this
package requires `^13.0.0`. Until the generator catches up, the application
resolves the pair with a `dependency_overrides` entry for `analyzer` — the
generators run at build time only, so check the regenerated code once.

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

Static helpers to try to launch a link and send an email based on 
[url_launcher](https://pub.dev/packages/url_launcher); each returns whether it
succeeded:

```dart
final bool linkResult = await UrlLauncher.launchLink('https://link');
final bool emailResult = await UrlLauncher.sendEmail(
      to: 'smth@email.com',
      title: 'Awesome email',
      body: 'Strong email body!',
    );
```

`makeCall` and `sendSms` open the phone and messaging apps; on the web
`launchLinkInSameTab` and `launchLinkViaLocation` open a link in the current
browser tab instead of a new one.

For testable link opening from view models use the `UrlLauncherPro` contract
(`open` / `sendEmail` / `call` / `sendSms`) with its `UrlLauncherRouter`
implementation instead of the static `UrlLauncher`. The package module
registers it — take it from getIt or through the constructor, as with
[NavigationServicePro](#navigationservicepro-injectable-facade).

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

## Clipboard

**ClipboardService** — the system clipboard with a haptic cue on every copy:
copied text gives no visual feedback of its own, so the tap has to be felt.

```dart
await ClipboardService.set('text to copy');
final String text = await ClipboardService.get();
```

## Store listing

**StoreService** — opens the store page of the application. One place for
every reason to send the user there — rating the app, taking an update the
backend now demands — because it is one and the same page. The store identity
is handed over once on start-up, so a tap carries nothing but itself:

```dart
getIt<StoreService>().appStoreId = '1234567890'; // Apple platforms only

// the control is shown only where there is a store to open
if (getIt<StoreService>().isAvailable) ...

await getIt<StoreService>().openListing();
```

Android, iOS and macOS have a store the plugin can open; everywhere else
`isAvailable` is `false` and `openListing()` does nothing, so an application
hides the control rather than offering one that leads nowhere. On the Apple
platforms the listing cannot be found without `appStoreId` — a missing one is
logged as an error instead of throwing.

The in-app rating sheet is deliberately left out. The system shows it at its
own discretion and does nothing at all once the user has rated the application
or the platform quota is spent — while the plugin's `isAvailable()` keeps
answering true, so an application cannot tell a shown sheet from a swallowed
one. A tap on an explicit «rate us» control has to land somewhere every time,
and only the store listing does.

## Identifiers

**UuidPro** — the random (v4) identifiers an application stores with its
records:

```dart
final String uid = UuidPro.get();
```

One generator for the whole application: `Uuid` carries a random number
generator of its own, and building a fresh one per identifier is pure waste.

## Application locale

**ApplicationLocale** — makes `intl` format dates and numbers in the language
of the interface. Wire it once, into the root application:

```dart
MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: ApplicationLocale.resolve,
  // ...
)
```

Without it `DateFormat` and `NumberFormat` take the device's locale, not the
application's: a Russian-only application on an English phone renders its text
in Russian and its months, weekdays and decimal separators in English. The
usual patch — a locale pinned into every formatter call,
`DateFormat('d MMMM', 'ru')` — hides the bug and has to be undone for each
language added. With the callback wired, a formatter takes no locale argument:

```dart
DateFormat('d MMMM').format(date); // «5 марта» in a Russian application
NumberFormat.decimalPattern().format(1.5); // «1,5»
```

The locale is resolved by Flutter's own algorithm (`basicLocaleListResolution`),
so the widgets get the same language as before — `intl` simply gets it too. The
application runs the callback on start-up and whenever the system languages
change, before anything below it builds, and each change is logged.

A few things to know:

* Hand over the tear-off as is, not a closure: the application compares the
  callback by identity on every rebuild.
* Do not set `Intl.systemLocale` (`findSystemLocale()`) "for correct
  formatting". It is exactly what makes formatters speak the device's
  language, and once the callback has run `intl` no longer consults it.
* `DateFormat` needs the date symbols of the locale. The `flutter_localizations`
  delegates load them, and `AppLocalizations.localizationsDelegates` already
  includes those; an application without them calls
  `initializeDateFormatting()` itself.
* A widget test builds its own `MaterialApp`. One that checks formatted dates
  or numbers wires the same callback there — or sets `Intl.defaultLocale` in
  `setUp` — otherwise it formats in `en_US`.

## Widgets

```dart
BannerPro(application: application),
```

`BannerPro` marks a non-production build with a corner ribbon carrying the
flavor [name](#flavor). It wraps the whole application — above every route, so
no screen can cover it — and on `FlavorProduction` returns the child as is.

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

```dart
ExpansionTilePro(
  title: title,
  titleStyle: titleStyle,
  icon: chevron,
  isExpanded: isExpanded,
  onToggle: onToggle,
  highlightColor: highlightColor,
  borderRadius: borderRadius,
  duration: duration,
  child: child,
),
```

`ExpansionTilePro` is an expandable row of a list: a title with a chevron
(`icon`, turned half a turn while expanded) and `child` under it. The expanded
state stays with the caller (`isExpanded` + `onToggle`): one list keeps a single
row open, another any number of them. Everything visual is a parameter, so the
row brings no design system of its own. The hover highlight bleeds past the row
horizontally by `highlightBleed` (12 by default), so the title keeps the same
vertical line as the rest of the block: no ancestor may clip those edges (a list
needs `clipBehavior: Clip.none`), and where there is no room outside — a modal,
a column flush against the edge — give the row a padding of the same width. The
tap target is an `EmptyButton`: no ripple, only a keyboard focus ring.

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
  When a tab becomes active, focus the top route of its navigator with
  `focusTopRoute(Navigator.of(context))`, and do it after the frame: until the
  stack rebuilds the tab is still excluded and the request is silently dropped.

  ```dart
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => focusTopRoute(Navigator.of(context)),
  );
  ```

- `unfocus()` (and `UnfocusingTap` with it) leaves the focus alone when it
  already sits on a scope: unfocusing a scope moves the focus one scope up,
  and a tap on the page background would otherwise kill keyboard scrolling.
- A focused `TextField` keeps the keys, as it does in a browser.

`KeyboardShortcutsPro` adds what Flutter does not map: Home/End (also with
Ctrl), Shift+Space, and — on the Apple platforms alone — the keys a browser on
macOS scrolls a page with: Cmd+Up/Down to the ends of the page, Option+Up/Down
by a screen, Option+Left/Right the same horizontally. The last of those needs
the binding the most: `defaultShortcuts` answers with the web map whatever the
host OS is, so Flutter's own Apple map never reaches a browser, and where it
does apply it moves Cmd+arrow by a single line instead. They are bound on the
Apple platforms alone because the same combinations are Alt+arrow elsewhere,
where Alt+Left/Right is the browser's own back/forward; Cmd+Left/Right is left
unbound everywhere, since every browser walks its history with it and a key
the application does not handle goes to the browser.

Its actions also replace the framework's own `ScrollAction` with
`ScrollActionPro`, which is what makes a **held** key usable. The framework
animates every press to the offset the page holds at that moment, and an
animation is a ticker of its own that reports zero elapsed time on its first
tick: with the OS repeating a held key every two or three frames, every other
frame left the page standing still and the next one made the distance up in a
jerk. Here a press moves an *aim* instead, and a single ticker — started with
the first press, stopped once the page has arrived — draws the page after it
with a critically damped pull tuned to the pace of the repeats. Held down, the
page trails the aim by a fixed distance and holds exactly the speed the repeats
ask for; released, it closes that distance and stops, and the distance covered
is always the sum of the presses. Home/End go the same way, aiming at a target
that does not move. The action is enabled only when it has a scrollable of the
intent's axis to move, so a key it cannot use is left to whoever is next.

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
since a `RouteLink` is a real `<a>` element the browser acts on by itself. The
hold outlives the press that ends the mode: the mode ends inside the
`pointerdown`, and the `mousedown` and `auxclick` whose defaults matter come
after it, so a press that begins under the mode is held to its own `auxclick`.
Nothing but the user ends the mode: the wheel, Escape, a click, or the release
of a button that was dragged rather than clicked. The cursor leaving the window
and the window losing the focus leave it on — the aim simply stops being
updated, and the page keeps going the way it was last aimed, as the browser's
own mode does.

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

A `RouteLink` is a real `<a>` element, and the browser leaves its focus on the
element a click landed on. When that element then goes — the card was on the
page the click navigated away from, or a lazy list recycled it — the browser
drops the focus onto the body of the document, outside the Flutter view, and
Flutter parks its own focus on the root scope, where no widget can take a
key: page scrolling, Escape and every other shortcut go dead until the next
click anywhere. `PageFocusKeeper` puts the focus back: it tells this case
from the user leaving for the address bar or another tab (the document still
holds the focus, its body has it) and walks the focus down the chain of
last-focused children onto the top route, the way the next click would have.
Wrap the application in it above everything else, next to `AutoScrollPro`:

```dart
MaterialApp.router(
  builder: (_, child) => PageFocusKeeper(child: AutoScrollPro(child: child!)),
  ...
)
```
