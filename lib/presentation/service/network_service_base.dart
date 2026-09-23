import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

/// Online / offline state of the application, decided by the backend rather
/// than by the network interface: a link the system reports may still lead
/// nowhere — Wi-Fi without Internet, a captive portal, a backend that is down.
///
/// Extend it once, as a singleton: every instance subscribes to
/// [NetworkSubject] and runs a ping timer of its own, so a second one would
/// announce every restore twice.
abstract base class NetworkServiceBase {
  /// Default of [pingPeriod].
  static const defaultPingPeriod = Duration(seconds: 30);

  /// Period between background reachability pings while in offline mode.
  ///
  /// Override it to tune the switch back to online — shorter for a
  /// media-heavy application that needs it quick, say. Read when the offline
  /// mode starts, so a change applies from the next one.
  Duration get pingPeriod => defaultPingPeriod;

  ///
  final ConnectivityService _connectivityService = getIt<ConnectivityService>();

  ///
  final NetworkSubject _networkSubject = getIt<NetworkSubject>();

  ///
  StreamSubscription<NetworkEvent>? _subscription;

  /// Starts `true`: the application counts as online until a lost connection
  /// or a failed ping says otherwise.
  final isOnlineNotifier = ValueNotifier<bool>(true);

  ///
  bool get isOnline => isOnlineNotifier.value;

  ///
  bool get isOffline => !isOnline;

  /// Runs [ping] every [pingPeriod] while offline; `null` otherwise.
  Timer? _timer;

  ///
  bool _isPingInProgress = false;

  /// Subscribes to [NetworkSubject], starts watching the interface and pings
  /// the backend once; repeated calls are no-ops.
  ///
  /// Call it when the request service is ready: the start-up ping goes
  /// through it.
  Future<void> prepare() async {
    if (_subscription != null) return;
    /// Subscribed before the interface is read: its first reading goes out
    /// on the subject, which replays nothing to a late listener.
    _subscription = _networkSubject.listen(onUpdate);

    await _connectivityService.prepare();

    /// No link: the interface's own `NetworkConnectionLost` turns the
    /// offline mode on, and a ping would have nothing to go through.
    if (!_connectivityService.isConnectivityAvailable) return;

    /// A link proves nothing: the offline mode starts if the backend does not
    /// answer.
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

  /// A no-op while already offline: every failed request reports a lost
  /// connection, and one offline mode needs one timer and one log line.
  void _activateOfflineMode() {
    if (isOffline) return;

    isOnlineNotifier.value = false;

    _timer ??= Timer.periodic(pingPeriod, (_) => ping());

    logInfo(info: 'Offline mode activated');
  }

  /// Cancels the ping timer even when already online, so a timer cannot
  /// outlive the offline mode.
  void _deactivateOfflineMode() {
    _timer?.cancel();
    _timer = null;

    if (isOnline) return;

    isOnlineNotifier.value = true;

    logInfo(info: 'Offline mode deactivated');
  }

  /// Any request that got an expected response proves the backend
  /// reachable.
  void _onlineMode() {
    if (isOnline) return;

    /// The restore goes out through the subject, so every listener, this
    /// service included, learns of it from one event.
    _networkSubject.add(NetworkRestore());
  }

  /// Whether the backend answers.
  ///
  /// Send the request silent: a request that reports its own success
  /// announces the restore a second time. Whatever it throws counts as no
  /// answer.
  @mustBeOverridden
  Future<bool> sendPingRequest();

  /// Asks the backend whether it is reachable and moves the offline mode to
  /// match.
  ///
  /// Runs on the offline timer, when a link comes back, and on demand — a
  /// retry button, say. A success announces [NetworkRestore] whatever the
  /// current state; a call while another ping runs is skipped and leaves the
  /// outcome to that one.
  Future<void> ping() async {
    final bool? result = await _checkBackendAvailability();
    if (result == null) return;

    if (!result) {
      logInfo(info: 'Ping failed');
      _activateOfflineMode();
      return;
    }

    /// Through the subject, as in `_onlineMode`.
    _networkSubject.add(NetworkRestore());
  }

  /// `true` when the backend answers, `false` when it does not, and `null`
  /// when a ping is already running: one ping at a time, so the timer, a
  /// returning link and a manual retry never double up.
  Future<bool?> _checkBackendAvailability() async {
    if (_isPingInProgress) return null;

    _isPingInProgress = true;

    /// [sendPingRequest] is application code: whatever it throws counts as an
    /// unreachable backend rather than escaping as an unhandled error.
    try {
      return await sendPingRequest();
    } catch (error) {
      logError(error: 'Ping request failed', additional: error.toString());
      return false;
    } finally {
      _isPingInProgress = false;
    }
  }

  /// A returning link proves nothing while offline — Wi-Fi without
  /// Internet, a captive portal — so the backend has to confirm it.
  void _confirmConnectionRestore() {
    logInfo(info: 'Connectivity available in offline mode, pinging backend');
    unawaited(ping());
  }

  /// Drives the offline mode from every event on [NetworkSubject].
  ///
  /// The subclass handles the rest — a [NetworkUnauthorized], say — and calls
  /// super, which the offline mode depends on.
  @mustBeOverridden
  @mustCallSuper
  void onUpdate(NetworkEvent event) => switch (event) {
    NetworkSuccess() => _onlineMode(),

    NetworkConnectionAvailable() when isOffline => _confirmConnectionRestore(),

    NetworkRestore() => _deactivateOfflineMode(),
    NetworkConnectionLost() => _activateOfflineMode(),

    /// The rest belongs to the subclass.
    _ => {},
  };

  ///
  bool get isWiFi => getIt<ConnectivityService>().isWiFi;
}
