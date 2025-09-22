import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// Extended class should be a singleton
abstract base class NetworkServiceBase {
  ///
  static const _pingPeriod = Duration(seconds: 60);

  ///
  final _connectivityService = getIt<ConnectivityService>();

  ///
  final _networkSubject = getIt<NetworkSubject>();

  ///
  StreamSubscription<NetworkEvent>? _subscription;

  ///
  final isOnlineNotifier = ValueNotifier<bool>(true);

  ///
  bool get isOnline => isOnlineNotifier.value;

  ///
  bool get isOffline => !isOnline;

  /// Timer for background connection restore checker
  Timer? _timer;

  ///
  Future<void> prepare() async {
    if (_subscription != null) return;
    _subscription = _networkSubject.listen(onUpdate);

    await _connectivityService.prepare();
    if (!_connectivityService.isConnectivityAvailable) return;

    ///
    final bool result = await sendPingRequest();
    if (!result) _activateOfflineMode();
  }

  ///
  void dispose() {
    _connectivityService.dispose();

    _subscription?.cancel();

    _timer?.cancel();
    _timer = null;
  }

  ///
  void _activateOfflineMode() {
    /// Turn the offline mode on
    isOnlineNotifier.value = false;

    _timer ??= Timer.periodic(_pingPeriod, (_) => ping());

    logInfo(info: 'Offline mode activated');
  }

  ///
  void _deactivateOfflineMode() {
    /// Turn the offline mode on
    isOnlineNotifier.value = true;

    _timer?.cancel();
    _timer = null;

    logInfo(info: 'Offline mode deactivated');
  }

  ///
  void _onlineMode() {
    if (isOnline) return;

    /// Send connection restore event to provide information about it for
    /// all listeners, include this one
    _networkSubject.add(NetworkRestore());
  }

  ///
  @mustBeOverridden
  Future<bool> sendPingRequest();

  ///
  Future<void> ping() async {
    ///
    final bool result = await sendPingRequest();
    if (result) {
      /// Send connection restore event to provide information about it for
      /// all listeners, include this one
      _networkSubject.add(NetworkRestore());
    }
  }

  ///
  @mustBeOverridden
  @mustCallSuper
  void onUpdate(NetworkEvent event) => switch (event) {
    /// Success
    NetworkSuccess() => _onlineMode(),

    /// Connection
    NetworkRestore() => _deactivateOfflineMode(),
    NetworkConnectionLost() => _activateOfflineMode(),

    /// All other doesn't metter here, will be handled in overriden function
    _ => {},
  };

  ///
  bool get isWiFi => getIt<ConnectivityService>().isWiFi;
}
