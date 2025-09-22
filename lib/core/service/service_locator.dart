import 'package:application_base/data/local/service/storage_service.dart';
import 'package:application_base/data/remote/service/connectivity_service.dart';
import 'package:application_base/domain/subject/network_subject.dart';
import 'package:application_base/presentation/service/lifecycle_service.dart';
import 'package:application_base/presentation/view_model/access_vm.dart';
import 'package:get_it/get_it.dart';

/// Common instance for service locator
final getIt = GetIt.instance;

abstract final class ServiceLocatorBase {
  /// Setup service locator
  static void prepare() {
    getIt
      /// Data layer
      ..registerLazySingleton<ConnectivityService>(
        ConnectivityService.singleton,
        dispose: (service) => service.dispose(),
      )
      ..registerLazySingleton<NetworkSubject>(
        NetworkSubject.singleton,
        dispose: (service) => service.dispose(),
      )
      ..registerLazySingleton<StorageService>(StorageService.singleton)
      /// Presentation layer
      ..registerLazySingleton<LifecycleService>(
        LifecycleService.singleton,
        dispose: (service) => service.dispose(),
      )
      ..registerLazySingleton<AccessVM>(AccessVM.singleton);
  }
}
