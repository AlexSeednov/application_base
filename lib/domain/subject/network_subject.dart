import 'dart:async';

import 'package:application_base/data/remote/const/network_event.dart';
import 'package:rxdart/rxdart.dart';

export 'package:application_base/data/remote/const/network_event.dart';

///
final class NetworkSubject {
  ///
  NetworkSubject._();

  ///
  factory NetworkSubject.singleton() => _instance;

  ///
  static final _instance = NetworkSubject._();

  ///
  final _networkSubject = PublishSubject<NetworkEvent>();

  ///
  void dispose() {
    _networkSubject.close();
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
