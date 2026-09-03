## 0.3.3

* **`RouteLink`** takes external URLs as well: an `https://…` link gets
  `target="_blank"`, so the browser context menu recognises it and a
  modifier-click opens it in a new tab, while a plain click still goes to
  `onClick`. A path with a query (`/list?kind=category`) is no longer
  percent-encoded into `/list%3Fkind=category` — the router could not match it.

## 0.3.2

* **`EmptyButton`** draws a focus ring for keyboard-driven focus
  (`FocusHighlightMode.traditional`). The overlay colour is transparent by
  design, so the ink well's own focus highlight was invisible and a keyboard
  user tabbing through the page could not see where they were. The ring
  follows the new `focusBorderRadius` (default — a small rounding).
* **`unfocus()`** — and `UnfocusingTap` with it — no longer touches the focus
  when the primary focus already sits on a scope, i.e. a route with no
  focused field. Unfocusing a scope moves the focus one scope up, and on the
  web that killed keyboard scrolling after any tap on the page background:
  Flutter's scroll action looks the scrollable up from the focused node, and
  above the route there is nothing to scroll.
* **`KeyboardShortcutsPro`** — shortcut and action maps for `MaterialApp` that
  add Home/End (also with Ctrl) and Shift+Space page scrolling on top of
  Flutter's defaults; a focused text field keeps the keys.
* **`RouteLink`** — a tap target that is a real link on the web (`url_launcher`
  `Link`): URL on hover, Ctrl/Cmd+click and the middle button into a new tab,
  while a plain click stays with the in-app navigation. A plain `EmptyButton`
  elsewhere.
* README: a **Web** section on keyboard scrolling (`primary: true` on the one
  root scrollable per route, `PrimaryScrollController.none`, tab focus,
  `unfocus()`), links and the browser context menu.

## 0.3.1

* **`UrlLauncher.launchLinkViaLocation`** — navigates the current browser tab
  by assigning `window.location` directly, bypassing `window.open`.
  url_launcher's web implementation always passes the `noopener` window
  feature to `window.open`, and browsers with custom popup handling (Arc and
  alike) treat such a call as a popup request even with the `_self` target —
  the page detaches into a separate window, so a redirect flow (e.g. payment
  confirmation) returns into the wrong tab while the original one keeps
  hanging with stale state. A direct location assignment cannot create a
  browsing context by construction. Meant for web redirect flows leaving for
  another `https` page; `launchLinkInSameTab` stays for links handed over to
  the OS (custom schemes, `intent://`). On non-web platforms behaves as a
  plain default launch.

## 0.3.0

* **`UrlLauncher.launchLinkInSameTab`** — opens a link in the current browser
  tab. Made for the web links whose navigation is handed over to the OS
  (custom application schemes, `intent://`): the page and the application
  state stay in place, popup blockers are not involved and no dead empty tab
  is left behind. Deliberately skips the `canLaunch` check — the web
  implementation of url_launcher reports `false` for any non-standard scheme,
  while such links are exactly what this method exists for. On non-web
  platforms behaves as a plain default launch.

## 0.2.9

* **`ShareService.share` is now safe and returns `Future<bool>`.** When the
  Web Share API is unavailable on web (desktop Firefox, Chromium on Linux,
  insecure HTTP context), share_plus used to open the default mail client with
  the shared text — surprising UX at best, a silent no-op when no mail client
  is configured. That `mailto:` fallback is now disabled, the call never
  throws, and the result tells whether the share sheet was actually presented:
  on `false` the consuming app applies its own fallback (e.g. copy the link to
  the clipboard and show a toast). Dismissing the sheet still counts as `true`
  — the user made a choice, no fallback is due. On web an unavailable share is
  an expected browser state and is not logged; on other platforms the failure
  is logged inside the service, so callers need no try-catch of their own.

## 0.2.8

* **Breaking: the remote error sink now receives the stack trace.**
  `logErrorRemote` (and `LoggerConfigService.errorSink` behind it) changed from
  `void Function({required String error})` to
  `void Function({required String error, StackTrace? stack})`, and `logError`
  gained an optional `stack` that it forwards untouched. The sink used to get
  text only, which left a crash reporter nothing to group by: every reporter
  buckets incoming errors by their frames, so a sink with no trace has to
  synthesise one at the point of reporting and unrelated errors collapse into a
  single issue. `LoggingMixin.logNamedError` takes and forwards `stack` too,
  and the local console printer now shows it. Consuming apps must widen their
  sink signature — adding `StackTrace? stack` to it is the whole migration.

