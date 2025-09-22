## 0.1.3

* Updates minimum supported SDK version to Flutter 3.35.4/Dart 3.9.2
* Updates all packages to actual versions

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