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

  /// The request it answers, as `METHOD url`, for the logs.
  final String request;

  ///
  final int statusCode;

  /// Any 2xx.
  bool get isOk => statusCode >= 200 && statusCode < 300;

  /// Every status outside the 2xx range
  bool get isNotOk => !isOk;
}
