import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository reads a body only from a response that exists and is a
/// success; anything else is its "no result", with no parsing attempted.
void main() {
  ///
  ResponseEntity response(int statusCode) => ResponseEntity(
    body: '42',
    request: 'GET /answer',
    statusCode: statusCode,
  );

  group('parsedOrNull', () {
    test('parses the body of a success', () {
      expect(response(200).parsedOrNull((data) => int.parse(data.body)), 42);
    });

    test('never parses a failure or a missing response', () {
      var parsed = 0;
      int count(ResponseEntity _) => ++parsed;

      expect(response(404).parsedOrNull(count), isNull);
      expect((null as ResponseEntity?).parsedOrNull(count), isNull);
      expect(parsed, 0);
    });
  });

  group('isOkOrFalse', () {
    test('is true for any 2xx', () {
      expect(response(204).isOkOrFalse, isTrue);
    });

    test('is false for a failure and for a missing response', () {
      expect(response(500).isOkOrFalse, isFalse);
      expect((null as ResponseEntity?).isOkOrFalse, isFalse);
    });
  });
}
