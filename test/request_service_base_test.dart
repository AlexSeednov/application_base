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
}

/// Every path under one test host.
final class _RequestService extends RequestServiceBase {
  ///
  @override
  Uri prepareUri({required String path}) =>
      Uri.parse('https://example.com/$path');
}
