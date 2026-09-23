/// An outcome of a request or a change of the connection, published through
/// `NetworkSubject`.
sealed class NetworkEvent {
  ///
  NetworkEvent({this.data});

  /// A payload for the listener to tell events of one type apart.
  final Object? data;
}

/// A response with an expected status.
final class NetworkSuccess extends NetworkEvent {
  ///
  NetworkSuccess({super.data});
}

/// The backend answers again; turns the offline mode off.
final class NetworkRestore extends NetworkEvent {
  ///
  NetworkRestore({super.data});
}

/// Network interface is available, but backend availability is not confirmed.
final class NetworkConnectionAvailable extends NetworkEvent {
  ///
  NetworkConnectionAvailable({super.data});
}

/// No Internet or the backend is unreachable; turns the offline mode on.
///
/// Also emitted on a timeout, a 504 and an SSL failure: for the user each is
/// the same temporary loss of connection.
final class NetworkConnectionLost extends NetworkEvent {
  ///
  NetworkConnectionLost({super.data});
}

/// Got 401 HTTP status.
final class NetworkUnauthorized extends NetworkEvent {
  ///
  NetworkUnauthorized({super.data});
}

/// Got 404 HTTP status.
///
/// Emitted only through `RequestType.expectedErrorMap`: an unmapped 404
/// arrives as [NetworkUnexpectedResponse].
final class NetworkNotFound extends NetworkEvent {
  ///
  NetworkNotFound({super.data});
}

/// A response whose status is neither expected nor mapped to an event.
final class NetworkUnexpectedResponse extends NetworkEvent {
  ///
  NetworkUnexpectedResponse({super.data});
}

/// Sending failed with an error that is not a connection problem.
final class NetworkUnexpectedError extends NetworkEvent {
  ///
  NetworkUnexpectedError({super.data});
}

/// A project-specific event, e.g. an outdated-client status mapped through
/// `RequestType.expectedErrorMap`.
final class NetworkCustomEvent extends NetworkEvent {
  ///
  NetworkCustomEvent({super.data});
}
