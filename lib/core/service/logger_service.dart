import 'package:application_base/core/const/navigator_transaction.dart';
import 'package:application_base/core/service/logger_config_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:logger/logger.dart';

/// Facade over [LoggerConfigService.userId].
String get loggerUserId => loggerState.userId;

///
set loggerUserId(String value) => loggerState.userId = value;

/// Facade over [LoggerConfigService.infoSink].
void Function({required String information})? get logInfoRemote =>
    loggerState.infoSink;

///
set logInfoRemote(void Function({required String information})? value) =>
    loggerState.infoSink = value;

/// Facade over [LoggerConfigService.isLocalLoggingEnabled].
bool get isLocalLoggingEnabled => loggerState.isLocalLoggingEnabled;

///
// A setter parameter is positional by language rule, so this lint cannot be
// satisfied without dropping the setter.
// ignore: avoid_positional_boolean_parameters
set isLocalLoggingEnabled(bool value) =>
    loggerState.isLocalLoggingEnabled = value;

/// Facade over [LoggerConfigService.errorSink].
void Function({required String error, StackTrace? stack})? get logErrorRemote =>
    loggerState.errorSink;

///
set logErrorRemote(
  void Function({required String error, StackTrace? stack})? value,
) => loggerState.errorSink = value;

/// Local logger for beauty output info in console
final Logger _localLogger = Logger(
  printer: PrettyPrinter(
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Local logger for beauty output info in console without stack
final Logger _localPureLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Logging some information
void logInfo({required String info, String? additional}) {
  /// Prepare full error message
  String message = info;
  if (additional != null) message += ': $additional';

  /// The console sink already goes through `print`, so on web this lands in
  /// the browser console and in the tooling console at once — no second write
  /// is needed.
  if (isLocalLoggingEnabled) _localPureLogger.i(message);

  /// Telemetry stays tied to release builds: a developer machine must not fill
  /// up the reporting of a live app.
  if (!isDebug) logInfoRemote?.call(information: message);
}

/// For greater clarity
void logImportant({required String info, String? additional}) =>
    logInfo(info: '⚡️⚡️⚡️ $info', additional: additional);

/// Logging some error
///
/// [stack] reaches the remote sink untouched — a reporter needs the frames as
/// a trace, not as text inside the message, to group the error with its peers.
void logError({required String error, String? additional, StackTrace? stack}) {
  /// Prepare full error message
  String message = error;
  if (additional != null) message += ': $additional';

  if (loggerUserId.isNotEmpty) message += '\nUser: $loggerUserId';

  ///
  if (isLocalLoggingEnabled) _localLogger.e(message, stackTrace: stack);

  ///
  if (!isDebug) logErrorRemote?.call(error: message, stack: stack);
}

/// New screen opened
void logScreenChanged({
  required NavigatorTransaction transaction,
  required String? from,
  required String? to,
}) {
  String message = 'Screen changed: ${navigatorTransactionString(transaction)}';
  if (from != null) message += ' from $from';
  if (to != null) message += ' to $to';
  logInfo(info: message);
}