## 0.2.7

* Adds `extraExpectedErrorMap` to `RequestServiceBase.sendBase`, completing the
  per-call escape hatch that 0.2.5 left half-finished. Making
  `RequestType.expectedErrorMap` final was right, but only
  `expectedStatusList` got a way to be widened for a single call, so a service
  that attaches a cross-cutting handler to every request it sends — an
  outdated-client status, for instance — had no route left other than mutating
  the request. Entries passed here win over the request's own for the same
  status.

* Turns the experimental `unsafe_variance` off. It fires on the ordinary shape
  of a generic widget or view model that accepts a callback — a field typed
  `Widget Function(BuildContext, T, int)` puts `T` in a parameter position,
  which is unsound in theory and is what the entire Flutter builder idiom rests
  on in practice. No rewrite both keeps the API and satisfies the rule, so the
  only available response would be to silence it at every occurrence.

## 0.2.6

* **Fixes a regression from 0.2.5: logging configuration written before
  `getIt.init()` was silently discarded.** Moving the four logger globals into
  `LoggerConfigService` put their storage behind the service locator, but every
  consuming app configures logging as one of its first steps — it picks a
  flavor and sets `canLogSensitiveData` — and that runs *before* the container
  is initialised. The facade resolved an unregistered type, wrote nothing, and
  the value fell back to its `isDebug` default. A production flavor started in
  a debug build therefore kept logging request and response bodies after being
  explicitly told not to. The storage now lives in a module-level `LoggerState`
  that the facades read and write directly, so an early write always lands;
  `LoggerConfigService` remains the injectable handle and restores the defaults
  from its dispose hook, which is what keeps the state isolated between tests.

* Turns `specify_nonobvious_local_variable_types` off in the shipped
  `analysis_options.yaml`. Enabling it in 0.2.5 was a judgement made from this
  package's `lib/` alone, where it produced 2 findings; measured against real
  code it produces 73 in this package's own CLI tool and 614 in a consuming app.
  The house style annotates fields and signatures rather than every local, so at
  that volume the rule reports style disagreement and buries the findings that
  matter. Its property-level counterpart stays on — those types are API surface.
  The `ignore_for_file` this had forced into `getit_check.dart` is gone.

* Turns `discarded_futures` off as well, for the same reason and after an
  explicit check. It was enabled in 0.2.5 as "the synchronous half of
  `unawaited_futures`"; that claim does not hold. The pattern it was meant to
  catch — an `async` callback passed to `Map.forEach`, whose future is
  discarded, the very bug fixed in this release — is not reported by it, while
  a forgotten `await` inside an async body is already covered by
  `unawaited_futures`. In practice it flags `.cancel()` / `.close()` in dispose
  methods, Hive `.save()` and navigation calls: 32 hits in a consuming app,
  each a deliberate fire-and-forget in a synchronous function where awaiting is
  not possible. The `unawaited()` wrappers added in 0.2.5 are kept — they read
  as intent — but they are no longer mandatory.

* **BREAKING — adds `FlavorStage` to the `FlavorType` hierarchy.** Projects had
  been redeclaring the whole flavor set locally just to gain a staging variant,
  which left two parallel sealed hierarchies and a second "current flavor"
  holder alongside the package's own. Because `FlavorType` is sealed, any
  exhaustive `switch` over it now has to handle the new case — that surfaces as
  a compile error, so nothing changes silently.

## 0.2.5

* Fixes a false offline mode when the device is behind a VPN.
  `ConnectivityService.isConnectivityAvailable` used to white-list only
  `mobile`/`wifi`/`ethernet`. On iOS and macOS a VPN has no dedicated interface
  type and `connectivity_plus` reports it as `ConnectivityResult.other`, which
  fell outside the white-list — the app switched to offline mode on launch even
  though every request succeeded, then flapped back online on the first `200`.
  Availability is now "any transport other than `none`", which also covers
  `bluetooth` and `satellite`. Actual backend reachability is still decided by
  the ping in `NetworkServiceBase`, so the transport check stays a cheap gate.
* Fixes `ConnectivityService` and `NetworkServiceBase` going permanently deaf
  after a `dispose()`/`prepare()` cycle. Both cancelled their stream
  subscription without clearing the field, while `prepare()` bails out on
  `_subscription != null` — so the second `prepare()` silently did nothing.
  Reachable from `getIt.reset()` in tests and from hot restart.
