import 'package:application_base/core/const/navigator_transaction.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:logger/logger.dart';

///
String loggerUserId = '';

///
void Function({required String information})? logInfoRemote;

///
void Function({required String error})? logErrorRemote;

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

  /// Logging local only in debug mode
  if (isDebug) {
    /// Current user information
    _localPureLogger.i(message);

    /// For logging in browser console on Web
    // ignore: avoid_print
    if (isWeb) print(message);
  } else {
    logInfoRemote?.call(information: message);
  }
}

/// For greater clarity
void logImportant({required String info, String? additional}) =>
    logInfo(info: '⚡️⚡️⚡️ $info', additional: additional);

/// Logging some error
void logError({required String error, String? additional}) {
  /// Prepare full error message
  String message = error;
  if (additional != null) message += ': $additional';

  /// Logging local only in debug mode
  if (isDebug) {
    /// Current user information
    if (loggerUserId.isNotEmpty) message += '\nUser: $loggerUserId';

    _localLogger.e(message);

    /// For logging in browser console on Web
    // ignore: avoid_print
    if (isWeb) print(message);
  } else {
    logErrorRemote?.call(error: message);
  }
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
