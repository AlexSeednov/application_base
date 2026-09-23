[English](README.md) | **Русский**

Единая основа для Flutter-приложений на базе
[особой архитектуры](https://miro.com/app/board/uXjVNJVBM3o=/?share_link_id=771428578014)

## Возможности

Пока включает:
* [Параметры анализа](#параметры-анализа)
* [Флейвор](#флейвор)
* [GetIt](#getit)
* [Логгер](#логгер)
* [Утилиты навигации](#утилиты-навигации)
* [Взаимодействие с API](#взаимодействие-с-api)
* [Отслеживание смены состояния онлайн / офлайн](#отслеживание-смены-состояния-онлайн--офлайн)
* [Отслеживание смены состояния жизненного цикла приложения](#отслеживание-смены-состояния-жизненного-цикла-приложения)
* [StorageService](#сервис-локального-хранилища)
* [Открытие ссылок](#открытие-ссылок)
* [Поделиться](#поделиться)
* [Тактильная отдача](#тактильная-отдача)
* [Буфер обмена](#буфер-обмена)
* [Страница в магазине приложений](#страница-в-магазине-приложений)
* [Идентификаторы](#идентификаторы)
* [Локаль приложения](#локаль-приложения)
* [Несколько полезных виджетов](#виджеты)
* [Веб](#веб)

## Поддерживаемые платформы

* Android
* iOS
* Linux — пока не протестирован
* MacOS — пока не протестирован
* Web
* Windows — пока не протестирован

## Требования

Основаны на минимальных требованиях всех используемых пакетов.

[Информация](https://docs.flutter.dev/release/archive) о совместимости версий
Flutter и Dart

* Flutter >=3.44.4
* Dart >=3.12.2
* iOS >=13.0 — url_launcher_ios ^6.3.5
* MacOS >=10.15 — url_launcher_macos ^3.2.4
* Android compileSDK 36 — Flutter ^3.35.0
* Java 17 — connectivity_plus ^6.0.1
* Android Gradle Plugin >=8.12.1 — connectivity_plus ^7.0.0
* Gradle wrapper >=8.13 — connectivity_plus ^7.0.0
* Kotlin >=2.2.0 — connectivity_plus ^7.0.0

## Журнал изменений

Все заметки о выпусках собраны в
[журнале изменений](https://github.com/AlexSeednov/application_base/blob/main/CHANGELOG.md)

## Использование

Добавьте в pubspec.yaml своего пакета строку вроде этой (и выполните неявный
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

Пакет регистрирует свои сервисы через модуль микропакета injectable.
Подключите его к своему сервис-локатору, добавив модуль в ваш `@InjectableInit`:

```dart
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/core/service/service_locator.module.dart';

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(ApplicationBasePackageModule)],
)
Future<void> configureDependencies() => getIt.init();
```

Когда подключены внешние модули пакетов, `getIt.init()` становится
асинхронным, поэтому при запуске его нужно **дождаться** (`await`). После этого
вызовите `ApplicationBase.prepare();` — он выполняет шаг после DI (флейвор +
жизненный цикл) и обращается к `getIt<LifecycleService>()`, поэтому должен
запускаться ПОСЛЕ того, как `getIt.init()` завершился.

Важно: не забудьте вызвать `WidgetsFlutterBinding.ensureInitialized();`
перед подготовкой.

## Параметры анализа

Создайте файл `analysis_options.yaml` в корне пакета (рядом с файлом
`pubspec.yaml`) и подключите в нём
`include: package:application_base/analysis_options.yaml`.

Пример файла `analysis_options.yaml`:

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

## Флейвор

Заранее созданные флейворы `Development`, `Stage` и `Production` с публичным
геттером `flavor`. У каждого флейвора есть короткое имя `name` (`Dev` / `Stage` /
`Prod`), которое используют логгер и [`BannerPro`](#виджеты), — короткое, потому
что лента баннера узкая и обрезает длинное слово.

Его можно задать прямо при подготовке пакета:

```dart
import 'package:application_base/application_base.dart';
import 'package:application_base/core/const/flavor_type.dart';

ApplicationBase.prepare(currentFlavor: FlavorDevelopment());
```

или в любом нужном месте через сеттер:

```dart
import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';

flavor = FlavorDevelopment();
```

Примечание: настоятельно не рекомендуется менять флейвор во время работы
приложения. Просто задайте его один раз при запуске приложения.

## GetIt

Основан на [get_it](https://pub.dev/packages/get_it)

### Сервисы пакета

Пакет регистрирует собственные сервисы через модуль микропакета injectable
(`ApplicationBasePackageModule`, генерируется в `service_locator.module.dart`;
как его подключить — см. [Использование](#использование)). Каждый сервис —
синглтон, которым владеет getIt: класс помечается `@lazySingleton` или, чтобы
привязать контракт к его реализации, `@LazySingleton(as: Contract)`.
Зависимости передаются через конструктор (constructor injection), который
помечен `@visibleForTesting`, чтобы вне тестов нельзя было создать второй
экземпляр. Владение устроено одинаково для всех, поэтому отдельные классы это
примечание не повторяют.

1. Зарегистрируйте сервис аннотацией injectable — саму регистрацию
генерирует `build_runner`, вручную её не пишут:

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

2. И используйте его:

```dart
import 'package:application_base/core/service/service_locator.dart';

getIt<AwesomeService>().makeMagic();
```

3. Проверка циклических зависимостей getIt — `getit_check`:

`getit_check` — статический анализатор, который поставляется вместе с пакетом
как исполняемый файл. Он сканирует `lib/` вашего проекта, находит классы,
зарегистрированные через аннотации `injectable` (`@lazySingleton`, `@singleton`,
`@injectable` и их конструкторные формы `@LazySingleton(as: X)`,
`@Singleton(as: X)`, `@Injectable(as: X)`), собирает все вызовы `getIt<T>()`
внутри них, строит ориентированный граф и сообщает о циклических зависимостях,
ранжируя их по серьёзности.

Запускайте из корня проекта:

```bash
dart run application_base:getit_check
dart run application_base:getit_check --verbose   # dump every registered class
                                                  # and its outgoing edges
dart run application_base:getit_check --no-color  # disable ANSI colors
dart run application_base:getit_check --ascii     # ASCII-only glyphs (for
                                                  # terminals without UTF-8)
```

Отчёт сгруппирован по серьёзности (сначала HIGH, затем LOW), каждый цикл
нарисован лесенкой с цветными стрелками `eager` / `lazy`, к каждому циклу
прилагается однострочная подсказка по исправлению, а классы, которые участвуют
в двух и более циклах, помечены `[hot: N cycles]`, чтобы главные нарушители
сразу бросались в глаза. Итоговая рамка в конце показывает общие цифры с одного
взгляда. Цвета автоматически отключаются, если stdout — не TTY, и учитывают
переменную окружения `NO_COLOR`.

Классификация рёбер:

* **eager** — `getIt<X>()` вызывается во время конструирования (инициализатор
  поля, тело конструктора или список инициализации конструктора). Цикл
  **хотя бы с одним eager-ребром** = гарантированное переполнение стека в тот
  момент, когда создаётся первый участник.
* **lazy** — `getIt<X>()` вызывается только из тела метода/геттера/сеттера
  (или из инициализатора статического поля, который выполняется при первом
  обращении). Цикл только из lazy-рёбер всё равно подозрителен, но стреляет
  лишь тогда, когда вызовы случайно пересекутся по времени.

Кроме того, инструмент отмечает дублирующиеся регистрации (несколько классов
претендуют на одно и то же имя в `getIt`) и сообщает об ошибках разбора по
каждому файлу. Код выхода — `0` на чистом графе, `1`, если найдены циклы, и `2`,
если не удалось найти `lib/`, — так что его можно использовать как проверку
в CI:

```bash
dart run application_base:getit_check || exit 1
```

Ограничения: вызовы `getIt<T>()` внутри миксинов не приписываются классам,
которые подключают эти миксины через `with`; анализ чисто статический, поэтому
каждый `getIt<T>()`, найденный в AST, считается потенциальной зависимостью
независимо от потока управления.

## Логгер

Основан на [Logger](https://pub.dev/packages/logger)

Для логирования в удалённые системы (Crashlytics, Sentry или что-то ещё)
просто задайте `logInfoRemote` и `logErrorRemote`:

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

Обработчик ошибок получает стек-трейс отдельным аргументом: сервисы отчётов
группируют ошибки по фреймам, поэтому обработчику, которому достаётся только
текст, пришлось бы синтезировать трейс в месте отправки и сваливать несвязанные
ошибки в одну группу.

Для локального логирования ошибок можно задать User ID:

```dart
///
void setUser() {
    /// Set user in logger
    loggerUserId = userId;
}
```

И используйте логгер везде, где нужно

```dart
logInfo(info: 'Interesting information');
logError(error: 'Some error happened');
logError(error: 'Some error happened', stack: stackTrace);
```

Также есть **LoggingMixin** — для удобных именованных логов в классах. Просто
подмешайте его и используйте:

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

## Утилиты навигации

Основаны на [AutoRoute](https://pub.dev/packages/auto_route)

При подготовке приложения нужно создать `RootStackRouter` на основе
`navigatorKey`:

1. Создайте экземпляр роутера

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

2. Также можно создать `routerConfig` с готовыми `Access checker` и
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

и использовать его как `routerConfig` приложения

```dart
MaterialApp.router(
    /// ...
    routerConfig: routerConfig,
    /// ...
)
```

Теперь популярные функции навигации можно вызывать прямо из
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

Также есть отдельная функция для снятия фокуса и геттеры для ключа
навигатора, актуальных контекста и роутера и имени текущего экрана:

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

Каждая смена экрана и вкладки автоматически логируется через `NavigatorObserverPro`

Навигатор автоматически проверяет доступность экранов через `AuthenticationGuard`
и `AccessVM`. Для этого нужно создать `AuthenticationGuard` и добавить его
в `routes`:

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

Теперь доступ можно **выдать** или **отозвать** в любой момент:

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

### NavigationServicePro (injectable-фасад)

Функции верхнего уровня, описанные выше, читают глобальный `navigatorKey`,
и это привязывает любую VM, которая их вызывает, к смонтированному роутеру.
Чтобы навигацию можно было тестировать, берите зависимостью контракт
`NavigationServicePro`: в тестах регистрируйте записывающий фейк и проверяйте
ветки навигации без прогона дерева виджетов через pump.

Контракт (`push` / `replace` / `replaceAll` / `navigate` / `pop` /
`popForced` / `popUntilRouteName` / `currentRouteName`) находится в
`navigation_service_pro.dart`, реализация `NavigationServiceRouter` — в
`navigation_service_router.dart`. Реализация помечена
`@LazySingleton(as: NavigationServicePro)`, поэтому её регистрирует
`ApplicationBasePackageModule` вместе с остальными сервисами пакета; то же
относится к `UrlLauncherRouter` за контрактом
[`UrlLauncherPro`](#открытие-ссылок). Если модуль подключён, как описано
в [Использовании](#использование), привязывать ничего не нужно: **не
регистрируйте их повторно** в DI своего проекта — getIt отвергает вторую
регистрацию того же типа. Берите контракт через конструктор injectable-класса
или из `getIt<NavigationServicePro>()`:

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

## Взаимодействие с API

На базе [http](https://pub.dev/packages/http). У приложения один сервис
запросов — синглтон-наследник `RequestServiceBase`, и каждое обращение к
бэкенду идёт через него:

```text
typed request → sendBase → ResponseEntity → Entity.parse → null on error
```

### Сервис запросов

Приложение один раз наследует `RequestServiceBase`. Обязательно задать только
`prepareUri` — как путь превращается в адрес. Заголовки (токены и прочее) —
тоже его забота: они передаются в `sendBase` при каждом вызове.

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

`@disposeMethod` на переопределении обязателен: базовый класс абстрактный и
сам не зарегистрирован, поэтому закрыть при сбросе getIt HTTP-клиент вместе с
его keep-alive соединениями может только регистрация конкретного наследника.
Таймауты — геттеры: `shortTimeout` (3 с), `normalTimeout` (20 с),
`longTimeout` (30 с); переопределите те, что не подходят. Сеттер `client`
подменяет HTTP-клиент (например, обёрткой, которая перехватывает статус у
каждого запроса) и закрывает прежний.

### Запросы

Запрос — это значение, описывающее один вызов: `RequestGet`, `RequestPost`,
`RequestPut`, `RequestPatch`, `RequestDelete` и две загрузки —
`RequestPostFormData` (поля multipart плюс файлы `XFile`) и `RequestPostFile`
(один файл потоком как `application/octet-stream`). `path` — часть адреса после
базовой, тело — готовая JSON-строка:

```dart
final ResponseEntity? response = await getIt<RequestService>().send(
  RequestPost(
    path: 'projects',
    body: jsonEncode(project.toJson()),
    expectedErrorMap: {HttpStatus.conflict: NetworkCustomEvent(data: 'duplicate')},
  ),
);
```

Что запрос может сообщить о себе:

* `expectedStatusList` — по умолчанию пуст, и тогда успех — любой 2xx.
  Заполняйте его, только когда смысл несёт конкретный статус, например чтобы
  самому обработать `404`; непустой список сверяется точно.
* `expectedErrorMap` — `статус → NetworkEvent`: событие, которым сообщается о
  сбое вместо общего `NetworkUnexpectedResponse`. Событие может нести `data` —
  например, какое из нескольких сообщений показать.
* `silence` — запрос не сообщает ни об успехе, ни об ошибках: фоновый пинг,
  предзагрузка, сбой которой пользователю видеть незачем. То, что касается
  всего приложения, всё равно уходит — потеря связи, `401`.
* `durationType` — `short` / `normal` / `long`, с каким таймаутом идёт запрос.
  По умолчанию `normal`, а у двух загрузок — `long`: загрузка и есть тот самый
  тяжёлый запрос, ради которого существует `longTimeout`.

### Результат

`sendBase` никогда не бросает исключений. Он возвращает `ResponseEntity`
(`body`, `statusCode`, `isOk` и `request` для логов), если статус ожидаемый, и
`null` в остальных случаях. К этому моменту о сбое уже сообщено в
`NetworkSubject`, поэтому вызывающая сторона не показывает своей ошибки, а
просто возвращает собственное «нет результата»:

| Что случилось | Событие |
| --- | --- |
| ожидаемый статус | `NetworkSuccess` |
| `401` | `NetworkUnauthorized` |
| `504`, таймаут, нет сокета, сбой SSL-рукопожатия, `ClientException` в вебе | `NetworkConnectionLost` |
| статус из `expectedErrorMap` | это событие |
| любой другой статус | `NetworkUnexpectedResponse` |
| любое другое исключение | `NetworkUnexpectedError` |

Два параметра `sendBase` расширяют один вызов, не трогая сам запрос:

* `extraExpectedStatusList` — принять в этот раз дополнительные статусы:
  например, `401`, на который сервис хочет ответить обновлением токена, а не
  общей обработкой. Он только добавляет.
* `extraExpectedErrorMap` — обработчик, который получает каждый запрос
  сервиса без объявления в каждом месте вызова (например, статус «устаревшая
  версия клиента»). Для одного и того же статуса он побеждает запись самого
  запроса.

`catchRedirect(uri:, headers:)` возвращает `Location` редиректа, не переходя
по нему, — `null`, если редиректа нет или вызов не удался.

### Разбор ответа

`SafeService` превращает тело ответа в сущности и не выпускает наружу
исключение из-за битых данных:

```dart
static ProjectEntity? parse(ResponseEntity data) =>
    SafeService.parse<ProjectEntity>(data, ProjectEntity.fromJson);

static List<ProjectEntity> parseList(ResponseEntity data) =>
    SafeService.parseList<ProjectEntity>(data, ProjectEntity.fromJson);
```

`parse` возвращает `null` на пустом или битом теле. `parseList` возвращает
пустой список, если тело не список, и пропускает отдельный элемент, который не
разобрался, — одна плохая запись стоит только себя, а не всей страницы. Каждый
сбой пишется в лог.

В лог попадают и все запросы с ответами: метод и путь, статус, а тела — только
пока включён `canLogSensitiveData` (по умолчанию — только в debug-сборках).

## Отслеживание смены состояния онлайн / офлайн

Есть ли у приложения связь, решается по двум источникам: сетевому интерфейсу
(`connectivity_plus`) и самому бэкенду. Связь, о которой сообщает система,
ничего не доказывает — Wi-Fi без интернета, captive portal, упавший бэкенд, —
поэтому последнее слово за бэкендом: офлайн-режим включается, когда запросы
перестают до него доходить, и выключается, когда какой-то снова проходит.

### Сетевой сервис

Приложение один раз наследует `NetworkServiceBase` и объясняет ему, как
пинговать бэкенд. Этот же класс — единственное место, которое реагирует на
события всех запросов:

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

Вызовите `prepare()` один раз на старте, когда сервис запросов готов: он
подписывается на `NetworkSubject`, начинает следить за интерфейсом и один раз
пингует бэкенд. Дальше:

* **Офлайн** наступает с `NetworkConnectionLost`: интерфейс сообщает, что связи
  нет (пропавшая связь перепроверяется через 3 с — сразу после переподключения
  iOS ненадолго сообщает, что её нет), запрос не дошёл до бэкенда (таймаут, нет
  сокета, SSL, `504`) или не удался пинг на старте.
* **В офлайне** сервис пингует каждые `pingPeriod` (по умолчанию 30 с;
  переопределите геттер) и сразу, как только интерфейс снова сообщает о связи.
* **Онлайн** возвращается с первым успешным пингом или с любым запросом,
  получившим ожидаемый ответ; тогда всем слушателям уходит `NetworkRestore`.
  Тихий запрос ни о чём не сообщает, поэтому не считается.

`isOnlineNotifier` (`ValueNotifier<bool>`) доносит состояние до UI — плашка
офлайна, недоступные действия, — рядом с ним `isOnline` / `isOffline`, а
`isWiFi` нужен для выбора вроде «скачивать только по Wi-Fi». `LifecycleService`
перечитывает интерфейс каждый раз, когда приложение возвращается на передний
план: начиная с Android 8.0 фоновое приложение не получает изменений связи.

### Перезагрузка после восстановления связи

Экран, данные которого не загрузились в офлайне, перезагружает их, когда связь
вернулась, — через `ConnectionRestoreMixin`:

```dart
final class ProjectListVM with ConnectionRestoreMixin {
  void init() => prepareConnection();

  Future<void> dispose() => disposeConnection();

  @override
  void onConnectionRestore() => unawaited(refresh());
}
```

Оба вызова можно безопасно повторять: `prepareConnection` сохраняет уже
имеющуюся подписку, а `disposeConnection` работает, даже если
`prepareConnection` так и не вызывался. Всё остальное может слушать
`NetworkSubject` напрямую — `listen` для всех событий, `listenConnectionRestore`
только для восстановления.

## Отслеживание смены состояния жизненного цикла приложения

Реализовано через синглтон `LifecycleService`.

```dart
  /// Create onUpdate function
  void onUpdate(AppLifecycleState state){
    /// Do some stuff
  }

  /// And subscribe to changes
  getIt<LifecycleService>().listen(onUpdate);
```

## Сервис локального хранилища

Синглтон, зарегистрированный в getIt, на основе
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
и [hive_ce](https://pub.dev/packages/hive_ce)

Добавьте зависимости в `pubspec.yaml`

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

`hive_ce_generator` 1.11.2 пока ограничивает `analyzer` версией `^12.0.0`, а
этот пакет требует `^13.0.0`. Пока генератор не догонит, приложение
разрешает эту пару через `dependency_overrides` для `analyzer` — генераторы
работают только при сборке, так что сгенерированный код достаточно один раз
проверить.

Сгенерируйте все адаптеры (подробнее —
[здесь](https://pub.dev/packages/hive_ce#store-objects))
и подготовьте **StorageService**

```dart
await getIt<StorageService>().prepare(
  cipherKey: 'secret key',
  registerAdapters: hive.registerAdapters, // Generated by Hive CE Generator
);
```

## Открытие ссылок

Статические хелперы — попытаться открыть ссылку и отправить письмо — на основе
[url_launcher](https://pub.dev/packages/url_launcher); каждый возвращает,
удалось ли действие:

```dart
final bool linkResult = await UrlLauncher.launchLink('https://link');
final bool emailResult = await UrlLauncher.sendEmail(
      to: 'smth@email.com',
      title: 'Awesome email',
      body: 'Strong email body!',
    );
```

`makeCall` и `sendSms` открывают приложения телефона и сообщений; в вебе
`launchLinkInSameTab` и `launchLinkViaLocation` открывают ссылку в текущей
вкладке браузера, а не в новой.

Чтобы открытие ссылок из VM можно было тестировать, используйте вместо
статического `UrlLauncher` контракт `UrlLauncherPro` (`open` / `sendEmail` /
`call` / `sendSms`) с его реализацией `UrlLauncherRouter`. Его регистрирует
модуль пакета — берите его из getIt или через конструктор, как и
[NavigationServicePro](#navigationservicepro-injectable-фасад).

## Поделиться

**ShareService** на основе [share_plus](https://pub.dev/packages/share_plus)

```dart
await ShareService.share(text: text);
```

## Тактильная отдача

**HapticService** — тактильная отдача поверх собственного `HapticFeedback`
из Flutter, с небольшим смысловым словарём вместо голых уровней силы вибрации:
вызывающий код говорит, что произошло, а ощущение «выбор сдвинулся», «действие
сработало» или «не вышло» остаётся одинаковым во всём приложении.

```dart
final HapticService _haptic;      // constructor-injected into a view model

unawaited(_haptic.selection());   // a choice moving under the finger
unawaited(_haptic.lightImpact()); // a small action landing
unawaited(_haptic.mediumImpact());// a mode changing
unawaited(_haptic.longPress());   // a context menu picking up (iOS only)
unawaited(_haptic.success());     // a job coming good  — two rising beats
unawaited(_haptic.failure());     // something refused  — three flat beats
```

Сигнал — это отклик на то, что пользователь уже видит, а не самостоятельное
сообщение; привязывайте его к видимому изменению, а не к ветке кода, которая
это изменение вызвала. Восстановление сохранённого состояния при открытии —
не жест, оставьте его без отклика. Почувствуется ли вообще хоть что-нибудь —
решает система: обе мобильные платформы учитывают собственный переключатель
тактильной отдачи, поэтому приложению своя настройка не нужна.

`longPress()` работает только на iOS намеренно: на Android ink-эффект Material
уже сам запускает платформенный отклик долгого нажатия, и второй поверх него
даёт двойной.

Вызывающий код получает именно контракт, поэтому тест может передать VM фейк
и проверить, какие сигналы та запросила. Платформа без канала тактильной отдачи
(десктоп, веб) запоминается после первого отказа и больше не опрашивается —
иначе такой частый сигнал, как `selection()`, писал бы строку в лог на каждый
шаг перетаскивания.

## Буфер обмена

**ClipboardService** — системный буфер обмена с тактильным сигналом на каждое
копирование: скопированный текст сам по себе никак визуально не откликается,
поэтому нажатие должно ощущаться.

```dart
await ClipboardService.set('text to copy');
final String text = await ClipboardService.get();
```

## Страница в магазине приложений

**StoreService** — открывает страницу приложения в магазине. Одно место для
любой причины отправить туда пользователя — оценить приложение, установить
обновление, которого теперь требует бэкенд, — потому что это одна и та же
страница. Идентификатор приложения в магазине передаётся один раз при старте,
так что нажатию не нужно ничего нести с собой:

```dart
getIt<StoreService>().appStoreId = '1234567890'; // Apple platforms only

// the control is shown only where there is a store to open
if (getIt<StoreService>().isAvailable) ...

await getIt<StoreService>().openListing();
```

На Android, iOS и macOS есть магазин, который плагин умеет открыть; на всех
остальных платформах `isAvailable` равно `false`, а `openListing()` ничего не
делает, так что приложение скрывает элемент управления, а не показывает тот,
что никуда не ведёт. На платформах Apple страницу не найти без `appStoreId` —
если его нет, это логируется как ошибка, а не выбрасывает исключение.

Встроенное окно оценки намеренно не используется. Система показывает его по
своему усмотрению и вообще ничего не делает, если пользователь уже оценил
приложение или квота платформы исчерпана, — при этом `isAvailable()` плагина
продолжает отвечать true, так что приложение не может отличить показанное окно
от проглоченного. Нажатие на явный элемент «Оцените нас» должно каждый раз
куда-то приводить, а так работает только страница в магазине.

## Идентификаторы

**UuidPro** — случайные идентификаторы (v4), которые приложение хранит вместе
со своими записями:

```dart
final String uid = UuidPro.get();
```

Один генератор на всё приложение: `Uuid` содержит собственный генератор
случайных чисел, и создавать новый на каждый идентификатор — чистое
расточительство.

## Локаль приложения

**ApplicationLocale** — заставляет `intl` форматировать даты и числа на языке
интерфейса. Подключите его один раз, в корневое приложение:

```dart
MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: ApplicationLocale.resolve,
  // ...
)
```

Без него `DateFormat` и `NumberFormat` берут локаль устройства, а не
приложения: приложение только на русском на телефоне с английским языком
показывает текст по-русски, а месяцы, дни недели и десятичные разделители —
по-английски. Обычная заплатка — локаль, зашитая в каждый вызов форматтера,
`DateFormat('d MMMM', 'ru')`, — прячет баг, и её приходится переделывать
с каждым добавленным языком. С подключённым колбэком форматтеру не нужен
аргумент локали:

```dart
DateFormat('d MMMM').format(date); // «5 марта» in a Russian application
NumberFormat.decimalPattern().format(1.5); // «1,5»
```

Локаль выбирается собственным алгоритмом Flutter (`basicLocaleListResolution`),
так что виджеты получают тот же язык, что и раньше, — просто теперь его
получает и `intl`. Приложение вызывает колбэк при старте и при каждой смене
системных языков, до того как построится всё, что ниже него, и каждая смена
логируется.

Что нужно знать:

* Передавайте tear-off как есть, а не замыкание: приложение сравнивает колбэк
  по идентичности при каждой перестройке.
* Не задавайте `Intl.systemLocale` (`findSystemLocale()`) «для правильного
  форматирования». Именно из-за него форматтеры и говорят на языке
  устройства, а после того как колбэк отработал, `intl` к нему больше не
  обращается.
* `DateFormat` нужны символы дат для локали. Их загружают делегаты
  `flutter_localizations`, а `AppLocalizations.localizationsDelegates` их уже
  включает; приложение без них вызывает `initializeDateFormatting()` само.
* Виджет-тест строит собственный `MaterialApp`. Тест, который проверяет
  отформатированные даты или числа, подключает туда тот же колбэк — или
  задаёт `Intl.defaultLocale` в `setUp`, — иначе он форматирует в `en_US`.

## Виджеты

```dart
BannerPro(application: application),
```

`BannerPro` помечает непродакшн-сборку угловой лентой с [именем](#флейвор)
флейвора. Он оборачивает всё приложение — над всеми маршрутами, чтобы ни один
экран не мог его перекрыть, — а на `FlavorProduction` возвращает дочерний
виджет как есть.

```dart
EmptyButton(
  onClick: onClick,
  child: child,
),
```

`EmptyButton` не даёт никакого визуального отклика, кроме рамки фокуса при
фокусе с клавиатуры (`FocusHighlightMode.traditional`), — с прозрачным
оверлеем пользователь клавиатуры иначе не видел бы, где находится. Передайте
`focusBorderRadius`, чтобы повторить скругление дочернего виджета.

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

`ExpansionTilePro` — раскрывающаяся строка списка: заголовок с шевроном
(`icon`, в раскрытом состоянии повёрнут на пол-оборота) и `child` под ним.
Состояние раскрытия остаётся у вызывающего кода (`isExpanded` + `onToggle`):
один список держит открытой одну строку, другой — сколько угодно. Всё визуальное
задаётся параметрами, так что собственной дизайн-системы строка не приносит.
Подсветка при наведении выходит за строку по горизонтали на `highlightBleed`
(по умолчанию 12), поэтому заголовок остаётся на одной вертикали с остальным
блоком: ни один предок не должен обрезать эти края (списку нужен
`clipBehavior: Clip.none`), а там, где снаружи места нет, — в модальном окне,
в колонке вплотную к краю — дайте строке отступ той же ширины. Область нажатия —
`EmptyButton`: никакого ripple, только рамка фокуса с клавиатуры.

## Веб

Flutter в вебе — это canvas, вокруг которого клавиатура, мышь и адресная
строка: многое, что страница в браузере получает бесплатно, приходится
подключать вручную. В этом разделе собрано, что пакет для этого даёт, и
правила, которым приложение должно следовать, чтобы всё работало.

### Прокрутка с клавиатуры

В вебе Flutter сам сопоставляет стрелки, PageUp/PageDown и пробел с
`ScrollIntent` и обрабатывает их встроенным `ScrollAction`. Это действие
прокручивает `Scrollable`, внутри которого находится виджет в фокусе, а если
внутри прокручиваемых областей ничего не в фокусе, откатывается к
`PrimaryScrollController` маршрута, у которого тогда должна быть **ровно одна**
подключённая позиция прокрутки. Здесь веб и отличается от мобильных платформ:
на десктопных платформах (а веб в десктопном браузере сообщает ОС хоста)
scroll view **не** наследуют primary-контроллер автоматически, поэтому у
контроллера нет клиентов и клавиши ничего не делают.

Правила, при которых это работает:

- **`primary: true` получает ровно один корневой scrollable на маршрут**:
  список страницы, список шторки, список диалога. Вложенные списки
  (`shrinkWrap`, `NeverScrollableScrollPhysics`) не должны быть `primary`:
  вторая позиция на контроллере маршрута ломает действие прокрутки и
  десктопный скроллбар.
- Scroll view, который **владеет** контроллером маршрута (передаёт его как
  `controller` и читает из него `offset`), оборачивает своё содержимое в
  `PrimaryScrollController.none`: на мобильных платформах вложенные
  вертикальные списки наследуют primary-контроллер и тоже подключились бы к нему.
- **Вкладки (`IndexedStack`)**: Flutter исключает скрытую вкладку из фокуса,
  но фокус при этом попадает на scope над вкладками, где прокручивать нечего.
  Когда вкладка становится активной, переведите фокус на верхний маршрут её
  навигатора через `focusTopRoute(Navigator.of(context))`, причём после кадра:
  пока стек не перестроится, вкладка всё ещё исключена, и запрос молча
  отбрасывается.

  ```dart
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => focusTopRoute(Navigator.of(context)),
  );
  ```

- `unfocus()` (а вместе с ним и `UnfocusingTap`) не трогает фокус, если тот
  уже стоит на scope: снятие фокуса со scope переносит фокус на scope уровнем
  выше, и тап по фону страницы иначе убивал бы прокрутку с клавиатуры.
- `TextField` в фокусе оставляет клавиши себе, как и в браузере.

`KeyboardShortcutsPro` добавляет то, что Flutter не сопоставляет: Home/End
(в том числе с Ctrl), Shift+Space и — только на платформах Apple — клавиши,
которыми браузер на macOS прокручивает страницу: Cmd+Up/Down — к краям
страницы, Option+Up/Down — на экран, Option+Left/Right — то же по горизонтали.
Последней группе привязка нужнее всего: `defaultShortcuts` отвечает веб-картой,
какой бы ни была ОС хоста, так что собственная Apple-карта Flutter до браузера
не доходит никогда, а там, где она всё же действует, Cmd+стрелка сдвигает
всего на одну строку. Привязаны они только на платформах Apple, потому что
в других ОС те же сочетания — это Alt+стрелка, а Alt+Left/Right там —
собственные «назад»/«вперёд» браузера; Cmd+Left/Right не привязан нигде,
поскольку этим сочетанием любой браузер ходит по своей истории, а клавиша,
которую приложение не обрабатывает, уходит браузеру.

Его actions также заменяют собственный `ScrollAction` фреймворка на
`ScrollActionPro` — именно благодаря этому **зажатой** клавишей можно
пользоваться. Фреймворк анимирует каждое нажатие, отталкиваясь от смещения, на
котором страница стоит в этот момент, а анимация — это отдельный тикер, который
на первом тике сообщает нулевое прошедшее время: когда ОС повторяет зажатую
клавишу каждые два-три кадра, каждый второй кадр оставлял страницу на месте, а
следующий наверстывал расстояние рывком. Здесь же нажатие сдвигает *цель*, а
единственный тикер — запускается первым нажатием, останавливается, когда
страница доехала, — тянет страницу за ней с критически демпфированной тягой,
настроенной под темп повторов. Пока клавиша зажата, страница отстаёт от цели на
фиксированное расстояние и держит ровно ту скорость, которую задают повторы;
когда клавишу отпустили, страница сокращает это расстояние и останавливается, и
пройденный путь всегда равен сумме нажатий. Home/End работают так же, целясь в
неподвижную точку. Действие включено, только когда ему есть что прокручивать по
оси intent'а, так что клавишу, которую оно использовать не может, получает
следующий в цепочке.

Передайте обе карты в приложение; они дополняют стандартные, так что внутри
поля по-прежнему побеждают сочетания для редактирования текста:

```dart
MaterialApp.router(
  shortcuts: KeyboardShortcutsPro.shortcuts,
  actions: KeyboardShortcutsPro.actions,
  ...
)
```

### Ссылки

Для браузера область нажатия — не ссылка: ни URL при наведении, ни
Ctrl/Cmd+клика или клика средней кнопкой в новую вкладку. `RouteLink` делает
виджет настоящей ссылкой в вебе (`Link` из `url_launcher`, элемент `<a>`
поверх виджета), а на остальных платформах остаётся обычным `EmptyButton`:

```dart
RouteLink(
  path: '/catalog/product/1', // absolute in-app path; null — no link, tap only
  onClick: viewModel.openDetails,
  child: card,
)
```

Обычный клик уходит в `onClick` — та же навигация внутри приложения, что и
раньше, со всеми данными, которые уже есть у VM. Ссылке передаётся только клик
с клавишей-модификатором: новую вкладку браузер открывает сам, а без сигнала
`followLink` от приложения плагин отменяет навигацию в текущей вкладке.
Стройте путь из того же объекта маршрута, который пушит клик
(`RouteMatcher.matchByRoute` + `UrlState.fromSegments` из auto_route), чтобы
URL при наведении совпадал с тем, который даёт клик. Передавайте
закодированную форму (`uri.toString()`), а не раскодированный `UrlState.url`,
и держите query в строке пути: виджет её разбирает, а `Uri(path:)` закодировал
бы `?` через percent-encoding.

Внешний URL (`https://…`) работает так же и получает `target="_blank"`:
контекстное меню браузера распознаёт его как ссылку, а клик с модификатором
открывает его в новой вкладке; обычный клик по-прежнему уходит в `onClick`,
так что у приложения остаётся свой способ открывать такие ссылки.

### Автопрокрутка средней кнопкой мыши

Браузер умеет прокручивать страницу по клику средней кнопкой: нажатие ставит
якорь, затем мышь задаёт направление и скорость, а клик завершает режим.
В вебе здесь браузер этого сделать не может — Flutter рисует в canvas, и в
документе нет собственного прокручиваемого элемента, — поэтому `AutoScrollPro`
воссоздаёт этот режим поверх приложения. Оберните им приложение целиком, над
навигатором, — тогда метка якоря и блокировка указателя одинаково накрывают
страницы, шторки и диалоги:

```dart
MaterialApp.router(
  builder: (_, child) => AutoScrollPro(child: child!),
  ...
)
```

Шаг отправляется так же, как от колеса мыши, — синтезированным
`PointerScrollEvent`, нацеленным в якорь, — а не записью в позицию прокрутки:
тогда фреймворк сам выбирает scrollable — тот, в который целился
пользователь, — сохраняет его физику и передаёт движение родителю, когда
вложенному списку дальше ехать некуда. Лишь когда под якорем вообще ничего не
прокручивается (фиксированная шапка, боковое меню), шаг напрямую принимает
primary-позиция маршрута — та же, которую прокручивает клавиатура, так что
правило *один корневой scrollable на маршрут* выше работает и для этого режима.

Пока режим включён, приложение стоит за блокировкой указателя: клик,
завершающий режим, ничего не нажимает и ни на что не наводится, как и в
браузере. Блокировка пропускает только собственные события колеса этого
режима. Браузер тоже сдерживается — пока режим включён, действие средней
кнопки по умолчанию отменяется, иначе клик, завершающий режим, заодно открыл
бы ссылку под курсором в новой вкладке, ведь `RouteLink` — настоящий элемент
`<a>`, на который браузер реагирует сам. Удержание переживает нажатие,
завершающее режим: режим заканчивается внутри `pointerdown`, а `mousedown` и
`auxclick`, чьи действия по умолчанию и важны, приходят после него, поэтому
нажатие, начавшееся в режиме, удерживается до своего `auxclick`. Завершить
режим может только пользователь: колесом, Escape, кликом или отпусканием
кнопки, которую тянули, а не кликнули. Уход курсора за пределы окна и потеря
окном фокуса режим не выключают — цель просто перестаёт обновляться, и
страница продолжает двигаться так, как была нацелена в последний раз, — так же
ведёт себя собственный режим браузера.

Над `RouteLink` средняя кнопка принадлежит браузеру — она открывает ссылку
в новой вкладке, — поэтому ссылка забирает этот клик у режима через
`AutoScrollScope`. Так же должно поступать всё остальное, что само отвечает
на среднюю кнопку.

Проверки на веб здесь нет: на платформе без средней кнопки режим никогда не
включится, а в Windows тот же жест — привычная десктопная конвенция.

### Контекстное меню браузера

Над canvas меню браузера предлагает только «Назад» и «Обновить», зато на
`RouteLink` это нативное меню ссылки — «Открыть в новой вкладке», «Копировать
адрес ссылки», — так что его стоит оставить.
`BrowserContextMenu.disableContextMenu()` (после инициализации binding) убирает
его сразу везде; текстовые поля тогда показывают вместо него собственное меню
Flutter.

### Фокус клавиатуры

`EmptyButton` рисует рамку фокуса при фокусе с клавиатуры, чтобы пользователь
клавиатуры видел, где находится; кнопки Material показывают собственный
оверлей фокуса.

`RouteLink` — настоящий элемент `<a>`, и браузер оставляет свой фокус на
элементе, на который пришёлся клик. Когда этот элемент затем исчезает —
карточка была на странице, с которой клик увёл, или ленивый список её
переиспользовал, — браузер сбрасывает фокус на body документа, за пределы
Flutter view, а Flutter паркует свой фокус на корневом scope, где ни один
виджет не может принять клавишу: прокрутка страницы, Escape и все остальные
сочетания клавиш не работают до следующего клика где угодно.
`PageFocusKeeper` возвращает фокус: он отличает этот случай от ухода
пользователя в адресную строку или на другую вкладку (документ по-прежнему
в фокусе, фокус у его body) и проводит фокус вниз по цепочке последних
сфокусированных дочерних узлов до верхнего маршрута — так, как это сделал бы
следующий клик. Оберните им приложение поверх всего остального, рядом с
`AutoScrollPro`:

```dart
MaterialApp.router(
  builder: (_, child) => PageFocusKeeper(child: AutoScrollPro(child: child!)),
  ...
)
```
