import 'dart:async';

import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// A missing link is published only when a fresh reading taken after the
/// delay still finds none. Back from the background Android answers "none"
/// for a network it has not unblocked for the app yet, and a stale "none"
/// from the stream must not outlive the link that came back.
void main() {
  ///
  late ConnectivityPlatform originalPlatform;

  ///
  late _FakeConnectivityPlatform platform;

  setUp(() {
    originalPlatform = ConnectivityPlatform.instance;
    platform = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = platform;
  });

  tearDown(() async {
    ConnectivityPlatform.instance = originalPlatform;
    await platform.dispose();
  });

  /// Runs [body] on a fake clock with a fresh subject and service, the events
  /// the subject got collected in the list it receives.
  void onFakeClock(
    void Function(
      FakeAsync async,
      ConnectivityService service,
      List<NetworkEvent> events,
    )
    body,
  ) => fakeAsync((async) {
    final subject = NetworkSubject();
    final service = ConnectivityService(subject);
    final events = <NetworkEvent>[];
    subject.listen(events.add);

    body(async, service, events);

    service.dispose();
    subject.dispose();
    async.flushMicrotasks();
  });

  test('a link found on reading is published at once', () {
    onFakeClock((async, service, events) {
      unawaited(service.getConnectivity());
      async.flushMicrotasks();

      expect(events.single, isA<NetworkConnectionAvailable>());
    });
  });

  test('no link on reading waits for the re-check', () {
    onFakeClock((async, service, events) {
      platform.current = [ConnectivityResult.none];
      unawaited(service.getConnectivity());
      async.flushMicrotasks();

      expect(events, isEmpty);

      async.elapse(const Duration(seconds: 3));

      expect(events.single, isA<NetworkConnectionLost>());
    });
  });

  test('a link back by the re-check is not reported lost', () {
    onFakeClock((async, service, events) {
      platform.current = [ConnectivityResult.none];
      unawaited(service.getConnectivity());
      async.flushMicrotasks();

      platform.current = [ConnectivityResult.wifi];
      async.elapse(const Duration(seconds: 3));

      expect(events.whereType<NetworkConnectionLost>(), isEmpty);
      expect(service.isConnectivityAvailable, isTrue);
    });
  });

  test('a stale "none" from the stream is read again, not trusted', () {
    onFakeClock((async, service, events) {
      unawaited(service.prepare());
      async.flushMicrotasks();

      platform.changes.add([ConnectivityResult.none]);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 3));

      expect(events.whereType<NetworkConnectionLost>(), isEmpty);
      expect(service.isConnectivityAvailable, isTrue);
    });
  });

  test('a disposed service publishes nothing after the re-check', () {
    onFakeClock((async, service, events) {
      platform.current = [ConnectivityResult.none];
      unawaited(service.getConnectivity());
      async.flushMicrotasks();

      service.dispose();
      async.elapse(const Duration(seconds: 3));

      expect(events, isEmpty);
    });
  });
}

/// Answers every reading with [current]; the stream sends what [changes] gets.
final class _FakeConnectivityPlatform extends ConnectivityPlatform {
  ///
  List<ConnectivityResult> current = [ConnectivityResult.wifi];

  ///
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  ///
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;

  ///
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  ///
  Future<void> dispose() => changes.close();
}
