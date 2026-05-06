///
sealed class NetworkEvent {
  ///
  NetworkEvent({this.data});

  ///
  final Object? data;
}

/// Request sent successfully, got response with expected status code
final class NetworkSuccess extends NetworkEvent {
  ///
  NetworkSuccess({super.data});
}

/// Internet or backend connection successfully restore
final class NetworkRestore extends NetworkEvent {
  ///
  NetworkRestore({super.data});
}

/// Network interface is available, but backend availability is not confirmed.
final class NetworkConnectionAvailable extends NetworkEvent {
  ///
  NetworkConnectionAvailable({super.data});
}

/// There is no internet connection or backend is down. Also emitted on
/// request timeouts — a timeout from the backend is treated as a temporary
/// loss of connection and triggers the offline mode.
final class NetworkConnectionLost extends NetworkEvent {
  ///
  NetworkConnectionLost({super.data});
}

/// Got 401 HTTP status
final class NetworkUnauthorized extends NetworkEvent {
  ///
  NetworkUnauthorized({super.data});
}

/// Got 404 HTTP status
final class NetworkNotFound extends NetworkEvent {
  ///
  NetworkNotFound({super.data});
}

/// Got a response with unexpected HTTP status
final class NetworkUnexpectedResponse extends NetworkEvent {
  ///
  NetworkUnexpectedResponse({super.data});
}

/// Got an error while sending request
final class NetworkUnexpectedError extends NetworkEvent {
  ///
  NetworkUnexpectedError({super.data});
}

///
final class NetworkCustomEvent extends NetworkEvent {
  ///
  NetworkCustomEvent({super.data});
}