* `NetworkServiceBase.dispose()` no longer disposes `ConnectivityService`: that
  is a `@lazySingleton` owned by getIt with its own `@disposeMethod`.
* `_deactivateOfflineMode()` now returns early when already online, mirroring
  the guard in `_activateOfflineMode()`. The ping timer is still cancelled
  first, so a stray timer cannot survive.
* **Fixes uploaded files silently going missing.** `_sendPostFormData` attached
  files inside `Map.forEach` with an `async` callback. `forEach` discards the
  futures it gets back, so `request.send()` ran before `MultipartFile.fromPath`
  had finished — the multipart body was sent with some or all files absent.
  Replaced with a sequential `for` loop.
* **Stops leaking error response bodies to the remote logger.**
  `logResponseError` was the only logger in `network_logger_service.dart` that
  appended `response.body` without checking `canLogSensitiveData`, and in
  release `logError` forwards to the remote sink. Error bodies routinely carry
  tokens, emails and an echo of user input.
* `loggerUserId` is now attached to errors in release too. The check sat inside
  the `isDebug` branch, so the id was added only where it was least useful and
  omitted from every remote report.
* Removes a crash-on-launch path in `SecureStorageUtility`. After generating a
  cipher key it re-read the value and force-unwrapped the result; a locked
  keychain or an unavailable Android Keystore turned that into a null-check
  exception. The generated key is now returned directly.
* **BREAKING.** `RequestType.expectedStatusList` and
  `RequestType.expectedErrorMap` are now `final`. To accept extra statuses for
  one call, pass `extraExpectedStatusList` to `RequestServiceBase.sendBase`
  instead of writing into the request — it is a per-call concern, and mutating
  a shared request object as a state flag is what the old callers did.
* **BREAKING — the package had two disagreeing definitions of success.**
  `ResponseEntity.isOk` meant any 2xx, while `RequestType.expectedStatusList`
  defaulted to `[200]` alone, so a `201 Created` from a POST — or a `204` from a
  DELETE — was routed to `NetworkUnexpectedResponse` even though `isOk` called
  the very same reply a success. The default is now an empty list, read as "any
  2xx". A non-empty list keeps its old meaning and is matched exactly, so every
  call site that pins statuses explicitly is unaffected;
  `extraExpectedStatusList` is additive on top of either and never narrows what
  is accepted. `RequestType` no longer imports `dart:io` — the `HttpStatus`
  constants in the defaults were its only use. The stale
  `ResponseEntity.isNotOk` comment ("every code except 200 & 201") is corrected.
* **BREAKING.** `flavor` now throws a `StateError` when read before it was set,
  instead of logging and falling back to `FlavorProduction()`. A forgotten
  `ApplicationBase.prepare` used to point debug builds at the production
  backend and production analytics.
* `RequestServiceBase` now releases its `http.Client`: the `client` setter
  closes the instance it replaces, and a new `dispose()` closes the current one.
  Previously the client and its keep-alive pool lived for the whole process.
* Drops two dead headers from web multipart uploads:
  `Access-Control-Allow-Origin` is a *response* header and does nothing on a
  request, and the manual `Content-Type` is overwritten by `MultipartRequest`
  in `finalize()` with the generated boundary. `Cache-Control` is kept.
* `.fvmrc` is no longer listed in `.gitignore` — it pins the Flutter version and
  is (and must stay) tracked.
* **The shipped `analysis_options.yaml` now covers the complete rule set of the
  pinned SDK.** It was audited against the linter registry of Dart 3.12.2: all
  224 stable and 10 experimental rules are listed, none of the removed or
  deprecated ones are. Rules that stay off are now written out as `false` with
  the reason next to them instead of being absent, so the file answers "why
  isn't this on?" without a trip to the docs. Notable changes:
  * All seven `TODO(Alex): need to dive deeper` markers are resolved.
    `discarded_futures`, `avoid_types_on_closure_parameters` and
    `no_literal_bool_comparisons` are on; `diagnostic_describe_all_properties`,
    `always_put_control_body_on_new_line`,
    `avoid_classes_with_only_static_members` and `omit_local_variable_types`
    stay off with a written rationale.
  * The "Incompatible rules: always_specify_types" notes on
    `avoid_types_on_closure_parameters` and `omit_local_variable_types` were
    stale — `always_specify_types` is disabled, so nothing was blocking them.
  * `no_runtimeType_toString`, `prefer_for_elements_to_map_fromIterable` and
    `prefer_iterable_whereType` were listed under their old camelCase spelling,
    which the analyzer treats as an alias of the canonical lowercase name. The
    duplicates are gone.
  * Experimental rules are now marked `# Experimental`, so the ones outside the
    stability guarantee are visible at a glance.
  * `public_member_api_docs` is enabled. The project rule that every
    declaration carries a `///` comment is now checked by the analyzer instead
    of resting on discipline. Its old note justified the rule being off by
    pointing at `package_api_docs`, which no longer exists in the SDK. Six
    class- and mixin-level comments were missing and have been written.
