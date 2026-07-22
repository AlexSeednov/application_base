///
final class ResponseEntity {
  ///
  ResponseEntity({
    required this.body,
    required this.request,
    required this.statusCode,
  });

  ///
  final String body;

  ///
  final String request;

  ///
  final int statusCode;

  /// Success status code
  bool get isOk => statusCode >= 200 && statusCode < 300;

  /// Every status outside the 2xx range
  bool get isNotOk => !isOk;
}
