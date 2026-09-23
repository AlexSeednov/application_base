import 'package:application_base/data/remote/const/network_event.dart';
import 'package:application_base/data/remote/const/request_duration_type.dart';
import 'package:cross_file/cross_file.dart';

/// A typed API request: method, path, body and how its response is judged.
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

  ///
  Object? get body;

  /// Statuses that count as success.
  ///
  /// Empty — the default — means "any 2xx", the same definition of success as
  /// `ResponseEntity.isOk`, so a `201 Created` from a POST is a success too.
  ///
  /// Fill the list in only when the exact status carries meaning — for example
  /// to take over a `404` instead of letting the unified path report it. A
  /// non-empty list is matched exactly, 2xx included.
  ///
  /// To accept extra statuses for a single call without touching the request,
  /// pass them to `RequestServiceBase.sendBase` as `extraExpectedStatusList`.
  final List<int> expectedStatusList;

  /// The event to publish for a failed status instead of
  /// [NetworkUnexpectedResponse].
  ///
  /// A 401 and a 504 are handled before this map and cannot be remapped.
  final Map<int, NetworkEvent> expectedErrorMap;

  /// Keeps this request's events off `NetworkSubject`, e.g. for a ping.
  ///
  /// A lost connection and a 401 are published anyway: that state is global.
  final bool silence;

  /// Picks the request's timeout.
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

  ///
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

  ///
  @override
  final String? body;
}

/// Multipart form with fields and files.
///
/// Runs with the long timeout by default: an upload is the heavy request
/// `RequestServiceBase.longTimeout` exists for, and the normal one cuts a
/// photo off on a slow mobile link.
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
    super.durationType = RequestDurationType.long,
  }) : super(type: 'POST form data');

  /// Form fields; each value is sent as its `toString()`.
  @override
  final Map<String, dynamic>? body;

  /// Drops `null` fields, which would otherwise be sent as the string `null`.
  final bool ignoreNullFields;

  /// Files keyed by form field name.
  final Map<String, XFile> files;
}

/// A file uploaded as a raw `application/octet-stream` body.
///
/// Runs with the long timeout by default, for the same reason as
/// [RequestPostFormData].
final class RequestPostFile extends RequestType {
  ///
  RequestPostFile({
    required super.path,
    required this.file,
    super.expectedStatusList = const [],
    super.expectedErrorMap = const {},
    super.silence = false,
    super.durationType = RequestDurationType.long,
  }) : super(type: 'POST file as binary data');

  ///
  final XFile file;

  /// Always `null`: [file] is streamed as the body instead.
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

  ///
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

  ///
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

  ///
  @override
  final String? body;
}
