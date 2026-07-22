import 'dart:async';
// TODO(Alex): избавиться?
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

/// Extended class should be a singleton
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

  // Optimize(Alex): попробовать заменить на RetryClient для автоматического
  // перезапроса в случае ошибок https://pub.dev/packages/http#retrying-requests
  // Настроить обработку ошибок - как минимум исключить 401.
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

  ///
  @mustBeOverridden
  Uri prepareUri({required String path});

  /// Return **null** only if got error with unified application behaviour
  /// via **errorSubject** stream (for example - `no connection` or
  /// `need authorization` errors), so it's not necessary to do something
  /// special in this case.
  ///
  /// Otherwise return **Response** with necessary information.
  ///
  /// [extraExpectedStatusList] widens [RequestType.expectedStatusList] for this
  /// single call, so a caller can take over a status the unified path would
  /// otherwise swallow — typically a 401 it wants to answer with a token
  /// refresh. It is a per-call concern, not a property of the request, so it
  /// is passed here instead of being written into [request].
  Future<ResponseEntity?> sendBase({
    required RequestType request,
    required Map<String, String> headers,
    List<int> extraExpectedStatusList = const [],
  }) async {
    try {
      ///
      final Uri uri = prepareUri(path: request.path);

      ///
      final List<int> expectedStatusList = extraExpectedStatusList.isEmpty
          ? request.expectedStatusList
          : [...request.expectedStatusList, ...extraExpectedStatusList];

      /// Log request
      logRequestInfo(
        request: request,
        body: request.body?.toString(),
        info: 'Sending',
      );

      /// Prepare response
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

      /// Send request
      final Response httpResponse = await futureResponse.timeout(
        timeoutFor(request.durationType),
      );

      /// Get response
      final response = ResponseEntity(
        request: '${request.type} $uri',
        body: httpResponse.body,
        statusCode: httpResponse.statusCode,
      );

      /// Check it
      if (!expectedStatusList.contains(httpResponse.statusCode)) {
        /// Some error happened, log it
        logResponseError(response: response);

        if (httpResponse.statusCode == HttpStatus.unauthorized) {
          // To apply custom behaviour on unathorized response (for example to
          // refresh access token) add unauthorized status code to
          // expectedStatusList and check response manually (do not forget to
          // call `onUnauthorized` to notify `NetworkSubject`)
          notifyUnauthorized();
          return null;
        }
        if (httpResponse.statusCode == HttpStatus.gatewayTimeout) {
          notify(NetworkConnectionLost());
          return null;
        }

        /// Try to get expected error type
        final NetworkEvent? expectedErrorType =
            request.expectedErrorMap[httpResponse.statusCode];
        if (expectedErrorType != null) {
          /// Custom handler
          notify(expectedErrorType, silence: request.silence);
          return null;
        }

        /// Handle it as unexpected response
        notify(NetworkUnexpectedResponse(), silence: request.silence);
        return null;
      }

      /// Expected response, just log it, notify and return
      logResponseInfo(response: response);
      notify(NetworkSuccess(), silence: request.silence);
      return response;
    } on TimeoutException {
      /// Request didn't complete in time — treat it the same way as a lost
      /// connection: backend is effectively unreachable from the user's
      /// perspective, so switch to offline mode. Bypass the `silence` flag
      /// because connection state is global.
      logRequestInfo(request: request, info: 'Timeout exception');
      notify(NetworkConnectionLost());
    } on SocketException catch (error) {
      /// SocketException means we could not even establish a socket
      /// (DNS lookup failure, route unreachable, connection refused, etc.).
      /// This is the typical signal of a connection problem when, for example,
      /// Wi-Fi reports as "available" but the upstream router blocks Internet
      /// or DNS resolution. Activate offline mode regardless of the silence
      /// flag — connection state is global and must not be hidden by silenced
      /// requests (e.g. ping).
      logRequestInfo(
        request: request,
        info: 'No connection (${error.message})',
      );
      notify(NetworkConnectionLost());
    } on HandshakeException catch (error) {
      /// SSL problem on backend side, need to activate offline mode
      logRequestError(request: request, error: error.message);
      notify(NetworkConnectionLost());
    } catch (error) {
      /// Something is crashed
      logRequestError(request: request, error: error.toString());
      notify(NetworkUnexpectedError(), silence: request.silence);
    }
    return null;
  }

  /// Just notify subjects
  void notifyUnauthorized() => notify(NetworkUnauthorized());

  ///
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
    /// Prepearing request
    final request = MultipartRequest('POST', uri);

    /// Add body data
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

    /// Add headers
    request.headers.addAll(headers);
    if (isWebBased) {
      /// Keep uploads away from any intermediate cache.
      ///
      /// `Content-Type` is deliberately not set here: [MultipartRequest]
      /// writes its own `multipart/form-data` value with the generated
      /// boundary in `finalize()`, and any value set earlier is overwritten.
      request.headers['Cache-Control'] = 'no-cache';
    }

    /// Add files
    ///
    /// A sequential loop, not `Map.forEach`: the body is asynchronous and
    /// `forEach` discards the futures it gets back, so the request used to be
    /// sent before the files were attached.
    for (final MapEntry<String, XFile> entry in requestData.files.entries) {
      if (isMobileBased) {
        /// Mobile
        request.files.add(
          await MultipartFile.fromPath(entry.key, entry.value.path),
        );
      } else {
        /// Web - need to use fromBytes instead of fromPath
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

    /// Sending request
    return Response.fromStream(await request.send());
  }

  // TODO(SH): Tested on mobile devices only, need to test on other platforms
  Future<Response> _sendPostFile({
    required Uri uri,
    required Map<String, String> headers,
    required RequestPostFile requestData,
  }) async {
    /// Prepare data
    final XFile file = requestData.file;

    /// Prepearing request
    final request = StreamedRequest('POST', uri);

    /// Add headers
    request.headers.addAll(headers);
    request.headers['Content-Type'] = 'application/octet-stream';
    request.contentLength = await file.length();

    /// Write chunks to request
    await file.openRead().forEach((chunk) => request.sink.add(chunk));

    /// Close sink without awaiting, otherwise request will not be sended
    unawaited(request.sink.close());

    /// Sending request
    return Response.fromStream(await request.send());
  }

  /// **null** on error
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
    } catch (error) {
      logError(error: 'Catch redirect $uri\n$error');
      return null;
    }
  }
}
