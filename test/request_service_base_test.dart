import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/const/request_type.dart';
import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:application_base/data/remote/service/request_service_base.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

/// Uploads go through the client the application set, like every other
/// request: a wrapper that watches statuses for the whole application — an
/// outdated-client check, say — must see them too. The file body reaches the
/// server whole although it is streamed.
void main() {
  ///
  late _RequestService service;

  ///
  late List<BaseRequest> sent;

  ///
  late List<int> body;

  setUp(() {
    getIt.registerLazySingleton<NetworkSubject>(NetworkSubject.new);
    sent = [];
    body = [];
    service = _RequestService()
      ..client = MockClient.streaming((request, bodyStream) async {
        sent.add(request);
        body = await bodyStream.toBytes();
        return StreamedResponse(Stream.value(const <int>[]), 200);
      });
  });

  tearDown(() async {
    service.dispose();
    await getIt.reset();
  });

  test('a file upload streams the whole file through the client', () async {
    final bytes = Uint8List.fromList(List<int>.generate(100000, (i) => i));

    final ResponseEntity? response = await service.sendBase(
      request: RequestPostFile(path: 'upload', file: XFile.fromData(bytes)),
      headers: const {},
    );

    expect(response?.statusCode, 200);
    expect(sent.single.contentLength, bytes.length);
    expect(sent.single.headers['Content-Type'], 'application/octet-stream');
    expect(body, bytes);
  });

  test('a form upload goes through the client', () async {
    final ResponseEntity? response = await service.sendBase(
      request: RequestPostFormData(path: 'upload', body: const {'a': 1}),
      headers: const {},
    );

    expect(response?.statusCode, 200);
    expect(sent.single, isA<MultipartRequest>());
  });

  /// A request repeated on a timer turns its routine lines off, so the log
  /// keeps only what tells a story: its failures.
  group('logging', () {
    test('a request logs its sending and its response by default', () async {
      final String log = await _logOf(
        () => service.sendBase(
          request: RequestGet(path: 'messages'),
          headers: const {},
        ),
      );

      expect(log, contains('Sending'));
      expect(log, contains('Response 200'));
    });

    test('a request with logging off leaves no line on success', () async {
      final String log = await _logOf(
        () => service.sendBase(
          request: RequestGet(path: 'messages', logging: false),
          headers: const {},
        ),
      );

      expect(log, isEmpty);
    });

    test('a request with logging off still logs its failure', () async {
      service.client = MockClient((_) async => Response('', 500));

      final String log = await _logOf(
        () => service.sendBase(
          request: RequestGet(path: 'messages', logging: false),
          headers: const {},
        ),
      );

      expect(log, isNot(contains('Sending')));
      expect(log, contains('Response 500'));
    });
  });

  /// Back from the background, the first request may go into a keep-alive
  /// connection the server closed long ago. A GET gets one more attempt on a
  /// fresh one; anything else could apply twice and is never repeated.
  group('broken connection', () {
    ///
    late int attemptCount;

    ///
    late List<NetworkEvent> events;

    setUp(() {
      attemptCount = 0;
      events = [];
      getIt<NetworkSubject>().listen(events.add);
    });

    /// Lets the subject deliver what was added.
    Future<void> delivered() => Future<void>.delayed(Duration.zero);

    test('a GET is sent once more and succeeds', () async {
      service.client = MockClient((_) async {
        attemptCount++;
        if (attemptCount == 1) {
          throw ClientException(
            'Connection closed before full header was received',
          );
        }
        return Response('', 200);
      });

      final ResponseEntity? response = await service.sendBase(
        request: RequestGet(path: 'messages'),
        headers: const {},
      );
      await delivered();

      expect(response?.statusCode, 200);
      expect(attemptCount, 2);
      expect(events.whereType<NetworkConnectionLost>(), isEmpty);
    });

    test('a GET failing twice reports one lost connection', () async {
      service.client = MockClient((_) {
        attemptCount++;
        throw const SocketException('Connection reset by peer');
      });

      final ResponseEntity? response = await service.sendBase(
        request: RequestGet(path: 'messages'),
        headers: const {},
      );
      await delivered();

      expect(response, isNull);
      expect(attemptCount, 2);
      expect(events.whereType<NetworkConnectionLost>(), hasLength(1));
    });

    test('a POST is never repeated', () async {
      service.client = MockClient((_) {
        attemptCount++;
        throw const SocketException('Connection reset by peer');
      });

      final ResponseEntity? response = await service.sendBase(
        request: RequestPost(path: 'messages', body: '{}'),
        headers: const {},
      );

      expect(response, isNull);
      expect(attemptCount, 1);
    });

    test('a failure that is not a connection is not repeated', () async {
      service.client = MockClient((_) {
        attemptCount++;
        throw const FormatException('Malformed');
      });

      await service.sendBase(
        request: RequestGet(path: 'messages'),
        headers: const {},
      );

      expect(attemptCount, 1);
    });

    test('a redirect is caught on the second attempt', () async {
      service.client = MockClient((_) async {
        attemptCount++;
        if (attemptCount == 1) {
          throw const SocketException('Connection reset by peer');
        }
        return Response(
          '',
          302,
          headers: const {'location': 'https://cdn.example.com/video'},
          isRedirect: true,
        );
      });

      final String? location = await service.catchRedirect(
        uri: Uri.parse('https://example.com/video'),
        headers: const {},
      );

      expect(location, 'https://cdn.example.com/video');
      expect(attemptCount, 2);
    });
  });
}

/// Everything the console logger printed while [body] ran.
Future<String> _logOf(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines.join('\n');
}

/// Every path under one test host, a retry without the pause.
final class _RequestService extends RequestServiceBase {
  ///
  @override
  Duration get retryDelay => Duration.zero;

  ///
  @override
  Uri prepareUri({required String path}) =>
      Uri.parse('https://example.com/$path');
}
