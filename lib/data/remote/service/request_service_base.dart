import 'dart:async';
// TODO(Alex): избавиться?
import 'dart:io';
import 'dart:typed_data';

import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:application_base/data/remote/service/network_logger_service.dart';
import 'package:application_base/data/remote/service/request_timeout_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

// TODO(Alex): временные константы из RequestTimeoutService и
// NetworkServiceBase перенести в этот класс - тогда при создании наследника
// этого класса можно будет просто переопределить константы при необходимости,
// а без переопределения будут использоваться дефолтные, как сейчас
///
/// Extended class should be a singleton
abstract base class RequestServiceBase {
  // Optimize(Alex): попробовать заменить на RetryClient для автоматического
  // перезапроса в случае ошибок https://pub.dev/packages/http#retrying-requests
  // Настроить обработку ошибок - как минимум исключить 401.
  /// https://dart.dev/tutorials/server/fetch-data#make-multiple-requests
  Client _client = Client();

  ///
  set client(Client newValue) => _client = newValue;

  ///
  final _networkSubject = getIt<NetworkSubject>();

  ///
  @mustBeOverridden
  Uri prepareUri({required String path});

  /// Return **null** only if got error with unified application behaviour
  /// via **errorSubject** stream (for example - `no connection` or
  /// `need authorization` errors), so it's not necessary to do something
  /// special in this case.
  ///
  /// Otherwise return **Response** with necessary information.
  Future<ResponseEntity?> sendBase({
    required RequestType request,
    required Map<String, String> headers,
  }) async {
    try {
      ///
      final Uri uri = prepareUri(path: request.path);

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
        RequestTimeoutService.timeout(request.durationType),
      );

      /// Get response
      final response = ResponseEntity(
        request: '${request.type} $uri',
        body: httpResponse.body,
        statusCode: httpResponse.statusCode,
      );

      /// Check it
      if (!request.expectedStatusList.contains(httpResponse.statusCode)) {
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
      /// Time is out
      logRequestInfo(request: request, info: 'Timeout exception');
      notify(NetworkRequestTimeout(), silence: request.silence);
    } on SocketException catch (error) {
      if (error.message.contains('Failed host lookup')) {
        /// Only on Android, iOS send timeout exception
        logRequestInfo(request: request, info: 'No connection');
        // Information(Alex): По факту здесь должно быть noConnection, но его
        // используем только для включения офлайн режима,
        // тогда как здесь этого делать не нужно
        notify(NetworkRequestTimeout(), silence: request.silence);
      } else {
        ///
        logRequestError(
          request: request,
          error: 'Socket exception ${error.message}',
        );
        notify(NetworkUnexpectedError(), silence: request.silence);
      }
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
      /// And special header for web compatibility
      request.headers['Access-Control-Allow-Origin'] = '*';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }

    /// Add file
    requestData.files.forEach((String field, XFile file) async {
      if (isMobileBased) {
        /// Mobile
        request.files.add(await MultipartFile.fromPath(field, file.path));
      } else {
        /// Web - need to use fromBytes instead of fromPath
        final Uint8List fileBytes = await file.readAsBytes();
        request.files.add(
          MultipartFile.fromBytes(field, fileBytes, filename: file.name),
        );
      }
    });

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
    final request = Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll(headers);

    final response = await _client.send(request);

    return response.isRedirect ? response.headers['location'] : null;
  }
}
