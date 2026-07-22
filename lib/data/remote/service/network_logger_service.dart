import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:application_base/data/remote/entity/response_entity.dart';

/// Can send sensitive data to remote logger or not
///
/// **isDebug** by default
bool canLogSensitiveData = isDebug;

/// Logging request information
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

/// Logging request error
void logRequestError({required RequestType request, required String error}) =>
    logError(error: 'Request ${request.type} ${request.path}\n$error');

/// Logging response
void logResponseInfo({required ResponseEntity response}) {
  String information =
      'Request ${response.request}\n'
      'Response ${response.statusCode}';
  if (canLogSensitiveData && response.body.isNotEmpty) {
    information += '\nBody ${response.body}';
  }
  logInfo(info: information);
}

/// Error in response
void logResponseError({required ResponseEntity response}) {
  String error =
      'Request ${response.request}\n'
      'Response ${response.statusCode}';

  if (canLogSensitiveData && response.body.isNotEmpty) {
    error += '\nBody ${response.body}';
  }
  logError(error: error);
}

/// Error on JSON parsing
void logJsonParsingError({required ResponseEntity data, required String info}) {
  String error =
      'Request ${data.request}\n'
      'Got JSON parsing error $info';
  if (canLogSensitiveData) error += '\n${data.body}';
  logError(error: error);
}

///
void logTokenEmptyError({required RequestType request}) => logInfo(
  info:
      'Request ${request.type} ${request.path}\n'
      'Can not be sent without token',
);
