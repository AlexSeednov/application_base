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
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();

  ///
  final NetworkSubject _networkSubject = getIt<NetworkSubject>();

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
  bool _isPingInProgress = false;

  ///
  Future<void> prepare() async {
    if (_subscription != null) return;
    _subscription = _networkSubject.listen(onUpdate);

    await _connectivityService.prepare();

    /// Without connectivity offline will be activated automatically
    if (!_connectivityService.isConnectivityAvailable) return;

    ///
    final bool? result = await _checkBackendAvailability();
    if (result == false) _activateOfflineMode();
  }

  ///
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;

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
    _timer?.cancel();
    _timer = null;

    if (isOnline) return;

    /// Turn the offline mode on
    isOnlineNotifier.value = true;

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
    final bool? result = await _checkBackendAvailability();
    if (result == null) return;

    if (!result) {
      logInfo(info: 'Ping failed');
      _activateOfflineMode();
      return;
    }

    /// Send connection restore event to provide information about it for
    /// all listeners, include this one
    _networkSubject.add(NetworkRestore());
  }

  /// Return
  ///   * `null` if ping is already in progress
  ///   * `true` if backend is available
  ///   * `false` otherwise.
  Future<bool?> _checkBackendAvailability() async {
    if (_isPingInProgress) return null;

    _isPingInProgress = true;

    /// [sendPingRequest] implementation may be not safe, so we need to catch
    /// all possible errors here to prevent crashes.
    try {
      return await sendPingRequest();
    } catch (error) {
      logError(error: 'Ping request failed', additional: error.toString());
      return false;
    } finally {
      _isPingInProgress = false;
    }
  }

  ///
  void _confirmConnectionRestore() {
    logInfo(info: 'Connectivity available in offline mode, pinging backend');
    unawaited(ping());
  }

  ///
  @mustBeOverridden
  @mustCallSuper
  void onUpdate(NetworkEvent event) => switch (event) {
    /// Success
    NetworkSuccess() => _onlineMode(),

    /// Connectivity
    NetworkConnectionAvailable() when isOffline => _confirmConnectionRestore(),

    /// Connection
    NetworkRestore() => _deactivateOfflineMode(),
    NetworkConnectionLost() => _activateOfflineMode(),

    /// All others don't matter here; they will be handled in the overridden
    /// function.
    _ => {},
  };

  ///
  bool get isWiFi => getIt<ConnectivityService>().isWiFi;
}
