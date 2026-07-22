import 'dart:async';

import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:meta/meta.dart';

///
base mixin ConnectionRestoreMixin {
  /// Nullable rather than `late`: [disposeConnection] is routinely reached
  /// through an early return that never ran [prepareConnection], and a `late`
  /// field turns that into a `LateInitializationError`.
  StreamSubscription<NetworkEvent>? _subscriptionConnection;

  /// Idempotent — a second call keeps the existing subscription instead of
  /// leaking the first one.
  void prepareConnection() => _subscriptionConnection ??=
      getIt<NetworkSubject>().listenConnectionRestore(onConnectionRestore);

  /// Clears the field so a later [prepareConnection] can subscribe again.
  Future<void> disposeConnection() async {
    await _subscriptionConnection?.cancel();
    _subscriptionConnection = null;
  }

  ///
  @mustBeOverridden
  void onConnectionRestore();
}
