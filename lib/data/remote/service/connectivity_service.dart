import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity changes are no longer communicated to Android apps
/// in the background starting with Android O (8.0).
/// You should always check for connectivity status when your app is resumed.
/// The broadcast is only useful when your application is in the foreground.
///
/// On iOS simulators, the connectivity types stream might not update
/// when Wi-Fi status changes.
final class ConnectivityService {
  ///
  ConnectivityService._();

  ///
  factory ConnectivityService.singleton() => _instance;

  ///
  static final _instance = ConnectivityService._();

  ///
  final _connectionSubject = getIt<NetworkSubject>();

  ///
  final List<ConnectivityResult> _connectivityList = [];

  ///
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Timer for special delay after connection lost
  Timer? _timer;

  /// Delay before checking connectivity availability
  final Duration _timerDelay = const Duration(seconds: 3);

  ///
  bool get isConnectivityAvailable =>
      _connectivityList.contains(ConnectivityResult.mobile) ||
      _connectivityList.contains(ConnectivityResult.wifi) ||
      _connectivityList.contains(ConnectivityResult.ethernet);

  ///
  bool get isWiFi => _connectivityList.contains(ConnectivityResult.wifi);

  ///
  Future<void> prepare() async {
    if (_subscription != null) return;
    _subscription = Connectivity().onConnectivityChanged.listen(_onUpdate);
    await getConnectivity();
  }

  ///
  void dispose() {
    _subscription?.cancel();

    _timer?.cancel();
    _timer = null;
  }

  ///
  Future<void> getConnectivity() async {
    final List<ConnectivityResult> actualConnectivityList = await Connectivity()
        .checkConnectivity();

    _connectivityList
      ..clear()
      ..addAll(actualConnectivityList);

    _check();
  }

  ///
  void _check() {
    if (isConnectivityAvailable) {
      logInfo(info: 'Connectivity available');
      _connectionSubject.add(NetworkSuccess());
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
      _check();
    } else {
      /// Starting with iOS 12, the implementation uses NWPathMonitor to obtain
      /// the enabled connectivity types. We noticed that this observer can give
      /// multiple or unreliable results. For example, reporting connectivity
      /// "none" followed by connectivity "wifi" right after reconnecting.
      ///
      /// Because of it will check connectivity after small delay
      logInfo(info: 'Connectivity become not available, will check it');

      _timer?.cancel();
      _timer = Timer(_timerDelay, _check);
    }
  }
}