* **Offline mode now engages on web.** A connection that cannot be made is
  reported by `package:http` as a `ClientException` there, never as a
  `SocketException`, so on web such a failure fell through to the generic catch
  and surfaced as `NetworkUnexpectedError` — nothing crashed, offline mode
  simply never turned on. `sendBase` and `catchRedirect` now handle
  `ClientException` the same way as a lost socket. The `dart:io` import is
  fine on web and the stale "get rid of it?" to-do is replaced by a note
  explaining why: dart2js ships a stub, only the `HttpStatus` integer constants
  and caught exception types are used, and every `Platform` member in
  `platform_service.dart` sits behind a `!isWeb` short-circuit.
* Local console logging is now controlled by `isLocalLoggingEnabled` instead of
  being hard-wired to `isDebug`. A release build still prints nothing by
  default, but the switch can be flipped to investigate an issue on a real
  device. The duplicated web output is gone: the `logger` package writes through
  `print`, so a single call already reaches the browser console and the tooling
  console — the extra `print` was a second write to the same channel, not a
  second destination.
* `logTokenEmptyError` reports through `logError` instead of `logInfo`.
* Removes the force-unwrapped `actualRouter!` from all ten helpers in
  `navigation_service.dart`. A missing router was logged by `actualContext` and
  then immediately crashed on the `!`; navigation is now skipped with an error
  entry instead.
* The four mutable logger globals (`loggerUserId`, `canLogSensitiveData`,
  `logInfoRemote`, `logErrorRemote`) moved into an injectable
  `LoggerConfigService`. They survived `getIt.reset()` and leaked between
  tests. The top-level names are kept as facades, so no call site changes; the
  facades fall back to defaults while the service locator is not yet ready.
* `ConnectionRestoreMixin` no longer stores its subscription in a `late` field:
  calling `disposeConnection()` without a preceding `prepareConnection()` threw
  a `LateInitializationError`. `prepareConnection()` is now idempotent and
  `disposeConnection()` clears the field so a later prepare can re-subscribe.
* `AccessVM` now implements `ValueListenable<bool>`, so screens can consume it
  through a `ValueListenableBuilder` like the rest of the project's state. It
  stays a `ChangeNotifier` on purpose — `auto_route` takes the instance as
  `reevaluateListenable`, and `needNotify: false` has to be able to update the
  flag without waking the router, which a plain `ValueNotifier` cannot do.
  Repeated writes of the same value no longer notify.
* **BREAKING.** `currentPlatform` returns `AvailablePlatform?` and yields `null`
  on an unrecognised host instead of silently answering `android`.
* `SafeService` renames its generic parameter from `Type` to `T`, which stopped
  it shadowing the built-in `Type` and removed both
  `// ignore: avoid_types_as_parameter_names` suppressions.
* Adds a GitHub Actions workflow: dependencies, a check that the committed
  generated sources match a fresh `build_runner` run, `dart format`,
  `flutter analyze --fatal-infos` and `getit_check`. It could not exist before
  — `.gitignore` excluded the whole `.github` directory, so no workflow could
  be committed.
* Fixes the code that the newly enabled rules flagged: intentional
  fire-and-forget calls in `StorageService`, `ConnectivityService`,
  `NetworkSubject`, `LifecycleService` and `NetworkServiceBase` are wrapped in
  `unawaited()`, non-obvious property and local types are annotated, redundant
  closure parameter types and an `async` without `await` are dropped.

## 0.2.4

