import 'dart:async';

import 'package:application_base/data/remote/const/network_event.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

export 'package:application_base/data/remote/const/network_event.dart';

/// The application-wide bus of [NetworkEvent]s: requests, connectivity and
/// the offline mode publish here.
@lazySingleton
final class NetworkSubject {
  ///
  @visibleForTesting
  NetworkSubject();

  /// A [PublishSubject]: a late listener gets no past events.
  final _networkSubject = PublishSubject<NetworkEvent>();

  ///
  @disposeMethod
  void dispose() {
    unawaited(_networkSubject.close());
  }

  ///
  StreamSubscription<NetworkEvent> listen(void Function(NetworkEvent) onData) =>
      _networkSubject.listen(onData);

  ///
  StreamSubscription<NetworkEvent> listenConnectionRestore(
    void Function() onData,
  ) => _networkSubject
      .where((type) => type is NetworkRestore)
      .listen((_) => onData());

  ///
  void add(NetworkEvent entity) => _networkSubject.add(entity);
}
