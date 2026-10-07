import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:application_base/presentation/service/network_service_base.dart';
import 'package:flutter_test/flutter_test.dart';

/// The restore is announced once per offline period: the subject delivers
/// asynchronously, so a service that flipped its state only on delivery sent
/// one [NetworkRestore] per success in flight — and every screen reloading on
/// restore reloaded that many times.
///
/// A reported loss is a report, not a verdict: the offline mode turns on only
/// once a ping confirms it, so a request failing on a connection that died in
/// the background does not flash the offline mode.
void main() {
  ///
  late List<NetworkEvent> events;

  ///
  late _NetworkService service;

  setUp(() {
    getIt
      ..registerLazySingleton<NetworkSubject>(NetworkSubject.new)
      ..registerLazySingleton<ConnectivityService>(
        () => ConnectivityService(getIt<NetworkSubject>()),
      );
    events = [];
    getIt<NetworkSubject>().listen(events.add);
    service = _NetworkService();
  });

  tearDown(() async {
    service.dispose();
    await getIt.reset();
  });

  /// Lets the confirmation timer fire, its ping answer and the subject
  /// deliver what was added.
  Future<void> settled() => Future<void>.delayed(Duration.zero);

  /// A loss the backend confirms.
  Future<void> goOffline() async {
    service
      ..isBackendUp = false
      ..onUpdate(NetworkConnectionLost());
    await settled();
  }

  group('restore', () {
    test('two successes in a row announce one restore', () async {
      await goOffline();
      expect(service.isOffline, isTrue);

      service
        ..onUpdate(NetworkSuccess())
        ..onUpdate(NetworkSuccess());
      await settled();

      expect(service.isOnline, isTrue);
      expect(events.whereType<NetworkRestore>(), hasLength(1));
    });

    test('a successful ping while online announces nothing', () async {
      await service.ping();
      await settled();

      expect(events.whereType<NetworkRestore>(), isEmpty);
    });

    test('a successful ping while offline restores once', () async {
      await goOffline();

      service.isBackendUp = true;
      await service.ping();
      service.onUpdate(NetworkSuccess());
      await settled();

      expect(service.isOnline, isTrue);
      expect(events.whereType<NetworkRestore>(), hasLength(1));
    });
  });

  group('loss confirmation', () {
    test('an unconfirmed loss leaves the service online', () async {
      service.onUpdate(NetworkConnectionLost());
      await settled();

      expect(service.isOnline, isTrue);
      expect(service.pingCount, 1);
      expect(events.whereType<NetworkOffline>(), isEmpty);
    });

    test('losses reported together are confirmed by one ping', () async {
      service
        ..isBackendUp = false
        ..onUpdate(NetworkConnectionLost())
        ..onUpdate(NetworkConnectionLost())
        ..onUpdate(NetworkConnectionLost());
      await settled();

      expect(service.isOffline, isTrue);
      expect(service.pingCount, 1);
      expect(events.whereType<NetworkOffline>(), hasLength(1));
    });

    test('a request getting through dismisses a waiting loss', () async {
      service
        ..confirmationDelay = const Duration(milliseconds: 50)
        ..isBackendUp = false
        ..onUpdate(NetworkConnectionLost())
        ..onUpdate(NetworkSuccess());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.isOnline, isTrue);
      expect(service.pingCount, 0);
    });

    test('a loss while offline needs no confirmation', () async {
      await goOffline();
      service
        ..pingCount = 0
        ..onUpdate(NetworkConnectionLost());
      await settled();

      expect(service.isOffline, isTrue);
      expect(service.pingCount, 0);
      expect(events.whereType<NetworkOffline>(), hasLength(1));
    });
  });

  group('listen', () {
    test('reports each switch once', () async {
      final switches = <bool>[];
      final subscription = service.listen(
        ({required isOnline}) => switches.add(isOnline),
      );
      addTearDown(subscription.cancel);

      await goOffline();
      service
        ..onUpdate(NetworkConnectionLost())
        ..onUpdate(NetworkSuccess());
      await settled();

      expect(switches, [false, true]);
    });

    test('a cancelled subscription hears nothing', () async {
      final switches = <bool>[];
      await service
          .listen(({required isOnline}) => switches.add(isOnline))
          .cancel();

      await goOffline();

      expect(switches, isEmpty);
    });
  });

  test('a disposed service stays where it was', () async {
    service
      ..dispose()
      ..isBackendUp = false
      ..onUpdate(NetworkConnectionLost());
    await settled();

    expect(service.isOnline, isTrue);
    expect(service.pingCount, 0);
  });
}

/// A backend that answers while [isBackendUp], and a confirmation that waits
/// [confirmationDelay].
final class _NetworkService extends NetworkServiceBase {
  ///
  bool isBackendUp = true;

  ///
  int pingCount = 0;

  /// None by default: the tests wait for the timer, not for the time.
  Duration confirmationDelay = Duration.zero;

  ///
  @override
  Duration get lossConfirmationDelay => confirmationDelay;

  ///
  @override
  Future<bool> sendPingRequest() async {
    pingCount++;
    return isBackendUp;
  }

  ///
  @override
  void onUpdate(NetworkEvent event) => super.onUpdate(event);
}
