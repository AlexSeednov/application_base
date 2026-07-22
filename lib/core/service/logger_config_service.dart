import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Mutable runtime configuration of the logging facade.
///
/// These four values used to be top-level variables. Being top-level, they
/// survived `getIt.reset()` and leaked between tests, and nothing tied their
/// lifetime to the rest of the container. Holding them here makes the state
/// resettable while the way callers write to it stays the same — the
/// `loggerUserId` / `canLogSensitiveData` / `logInfoRemote` / `logErrorRemote`
/// accessors are now thin facades over this object.
@lazySingleton
final class LoggerConfigService {
  ///
  @visibleForTesting
  LoggerConfigService();

  /// Attached to every error report so a crash can be traced to an account.
  String userId = '';

  /// Whether request and response bodies are allowed to reach the logs.
  bool canLogSensitiveData = isDebug;

  /// Remote sink for informational messages, wired by the consuming app.
  void Function({required String information})? infoSink;

  /// Remote sink for errors, wired by the consuming app.
  void Function({required String error})? errorSink;
}

/// The registered config, or `null` while the service locator is not ready.
///
/// Logging must not depend on DI being initialised: the very first lines are
/// written before `getIt.init()` completes, and resolving an unregistered type
/// would throw inside the logger itself. Callers fall back to defaults.
LoggerConfigService? get loggerConfigOrNull =>
    getIt.isRegistered<LoggerConfigService>()
    ? getIt<LoggerConfigService>()
    : null;