* Updates minimum supported SDK version to Flutter 3.44.4/Dart 3.12.2.
* Updates all packages to actual versions. Key upgrades and migration notes:
  * **injectable 2.7 → 3.0 / injectable_generator 2.12 → 3.1.** The removed
    `includeMicroPackages` and `usesNullSafety` options are gone — micro-packages
    are wired explicitly through `externalPackageModulesBefore` /
    `externalPackageModulesAfter` (already how this package is consumed, so no
    change on the consumer side). The regenerated `service_locator.module.dart`
    no longer carries the leading `//@GeneratedMicroModule` marker comment (it
    belonged to the old discovery mechanism). injectable_generator now caps
    `analyzer` at `<14.0.0` and requires Dart `>=3.12.0`; a new
    `allowMultipleRegistrations` flag is available.
  * **analyzer 9 → 13.** Major AST restructuring for primary-constructor
    support: `ClassDeclaration.name` → `namePart.typeName`,
    `ClassDeclaration.members` → `body.members`, and `NamedExpression` →
    `NamedArgument` (`.name.label.name` → `.name.lexeme`, `.expression` →
    `.argumentExpression`). The `getit_check` executable was migrated to the new
    API. Pinned to `^13.0.0` because injectable_generator does not yet allow
    analyzer 14.
  * **build_runner 2.10 → 2.15.** Builders are now AOT-compiled and the
    `--delete-conflicting-outputs` flag was removed (its behaviour is the default
    now), so the build command is simply `dart run build_runner build`.
  * **share_plus 12 → 13.** Breaking only in platform/dependency requirements
    (Flutter ≥ 3.41.6, Dart ≥ 3.11, win32 6.x); the
    `SharePlus.instance.share(ShareParams(...))` API is unchanged.
  * Minor bumps: connectivity_plus 7.0 → 7.2, cross_file 0.3.5+2 → 0.3.5+4,
    flutter_secure_storage 10.0 → 10.3, get_it 9.2.0 → 9.2.1,
    hive_ce 2.19.1 → 2.19.3, logger 2.6 → 2.7, meta 1.17 → 1.18,
    url_launcher_android 6.3.30 → 6.3.32.
* Dropped the deprecated/removed `avoid_null_checks_in_equality_operators`,
  `prefer_bool_in_asserts`, `prefer_final_parameters` and
  `use_if_null_to_convert_nulls_to_bools` rules from the shipped
  `analysis_options.yaml`.

## 0.2.3

* **BREAKING — DI moved to injectable.** The package now registers its own
  services through an injectable micro-package module
  (`ApplicationBasePackageModule` in `service_locator.module.dart`) instead of
  the manual `ServiceLocatorBase.prepare()` (class removed). Consumers wire it
  via `externalPackageModulesBefore: [ExternalModule(ApplicationBasePackageModule)]`
  in their `@InjectableInit`. `ApplicationBase.prepare()` no longer registers
  dependencies — it is now a post-DI step (flavor + `LifecycleService.prepare()`)
  and must be called AFTER the consumer's `getIt.init()`.
* `NavigationServicePro` — injectable facade over the `navigation_service.dart`
  helpers (`push` / `replace` / `replaceAll` / `navigate` / `pop` / `popForced`
  / `popUntilRouteName` / `currentRouteName`) so view models depend on a
  contract instead of the global-`navigatorKey` functions and navigation
  branches can be tested with a recording fake. Contract lives in
  `navigation_service_pro.dart`, the `NavigationServiceRouter` implementation in
  `navigation_service_router.dart`. Registered by the package's injectable
  module as `@LazySingleton(as: NavigationServicePro)`.
* `UrlLauncherPro` — injectable facade over the static `UrlLauncher` (`open` /
  `sendEmail` / `call` / `sendSms`) for the same testability reason. Contract
  lives in `url_launcher_pro.dart`, the `UrlLauncherRouter` implementation in
  `url_launcher_router.dart`. Registered by the package's injectable module as
  `@LazySingleton(as: UrlLauncherPro)`.

## 0.2.2

* `catchRedirect` now in try/catch with the same behaviour as a base sender.
* `getit_check` cleared from warnings.

## 0.2.1

* `getit_check` executable added — static analyzer that scans `lib/` of the
  consuming project, finds classes registered via `injectable` annotations
  (`@lazySingleton` / `@singleton` / `@injectable` and their constructor forms
  `@LazySingleton(as: X)`, ...), collects every `getIt<T>()` call inside them
  and reports cyclic dependencies ranked by severity (eager vs lazy edges).
  Run from your project root: `dart run application_base:getit_check`
  (add `--verbose` to dump every registered class with its outgoing edges).

## 0.2.0

* Offline mode now confirms backend reachability before switching back online
  after connectivity returns, with serialized ping checks and restore logs.
* New `NetworkConnectionAvailable` network event added - network interface 
  is available, but backend availability is not confirmed.

## 0.1.9

* `NetworkRequestTimeout` removed — request timeouts are now treated as a
  loss of connection and emit `NetworkConnectionLost` directly. This lets
  the offline mode activate even for silent/background requests without an
  extra reachability check.
