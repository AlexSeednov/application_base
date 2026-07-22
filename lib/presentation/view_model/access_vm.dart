import 'package:application_base/core/service/logger_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Whether the current session is allowed past the authentication guard.
///
/// Implements [ValueListenable] so screens consume it through a
/// `ValueListenableBuilder<bool>` like every other piece of state in the
/// project, while staying a [ChangeNotifier] because `auto_route` takes the
/// instance itself as `reevaluateListenable`. A plain [ValueNotifier] would not
/// do: it notifies on every write, and [grantAccess] / [revokeAccess] must be
/// able to update the flag *without* waking the router — that is what
/// `needNotify` is for.
@lazySingleton
final class AccessVM extends ChangeNotifier implements ValueListenable<bool> {
  ///
  @visibleForTesting
  AccessVM();

  ///
  bool _isGranted = false;

  ///
  @override
  bool get value => _isGranted;

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
    /// Nothing changed — do not wake the router or repeat the log line.
    if (_isGranted == isAccessGranted) return;

    _isGranted = isAccessGranted;
    if (needNotify) notifyListeners();

    logInfo(info: 'Access state: $_isGranted');
  }
}
