import 'package:application_base/core/service/platform_service.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Backing store of the logging facade.
///
/// Deliberately a plain object held in a module-level field rather than state
/// living inside [LoggerConfigService]: a consuming app configures logging as
/// one of its very first steps — picking a flavor and deciding whether
/// sensitive data may be logged — and that happens *before* `getIt.init()` has
/// run. Keeping the values in the singleton meant those early writes resolved
/// against an unregistered type and were silently dropped, so a production
/// flavor running in a debug build would have kept logging bodies despite
/// being told not to.
final class LoggerState {
  ///
  @visibleForTesting
  LoggerState();

  /// Attached to every error report so a crash can be traced to an account.
  String userId = '';

  /// Whether request and response bodies are allowed to reach the logs.
  bool canLogSensitiveData = isDebug;

  /// Whether messages are printed to the local console.
  ///
  /// Defaults to debug builds, so a release build prints nothing anywhere a
  /// user could read it. Flip it on to investigate an issue on a real device.
  bool isLocalLoggingEnabled = isDebug;

  /// Remote sink for informational messages, wired by the consuming app.
  void Function({required String information})? infoSink;

  /// Remote sink for errors, wired by the consuming app.
  void Function({required String error})? errorSink;
}

/// The instance every logging facade reads from and writes to.
final LoggerState loggerState = LoggerState();

/// Injectable handle over [loggerState].
///
/// The values used to be four separate top-level variables with nothing tying
/// them together and no way to put them back: they survived `getIt.reset()` and
/// leaked between tests. Grouping them here gives the container a seam — the
/// dispose hook restores defaults — without moving the storage itself behind
/// DI, which is what the early-write problem above rules out.
@lazySingleton
final class LoggerConfigService {
  ///
  @visibleForTesting
  LoggerConfigService();

  ///
  String get userId => loggerState.userId;

  ///
  set userId(String value) => loggerState.userId = value;

  ///
  bool get canLogSensitiveData => loggerState.canLogSensitiveData;

  ///
  set canLogSensitiveData(bool value) =>
      loggerState.canLogSensitiveData = value;

  ///
  bool get isLocalLoggingEnabled => loggerState.isLocalLoggingEnabled;

  ///
  set isLocalLoggingEnabled(bool value) =>
      loggerState.isLocalLoggingEnabled = value;

  ///
  void Function({required String information})? get infoSink =>
      loggerState.infoSink;

  ///
  set infoSink(void Function({required String information})? value) =>
      loggerState.infoSink = value;

  ///
  void Function({required String error})? get errorSink =>
      loggerState.errorSink;

  ///
  set errorSink(void Function({required String error})? value) =>
      loggerState.errorSink = value;

  /// Restores every value to its default, so one test cannot inherit the
  /// logging configuration of another.
  @disposeMethod
  void reset() {
    loggerState
      ..userId = ''
      ..canLogSensitiveData = isDebug
      ..isLocalLoggingEnabled = isDebug
      ..infoSink = null
      ..errorSink = null;
  }
}
