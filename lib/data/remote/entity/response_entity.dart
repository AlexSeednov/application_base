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

/// The check every repository method makes before it reads a response: a
/// response exists and is a success. A failure has already been reported to
/// `NetworkSubject` by then, so the method only returns its "no result".
extension ResponseEntityParsing on ResponseEntity? {
  /// The body parsed with [parse] when the response is a success; `null` when
  /// there is no response or its status is not 2xx.
  T? parsedOrNull<T>(T? Function(ResponseEntity data) parse) {
    final response = this;
    if (response == null || response.isNotOk) return null;
    return parse(response);
  }

  /// Whether the response is a success; `false` when there is none. For a
  /// request whose body nobody reads — sending a code, signing out.
  bool get isOkOrFalse => this?.isOk ?? false;
}