* `NetworkServiceBase`: removed timeout-triggered ping fallback that became
  redundant after the change above.

## 0.1.8

* `RequestServiceBase`: request timeouts (`shortTimeout`, `normalTimeout`,
  `longTimeout`) are now overridable getters on the base class itself.
  `RequestTimeoutService` removed — subclasses can tune timeouts directly.
* `RequestServiceBase`: any `SocketException` (including DNS lookup failures
  while Wi-Fi reports as connected) now emits `NetworkConnectionLost` so the
  offline mode is activated automatically.
* `NetworkServiceBase`: on `NetworkRequestTimeout` performs a short reachability
  ping and activates the offline mode if it fails — covers iOS where blocked
  DNS surfaces as a timeout instead of a socket exception.
* `NetworkServiceBase`: background ping period is now configurable via the
  overridable `pingPeriod` getter. Default value bumped to 30 seconds.

## 0.1.7

* **previousState** added to **LifecycleService**
* Double "Request" in network logger fixed

## 0.1.6

* Updates minimum supported SDK version to Flutter 3.38.7/Dart 3.10.7
* Updates all packages to actual versions
* **catchRedirect** added
* **sendEmail** improved
* **OpacityPro** added
* **EnabledPro** added
* **StringExtension** added with two functions: **asUri** and **capitalized**

## 0.1.5

* **currentRouteName** added
* **navigatePath** added
* **popTopScreen** added

## 0.1.4

* Navigate functions fixes and improvements
  * root router changed to actual context router to provide right behaviour
  * **AuthenticationGuard -> onNavigation** reworked
  * **AccessVM** improvement and simplified - it's fully automatically now

* Breaking changes:
  * **router** changed to **actualRouter**
  * **router** removed from **ApplicationBase -> prepare**
  * **openDefaultScreen** removed
  * **needNotify** parameter removed from **AccessVM -> revokeAccess**

## 0.1.3

* Updates minimum supported SDK version to Flutter 3.35.4/Dart 3.9.2
* Updates all packages to actual versions
* Package versions store rebased from refs to tags
* **logImportant** and **logNamedImportant** functions added

## 0.1.2

* **RequestPostFile** added to uploading file as binary data using octet-stream
(tested only for Android and iOS for now)

## 0.1.1

Breaking changes:

* **logSensitive** renamed to **canLogSensitiveData** and improved
* **RequestPostWithFiles** renamed to **RequestPostFormData** and improved

## 0.1.0

* **ShareService** based on [share_plus](https://pub.dev/packages/share_plus)
* Some unified widgets added
  * EmptyButton
  * UnfocusingTap

## 0.0.9

* Updates minimum supported SDK version to Flutter 3.32.2/Dart 3.8.1
* Updates all packages to actual versions

## 0.0.8

* **PATCH** request type added
* Success response HTTP status code is now from 200 to 300, not only 200 and 201

## 0.0.7

* **StorageService** based on 
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) 
and [hive_ce](https://pub.dev/packages/hive_ce)
* **UrlLauncher** based on [url_launcher](https://pub.dev/packages/url_launcher)
* **LoggingMixin** added

## 0.0.6

* Updates minimum supported SDK version to Flutter 3.24.5/Dart 3.5.4
* Updates dependencies

## 0.0.5

* Response + RawDataEntity = **ResponseEntity**
* **NetworkCustomEvent** added

## 0.0.4

* **LifecycleService** is now with **AppLifecycleState** listener
* **RequestPostWithFile** is now web-compatible but requires XFile instead of 
local file path
* In **RequestServiceBase** added parameter **logSensitive** to send or not to
send sensitive data in logger (instead of private **_sendSensitive** parameter)
* **onUnauthorized** -> **notifyUnauthorized**
* Logger events in debug mode won't be sent to remote logger anymore
* Error in response will be logged in remote logger with response body despite
**logSensitive** parameter
* Network logger functions cleared
* **ConnectionRestoreMixin** migrated from Presentation layer to Domain

## 0.0.3

* Updates dependencies

## 0.0.2

* API interaction based on [http](https://pub.dev/packages/http)
* Online / offline state change checker

## 0.0.1

* **Analysis options**
* **Flavors**
* **GetIt** based on [get_it](https://pub.dev/packages/get_it)
* **Logger** based on [Logger](https://pub.dev/packages/logger)
* **Navigation utilities** based on [AutoRoute](https://pub.dev/packages/auto_route)