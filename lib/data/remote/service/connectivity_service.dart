import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:meta/meta.dart';

/// Tracks the device's network links and reports them to [NetworkSubject].
///
/// Since Android 8 the change stream is silent in the background, so call
/// [getConnectivity] when the app resumes. On iOS simulators the stream may
/// miss Wi-Fi changes.
@lazySingleton
final class ConnectivityService {
  ///
  @visibleForTesting
  ConnectivityService(this._connectionSubject);

  ///
  final NetworkSubject _connectionSubject;

  ///
  final List<ConnectivityResult> _connectivityList = [];

  ///
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Pending re-check of a link reported as lost.
  Timer? _timer;

  /// How long a lost link waits before it is confirmed.
  final Duration _timerDelay = const Duration(seconds: 3);

  /// Set by [dispose], cleared by [prepare]: a re-check whose reading was
  /// still in flight must not publish to a disposed subject.
  bool _isDisposed = false;

  /// Any transport other than [ConnectivityResult.none] counts as a link.
  ///
  /// Deliberately not a white-list of `mobile`/`wifi`/`ethernet`: on iOS and
  /// macOS a VPN has no dedicated interface type and is reported as
  /// [ConnectivityResult.other], so a white-list drops the app into offline
  /// mode while the network is perfectly usable. The same applies to
  /// `bluetooth` and `satellite`.
  ///
  /// This is only a cheap gate on whether a link exists at all — whether the
  /// backend is actually reachable is decided by the ping in
  /// `NetworkServiceBase`.
  bool get isConnectivityAvailable =>
      _connectivityList.any((result) => result != ConnectivityResult.none);

  ///
  bool get isWiFi => _connectivityList.contains(ConnectivityResult.wifi);

  /// Idempotent: a second call keeps the existing subscription.
  Future<void> prepare() async {
    if (_subscription != null) return;
    _isDisposed = false;
    _subscription = Connectivity().onConnectivityChanged.listen(_onUpdate);
    await getConnectivity();
  }

  ///
  @disposeMethod
  void dispose() {
    _isDisposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;

    _timer?.cancel();
    _timer = null;
  }

  /// Re-reads the links. A link found is published at once; no link goes
  /// through the same delayed re-check as a stream update — back from the
  /// background is exactly when Android answers "none" for a network it has
  /// not unblocked yet.
  Future<void> getConnectivity() async {
    await _read();

    if (isConnectivityAvailable) {
      _timer?.cancel();
      _timer = null;
      _check();
      return;
    }

    _scheduleRecheck();
  }

  ///
  Future<void> _read() async {
    final List<ConnectivityResult> actualConnectivityList = await Connectivity()
        .checkConnectivity();

    _connectivityList
      ..clear()
      ..addAll(actualConnectivityList);
  }

  /// A loss is published only if a fresh reading after [_timerDelay] still
  /// finds no link. On iOS 12+ the plugin relies on `NWPathMonitor`, which
  /// can report "none" and then "wifi" right after a reconnect. On Android it
  /// asks `getActiveNetwork()`, which answers "none" for a network that is
  /// only blocked for the app — in Doze or App Standby — until the block is
  /// lifted on the return to the foreground.
  ///
  /// A fresh reading rather than the last one: the plugin does not report a
  /// lifted block, and a stale "none" delivered from the background would
  /// otherwise stand.
  void _scheduleRecheck() {
    logInfo(info: 'Connectivity became not available, will check it');

    _timer?.cancel();
    _timer = Timer(_timerDelay, () => unawaited(_recheck()));
  }

  ///
  Future<void> _recheck() async {
    _timer = null;

    await _read();
    if (_isDisposed) return;

    _check();
  }

  ///
  void _check() {
    if (isConnectivityAvailable) {
      logInfo(info: 'Connectivity available');
      _connectionSubject.add(NetworkConnectionAvailable());
    } else {
      logInfo(info: 'Connectivity not available');
      _connectionSubject.add(NetworkConnectionLost());
    }
  }

  ///
  void _onUpdate(List<ConnectivityResult> result) {
    _connectivityList
      ..clear()
      ..addAll(result);

    if (isConnectivityAvailable) {
      _timer?.cancel();
      _timer = null;
      _check();
      return;
    }

    _scheduleRecheck();
  }
}
