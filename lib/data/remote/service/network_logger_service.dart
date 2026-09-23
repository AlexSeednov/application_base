import 'package:application_base/core/service/logger_config_service.dart';
import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:application_base/data/remote/entity/response_entity.dart';

/// Whether request and response bodies may reach the logs.
///
/// **isDebug** by default. Facade over
/// [LoggerConfigService.canLogSensitiveData]; kept here so the existing import
/// sites in the consuming apps do not change.
bool get canLogSensitiveData => loggerState.canLogSensitiveData;

///
// A setter parameter is positional by language rule, so this lint cannot be
// satisfied without dropping the setter and breaking every existing call site.
// ignore: avoid_positional_boolean_parameters
set canLogSensitiveData(bool value) => loggerState.canLogSensitiveData = value;

/// [body] is dropped unless [canLogSensitiveData] allows it.
void logRequestInfo({
  required RequestType request,
  String? body,
  String? info,
}) {
  String information = 'Request ${request.type} ${request.path}';
  if (canLogSensitiveData && body != null) information += '\nBody $body';
  if (info != null) information += '\n$info';
  logInfo(info: information);
}

///
void logRequestError({required RequestType request, required String error}) =>
    logError(error: 'Request ${request.type} ${request.path}\n$error');

/// The body is dropped unless [canLogSensitiveData] allows it.
void logResponseInfo({required ResponseEntity response}) {
  String information =
      'Request ${response.request}\n'
      'Response ${response.statusCode}';
  if (canLogSensitiveData && response.body.isNotEmpty) {
    information += '\nBody ${response.body}';
  }
  logInfo(info: information);
}

/// Logs a response with an unexpected status; the body is dropped unless
/// [canLogSensitiveData] allows it.
void logResponseError({required ResponseEntity response}) {
  String error =
      'Request ${response.request}\n'
      'Response ${response.statusCode}';

  if (canLogSensitiveData && response.body.isNotEmpty) {
    error += '\nBody ${response.body}';
  }
  logError(error: error);
}

/// The raw body is dropped unless [canLogSensitiveData] allows it.
void logJsonParsingError({required ResponseEntity data, required String info}) {
  String error =
      'Request ${data.request}\n'
      'Got JSON parsing error $info';
  if (canLogSensitiveData) error += '\n${data.body}';
  logError(error: error);
}

///
void logTokenEmptyError({required RequestType request}) => logError(
  error:
      'Request ${request.type} ${request.path}\n'
      'Can not be sent without token',
);
