import 'package:application_base/core/service/logger_service.dart';
import 'package:flutter/foundation.dart';

///
final class AccessVM with ChangeNotifier {
  ///
  AccessVM._();

  ///
  factory AccessVM.singleton() => _instance;

  ///
  static final _instance = AccessVM._();

  ///
  bool _isGranted = false;

  ///
  bool get isGranted => _isGranted;

  ///
  void grantAccess({bool needNotify = true}) =>
      _changeGrantedState(isAccessGranted: true, needNotify: needNotify);

  ///
  void revokeAccess({bool needNotify = true}) =>
      _changeGrantedState(isAccessGranted: false, needNotify: needNotify);

  /// Auto route to authorization screen and auto return to current route
  /// after success authorization on [needNotify] is true
  void _changeGrantedState({
    required bool isAccessGranted,
    required bool needNotify,
  }) {
    _isGranted = isAccessGranted;
    if (needNotify) notifyListeners();

    logInfo(info: 'Access state: $_isGranted');
  }
}
