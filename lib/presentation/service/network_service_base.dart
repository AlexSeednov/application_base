import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// Extended class should be a singleton
abstract base class NetworkServiceBase {
  /// Default period between background reachability pings while in offline
  /// mode. Subclasses may override [pingPeriod] to tune this for the concrete
  /// application (e.g. shorter for media-heavy apps that need a quick switch
  /// back to online).
  static const defaultPingPeriod = Duration(seconds: 30);

  /// Period between background reachability pings while in offline mode.
  /// Override in a subclass to customize.
  Duration get pingPeriod => defaultPingPeriod;

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

  /// Guard against concurrent timeout-triggered ping checks
  bool _timeoutCheckInProgress = false;

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
    if (isOffline) return;

    /// Turn the offline mode on
    isOnlineNotifier.value = false;

    _timer ??= Timer.periodic(pingPeriod, (_) => ping());

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

    /// Timeout may indicate either a slow backend or a silently dropped
    /// connection (e.g. iOS does not surface DNS failures as SocketException —
    /// it reports them as TimeoutException). Confirm reachability with a
    /// short ping and switch to offline mode if it fails.
    NetworkRequestTimeout() => _checkReachabilityAfterTimeout(),

    /// All others don't matter here; they will be handled in the overridden
    /// function.
    _ => {},
  };

  /// Performs a single ping when a request times out. If the backend remains
  /// unreachable, activates offline mode. Skipped while already offline (the
  /// periodic timer handles that case) or if a check is already running.
  Future<void> _checkReachabilityAfterTimeout() async {
    if (isOffline) return;
    if (_timeoutCheckInProgress) return;
    _timeoutCheckInProgress = true;
    try {
      final bool result = await sendPingRequest();
      if (!result && isOnline) _activateOfflineMode();
    } finally {
      _timeoutCheckInProgress = false;
    }
  }

  ///
  bool get isWiFi => getIt<ConnectivityService>().isWiFi;
}
