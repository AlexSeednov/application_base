import 'package:application_base/core/const/navigator_transaction.dart';
import 'package:application_base/core/service/logger_config_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:logger/logger.dart';

/// Facade over [LoggerConfigService.userId].
String get loggerUserId => loggerConfigOrNull?.userId ?? '';

///
set loggerUserId(String value) => loggerConfigOrNull?.userId = value;

/// Facade over [LoggerConfigService.infoSink].
void Function({required String information})? get logInfoRemote =>
    loggerConfigOrNull?.infoSink;

///
set logInfoRemote(void Function({required String information})? value) =>
    loggerConfigOrNull?.infoSink = value;

/// Facade over [LoggerConfigService.isLocalLoggingEnabled].
bool get isLocalLoggingEnabled =>
    loggerConfigOrNull?.isLocalLoggingEnabled ?? isDebug;

///
// A setter parameter is positional by language rule, so this lint cannot be
// satisfied without dropping the setter.
// ignore: avoid_positional_boolean_parameters
set isLocalLoggingEnabled(bool value) =>
    loggerConfigOrNull?.isLocalLoggingEnabled = value;

/// Facade over [LoggerConfigService.errorSink].
void Function({required String error})? get logErrorRemote =>
    loggerConfigOrNull?.errorSink;

///
set logErrorRemote(void Function({required String error})? value) =>
    loggerConfigOrNull?.errorSink = value;

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
void logError({required String error, String? additional}) {
  /// Prepare full error message
  String message = error;
  if (additional != null) message += ': $additional';

  if (loggerUserId.isNotEmpty) message += '\nUser: $loggerUserId';

  ///
  if (isLocalLoggingEnabled) _localLogger.e(message);

  ///
  if (!isDebug) logErrorRemote?.call(error: message);
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
