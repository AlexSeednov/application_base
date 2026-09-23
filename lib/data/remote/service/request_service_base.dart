import 'dart:async';
// Safe on web: dart2js ships a stub, and the only members used here are the
// [HttpStatus] integer constants plus exception types that are merely caught.
// Nothing in this file evaluates a `Platform` member.
import 'dart:io';
import 'dart:typed_data';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/const/request_duration_type.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:application_base/data/remote/service/network_logger_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// Base of the application's HTTP service: sends a [RequestType] and reports
/// every failure to [NetworkSubject].
///
/// A subclass must be a singleton: it owns the HTTP client and its connection
/// pool.
abstract base class RequestServiceBase {
  /// Timeout for super fast requests (e.g. ping). Override to customize.
  Duration get shortTimeout => const Duration(seconds: 3);

  /// Timeout for most requests. Override to customize.
  Duration get normalTimeout => const Duration(seconds: 20);

  /// Timeout for probably heavy requests (e.g. uploading a photo).
  /// Override to customize.
  Duration get longTimeout => const Duration(seconds: 30);

  /// Returns the timeout for the given [RequestDurationType] using the
  /// values from [shortTimeout], [normalTimeout] and [longTimeout].
  Duration timeoutFor(RequestDurationType type) => switch (type) {
    RequestDurationType.short => shortTimeout,
    RequestDurationType.normal => normalTimeout,
    RequestDurationType.long => longTimeout,
  };

  // Optimize(Alex): try `RetryClient` to retry failed requests automatically
  // (https://pub.dev/packages/http#retrying-requests). Tune which failures are
  // retried — a 401 at least must not be.
  /// One client for every request, so keep-alive connections are reused:
  /// https://dart.dev/tutorials/server/fetch-data#make-multiple-requests
  Client _client = Client();

  /// Replaces the HTTP client, closing the previous one.
  ///
  /// The replaced client owns a connection pool that would otherwise stay
  /// open for the rest of the process.
  set client(Client newValue) {
    if (identical(_client, newValue)) return;
    _client.close();
    _client = newValue;
  }

  /// Releases the HTTP client together with its keep-alive connections.
  ///
  /// Subclasses are singletons, so mark the override with `@disposeMethod`
  /// for getIt to call it on reset.
  @mustCallSuper
  void dispose() => _client.close();

  ///
  final NetworkSubject _networkSubject = getIt<NetworkSubject>();

  /// Builds the full URL for [path]: the host and the base API segment are
  /// the subclass's, see [RequestType.path].
  @mustBeOverridden
  Uri prepareUri({required String path});

  /// Sends [request]; `null` means it failed.
  ///
  /// A failure is already reported to [NetworkSubject] — no connection, a
  /// 401, an unexpected status — and handled there the same way for the whole
  /// application, so a caller needs no special branch for `null`.
  ///
  /// [extraExpectedStatusList] widens what this single call accepts, so a
  /// caller can take over a status the unified path would otherwise swallow —
  /// typically a 401 it wants to answer with a token refresh. It is additive:
  /// it never removes a status that would have been accepted anyway. Being a
  /// per-call concern rather than a property of the request, it is passed here
  /// instead of being written into [request].
  ///
  /// [extraExpectedErrorMap] is the same idea for
  /// [RequestType.expectedErrorMap]: it lets a service attach a handler that
  /// applies to every request it sends — an outdated-client status, say —
  /// without each call site having to declare it. Entries here win over the
  /// request's own for the same status.
  Future<ResponseEntity?> sendBase({
    required RequestType request,
    required Map<String, String> headers,
    List<int> extraExpectedStatusList = const [],
    Map<int, NetworkEvent> extraExpectedErrorMap = const {},
  }) async {
    try {
      final Uri uri = prepareUri(path: request.path);

      logRequestInfo(
        request: request,
        body: request.body?.toString(),
        info: 'Sending',
      );

      final Future<Response> futureResponse = switch (request) {
        RequestGet() => _client.get(uri, headers: headers),
        RequestPost() => _client.post(
          uri,
          headers: headers,
          body: request.body,
        ),
        RequestPostFormData() => _sendPostFormData(
          uri: uri,
          headers: headers,
          requestData: request,
        ),
        RequestPostFile() => _sendPostFile(
          uri: uri,
          headers: headers,
          requestData: request,
        ),
        RequestPut() => _client.put(uri, headers: headers, body: request.body),
        RequestPatch() => _client.patch(
          uri,
          headers: headers,
          body: request.body,
        ),
        RequestDelete() => _client.delete(
          uri,
          headers: headers,
          body: request.body,
        ),
      };

      final Response httpResponse = await futureResponse.timeout(
        timeoutFor(request.durationType),
      );

      final response = ResponseEntity(
        request: '${request.type} $uri',
        body: httpResponse.body,
        statusCode: httpResponse.statusCode,
      );

      /// Success is "any 2xx" unless the request pins an explicit list, which
      /// keeps this in step with [ResponseEntity.isOk].
      /// [extraExpectedStatusList] is strictly additive on top of either: it
      /// widens what this one call tolerates and never narrows it.
      final bool isExpectedStatus =
          extraExpectedStatusList.contains(httpResponse.statusCode) ||
          (request.expectedStatusList.isEmpty
              ? response.isOk
              : request.expectedStatusList.contains(httpResponse.statusCode));

      if (!isExpectedStatus) {
        logResponseError(response: response);

        if (httpResponse.statusCode == HttpStatus.unauthorized) {
          // A caller that handles a 401 itself (say, with a token refresh)
          // accepts it through `expectedStatusList` or
          // `extraExpectedStatusList`, checks the response, and calls
          // `notifyUnauthorized` itself when `NetworkSubject` must still know.
          notifyUnauthorized();
          return null;
        }
        if (httpResponse.statusCode == HttpStatus.gatewayTimeout) {
          // The backend behind the gateway is unreachable: the same lost
          // connection as a timeout, and just as global, so never silenced.
          notify(NetworkConnectionLost());
          return null;
        }

        final NetworkEvent? expectedErrorType =
            extraExpectedErrorMap[httpResponse.statusCode] ??
            request.expectedErrorMap[httpResponse.statusCode];
        if (expectedErrorType != null) {
          notify(expectedErrorType, silence: request.silence);
          return null;
        }

        notify(NetworkUnexpectedResponse(), silence: request.silence);
        return null;
      }

      logResponseInfo(response: response);
      notify(NetworkSuccess(), silence: request.silence);
      return response;
    } on TimeoutException {
      /// A timeout counts as a lost connection: for the user the backend is
      /// unreachable, so the app goes offline. Never silenced — connection
      /// state is global.
      logRequestInfo(request: request, info: 'Timeout exception');
      notify(NetworkConnectionLost());
    } on SocketException catch (error) {
      /// No socket at all: DNS failure, unreachable route, refused connection.
      /// The typical case is Wi-Fi reported as available while the router
      /// blocks the Internet or DNS. Never silenced, not even for a ping —
      /// connection state is global.
      logRequestInfo(
        request: request,
        info: 'No connection (${error.message})',
      );
      notify(NetworkConnectionLost());
    } on HandshakeException catch (error) {
      /// An SSL problem on the backend side leaves it just as unreachable, so
      /// the app goes offline.
      logRequestError(request: request, error: error.message);
      notify(NetworkConnectionLost());
    } on ClientException catch (error) {
      /// The web build never sees a [SocketException]: there `package:http`
      /// reports a connection that could not be made as [ClientException].
      /// The generic catch below would call it an unexpected error, and the
      /// app would never go offline on the web.
      logRequestInfo(
        request: request,
        info: 'No connection (${error.message})',
      );
      notify(NetworkConnectionLost());
    } catch (error) {
      /// Not a connection problem, so the request's `silence` applies.
      logRequestError(request: request, error: error.toString());
      notify(NetworkUnexpectedError(), silence: request.silence);
    }
    return null;
  }

  /// Reports a 401 to [NetworkSubject], never silenced.
  ///
  /// Public for a caller that accepted a 401 itself and still needs the
  /// unified handling.
  void notifyUnauthorized() => notify(NetworkUnauthorized());

  /// A silenced event is dropped, not delivered quietly.
  void notify(NetworkEvent type, {bool silence = false}) {
    if (silence) return;
    _networkSubject.add(type);
  }

  ///
  Future<Response> _sendPostFormData({
    required Uri uri,
    required Map<String, String> headers,
    required RequestPostFormData requestData,
  }) async {
    final request = MultipartRequest('POST', uri);

    if (requestData.body != null) {
      Iterable<MapEntry<String, dynamic>> entries;

      if (requestData.ignoreNullFields) {
        entries = requestData.body!.entries.where(
          (entry) => entry.value != null,
        );
      } else {
        entries = requestData.body!.entries;
      }
      request.fields.addAll(
        entries
            .map((entry) => MapEntry(entry.key, entry.value.toString()))
            .fold<Map<String, String>>(
              {},
              (previous, current) => previous..[current.key] = current.value,
            ),
      );
    }

    request.headers.addAll(headers);
    if (isWebBased) {
      /// Keep uploads away from any intermediate cache.
      ///
      /// `Content-Type` is deliberately not set here: [MultipartRequest]
      /// writes its own `multipart/form-data` value with the generated
      /// boundary in `finalize()`, and any value set earlier is overwritten.
      request.headers['Cache-Control'] = 'no-cache';
    }

    /// A sequential loop, not `Map.forEach`: `forEach` drops the futures of
    /// the asynchronous body, and the request would go out before the files
    /// are attached.
    for (final MapEntry<String, XFile> entry in requestData.files.entries) {
      if (isMobileBased) {
        request.files.add(
          await MultipartFile.fromPath(entry.key, entry.value.path),
        );
      } else {
        /// `fromPath` needs `dart:io`, which the web lacks. Desktop takes this
        /// branch too.
        final Uint8List fileBytes = await entry.value.readAsBytes();
        request.files.add(
          MultipartFile.fromBytes(
            entry.key,
            fileBytes,
            filename: entry.value.name,
          ),
        );
      }
    }

    return Response.fromStream(await request.send());
  }

  ///
  Future<Response> _sendPostFile({
    required Uri uri,
    required Map<String, String> headers,
    required RequestPostFile requestData,
  }) async {
    final XFile file = requestData.file;

    final request = StreamedRequest('POST', uri);

    request.headers.addAll(headers);
    request.headers['Content-Type'] = 'application/octet-stream';
    request.contentLength = await file.length();

    await file.openRead().forEach((chunk) => request.sink.add(chunk));

    /// Not awaited: the close completes only once `request.send()` drains the
    /// stream, so awaiting it here would hang.
    unawaited(request.sink.close());

    return Response.fromStream(await request.send());
  }

  /// The `Location` a GET to [uri] redirects to, without following it.
  ///
  /// `null` when the response is not a redirect or the request fails.
  Future<String?> catchRedirect({
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    try {
      final request = Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll(headers);

      final StreamedResponse response = await _client
          .send(request)
          .timeout(normalTimeout);

      return response.isRedirect ? response.headers['location'] : null;
    } on TimeoutException {
      logInfo(info: 'Catch redirect $uri\nTimeout exception');
      notify(NetworkConnectionLost());
      return null;
    } on SocketException catch (error) {
      logInfo(info: 'Catch redirect $uri\nNo connection (${error.message})');
      notify(NetworkConnectionLost());
      return null;
    } on HandshakeException catch (error) {
      logError(error: 'Catch redirect $uri\n${error.message}');
      notify(NetworkConnectionLost());
      return null;
    } on ClientException catch (error) {
      /// See the note in [sendBase]: this is the web-side shape of a failed
      /// connection.
      logInfo(info: 'Catch redirect $uri\nNo connection (${error.message})');
      notify(NetworkConnectionLost());
      return null;
    } catch (error) {
      logError(error: 'Catch redirect $uri\n$error');
      return null;
    }
  }
}
