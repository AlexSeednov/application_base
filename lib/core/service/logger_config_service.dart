import 'package:application_base/core/service/platform_service.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Backing store of the logging facade.
///
/// A plain object in a module-level field rather than state inside
/// [LoggerConfigService]: an application configures logging — the flavor,
/// whether sensitive data may be logged — *before* `getIt.init()` runs.
/// Behind DI those early writes would resolve against an unregistered type
/// and be dropped, and a production flavor in a debug build would keep
/// logging bodies despite being told not to.
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
  ///
  /// The stack trace travels beside the message instead of being folded into
  /// it: crash reporters group incoming errors by their frames, so a sink that
  /// only ever sees text has to invent a trace at the point of reporting and
  /// every unrelated error collapses into one issue.
  void Function({required String error, StackTrace? stack})? errorSink;
}

/// The instance every logging facade reads from and writes to.
final LoggerState loggerState = LoggerState();

/// Injectable handle over [loggerState].
///
/// Gives getIt a seam over state it does not own: [reset] runs on
/// `getIt.reset()`, so logging state does not leak between tests. The storage
/// itself stays outside DI for the early writes described on [LoggerState].
///
/// Registered eagerly: getIt skips the dispose hook of a lazy singleton nobody
/// resolved, and the top-level logging setters write around this service, so
/// a lazy one would let their state leak whenever only they were used.
@singleton
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
  void Function({required String error, StackTrace? stack})? get errorSink =>
      loggerState.errorSink;

  ///
  set errorSink(void Function({required String error, StackTrace? stack})? v) =>
      loggerState.errorSink = v;

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
