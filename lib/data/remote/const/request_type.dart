import 'package:application_base/data/remote/const/network_event.dart';
import 'package:application_base/data/remote/const/request_duration_type.dart';
import 'package:cross_file/cross_file.dart';

/// API request type with all necessary data
sealed class RequestType {
  ///
  RequestType({
    required this.type,
    required this.path,
    this.expectedStatusList = const [],
    this.expectedErrorMap = const {},
    this.silence = false,
    this.durationType = RequestDurationType.normal,
  });

  /// Type name for logging
  final String type;

  /// Path for request without address and base API segment
  final String path;

  /// Body for request
  Object? get body;

  /// Expected response statuse list in API endpoint
  ///
  /// Empty — the default — means "any 2xx", the same definition of success as
  /// `ResponseEntity.isOk`. Before, the default was `[200]` alone, so a `201
  /// Created` from a POST was reported as an unexpected response even though
  /// `ResponseEntity.isOk` called the very same reply a success.
  ///
  /// Fill the list in only when the exact status carries meaning — for example
  /// to take over a `404` instead of letting the unified path report it. A
  /// non-empty list is matched exactly, 2xx included.
  ///
  /// To accept extra statuses for a single call without touching the request,
  /// pass them to `RequestServiceBase.sendBase` as `extraExpectedStatusList`.
  final List<int> expectedStatusList;

  /// Expected response pair `HTTP status -> Network event` map in API endpoint
  final Map<int, NetworkEvent> expectedErrorMap;

  /// Do not show error on silence mode
  final bool silence;

  /// Average request duration type
  final RequestDurationType durationType;
}

///
final class RequestGet extends RequestType {
  ///
  RequestGet({
    required super.path,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.normal,
  }) : super(type: 'GET');

  /// Body for request
  @override
  final Object? body = null;
}

///
final class RequestPost extends RequestType {
  ///
  RequestPost({
    required super.path,
    this.body,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.normal,
  }) : super(type: 'POST');

  /// Body for request
  @override
  final String? body;
}

///
final class RequestPostFormData extends RequestType {
  ///
  RequestPostFormData({
    required super.path,
    this.body,
    this.files = const {},
    this.ignoreNullFields = true,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
  }) : super(type: 'POST form data');

  /// Body for request in JSON
  @override
  final Map<String, dynamic>? body;

  ///
  final bool ignoreNullFields;

  /// Field name and path to local file
  final Map<String, XFile> files;
}

/// Uploading file as binary data using octet-stream
final class RequestPostFile extends RequestType {
  ///
  RequestPostFile({
    required super.path,
    required this.file,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
  }) : super(type: 'POST file as binary data');

  /// Path to a local file
  final XFile file;

  /// Request has no body
  @override
  Object? get body => null;
}

///
final class RequestPut extends RequestType {
  ///
  RequestPut({
    required super.path,
    this.body,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.normal,
  }) : super(type: 'PUT');

  /// Body for request
  @override
  final String? body;
}

///
final class RequestPatch extends RequestType {
  ///
  RequestPatch({
    required super.path,
    this.body,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.normal,
  }) : super(type: 'PATCH');

  /// Body for request
  @override
  final String? body;
}

///
final class RequestDelete extends RequestType {
  ///
  RequestDelete({
    required super.path,
    this.body,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.normal,
  }) : super(type: 'DELETE');

  /// Body for request
  @override
  final String? body;
}
