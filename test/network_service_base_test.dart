import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:application_base/presentation/service/network_service_base.dart';
import 'package:flutter_test/flutter_test.dart';

/// The restore is announced once per offline period: the subject delivers
/// asynchronously, so a service that flipped its state only on delivery sent
/// one [NetworkRestore] per success in flight — and every screen reloading on
/// restore reloaded that many times.
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

  /// Lets the subject deliver what was added.
  Future<void> delivered() => Future<void>.delayed(Duration.zero);

  test('two successes in a row announce one restore', () async {
    service.onUpdate(NetworkConnectionLost());
    expect(service.isOffline, isTrue);

    service
      ..onUpdate(NetworkSuccess())
      ..onUpdate(NetworkSuccess());
    await delivered();

    expect(service.isOnline, isTrue);
    expect(events.whereType<NetworkRestore>(), hasLength(1));
  });

  test('a successful ping while online announces nothing', () async {
    await service.ping();
    await delivered();

    expect(events.whereType<NetworkRestore>(), isEmpty);
  });

  test('a successful ping while offline restores once', () async {
    service.onUpdate(NetworkConnectionLost());

    await service.ping();
    service.onUpdate(NetworkSuccess());
    await delivered();

    expect(service.isOnline, isTrue);
    expect(events.whereType<NetworkRestore>(), hasLength(1));
  });

  test('a disposed service stays where it was', () {
    service
      ..dispose()
      ..onUpdate(NetworkConnectionLost());

    expect(service.isOnline, isTrue);
  });
}

/// A backend that always answers.
final class _NetworkService extends NetworkServiceBase {
  ///
  @override
  Future<bool> sendPingRequest() async => true;

  ///
  @override
  void onUpdate(NetworkEvent event) => super.onUpdate(event);
}
